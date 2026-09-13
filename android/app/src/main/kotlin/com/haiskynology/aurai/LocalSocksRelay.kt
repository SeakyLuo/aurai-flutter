package com.haiskynology.aurai

import android.net.VpnService
import android.net.Network
import java.io.Closeable
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Semaphore
import kotlin.concurrent.thread

/** Authenticated loopback relay. Only upstream sockets bypass the VPN. */
class LocalSocksRelay(private val vpn: VpnService, private val network: Network) : Closeable {
    val username = "aurai"
    val password = UUID.randomUUID().toString()
    private val listener = ServerSocket(0, 32, InetAddress.getByName("127.0.0.1"))
    val port: Int get() = listener.localPort
    private val resources = ConcurrentHashMap.newKeySet<Closeable>()
    private val slots = Semaphore(64)
    @Volatile private var closed = false

    fun start() {
        thread(name = "vpn-accept") {
            try {
                while (!closed) {
                    val client = listener.accept()
                    if (!slots.tryAcquire()) { client.close(); continue }
                    resources.add(client)
                    thread(name = "vpn-session") {
                        try { handle(client) } catch (_: IOException) {
                            // Peer disconnects and network changes end only this flow.
                        } finally {
                            release(client)
                            slots.release()
                        }
                    }
                }
            } catch (_: IOException) {
                // Closing the service closes the listening socket.
            }
        }
    }

    private fun handle(client: Socket) {
        client.soTimeout = 10000
        val input = DataInputStream(client.getInputStream())
        val output = DataOutputStream(client.getOutputStream())
        if (input.readUnsignedByte() != 5) return
        val methods = ByteArray(input.readUnsignedByte()).also(input::readFully)
        if (!methods.contains(2.toByte())) { output.write(byteArrayOf(5, -1)); return }
        output.write(byteArrayOf(5, 2))
        if (input.readUnsignedByte() != 1) return
        val user = ByteArray(input.readUnsignedByte()).also(input::readFully).toString(Charsets.UTF_8)
        val pass = ByteArray(input.readUnsignedByte()).also(input::readFully).toString(Charsets.UTF_8)
        val accepted = user == username && pass == password
        output.write(byteArrayOf(1, if (accepted) 0 else 1))
        if (!accepted || input.readUnsignedByte() != 5) return
        val command = input.readUnsignedByte()
        if (input.readUnsignedByte() != 0) return
        val address = address(input)
        val port = input.readUnsignedShort()
        when (command) {
            1 -> tcp(client, output, address, port)
            3 -> udp(client, output)
            else -> reply(output, 7, 0)
        }
    }

    private fun tcp(client: Socket, output: DataOutputStream, host: String, port: Int) {
        val upstream = Socket()
        resources.add(upstream)
        val flow = NetworkTrafficLog.open(host, port, "TCP")
        var connected = false
        try {
            network.bindSocket(upstream)
            if (!vpn.protect(upstream)) throw IOException("Cannot protect upstream socket")
            upstream.connect(InetSocketAddress(host, port), 10000)
            upstream.soTimeout = 60000
            client.soTimeout = 60000
            reply(output, 0, upstream.localPort)
            connected = true
            NetworkTrafficLog.update(flow)
            val upload = thread(name = "vpn-upload") {
                try {
                    pipe(client, upstream) { NetworkTrafficLog.update(flow, sent = it) }
                    upstream.shutdownOutput()
                } catch (_: IOException) {
                    release(upstream)
                }
            }
            try {
                pipe(upstream, client) { NetworkTrafficLog.update(flow, received = it) }
                client.shutdownOutput()
                upload.join(61000)
            } finally {
                release(upstream)
            }
            NetworkTrafficLog.update(flow, status = "closed")
        } catch (_: IOException) {
            NetworkTrafficLog.update(flow, status = "failed")
            if (!connected) try { reply(output, 1, 0) } catch (_: IOException) { }
        } finally { release(upstream) }
    }

    private fun pipe(from: Socket, to: Socket, count: (Int) -> Unit) {
        val buffer = ByteArray(16384)
        val input = from.getInputStream()
        val output = to.getOutputStream()
        while (!closed) {
            val size = input.read(buffer)
            if (size < 0) break
            output.write(buffer, 0, size)
            count(size)
        }
    }

    private fun udp(control: Socket, output: DataOutputStream) {
        val local = DatagramSocket(0, InetAddress.getByName("127.0.0.1"))
        val remote = DatagramSocket()
        resources.add(local); resources.add(remote)
        val flows = ConcurrentHashMap<InetSocketAddress, NetworkTrafficLog.Flow>()
        try {
            network.bindSocket(remote)
            if (!vpn.protect(remote)) throw IOException("Cannot protect UDP socket")
            local.soTimeout = 60000
            remote.soTimeout = 60000
            reply(output, 0, local.localPort)
            var clientAddress: InetSocketAddress? = null
            val peerLock = Any()
            val receive = thread(name = "vpn-udp-receive") {
                val packet = DatagramPacket(ByteArray(65535), 65535)
                try {
                    while (!closed) {
                        packet.length = packet.data.size
                        remote.receive(packet)
                        val source = packet.socketAddress as InetSocketAddress
                        val flow = flows[source] ?: continue
                        val peer = synchronized(peerLock) { clientAddress } ?: continue
                        val addressBytes = packet.address.address
                        val header = byteArrayOf(0, 0, 0, if (addressBytes.size == 4) 1 else 4) +
                            addressBytes + byteArrayOf((packet.port shr 8).toByte(), packet.port.toByte())
                        val bytes = header + packet.data.copyOfRange(packet.offset, packet.offset + packet.length)
                        local.send(DatagramPacket(bytes, bytes.size, peer))
                        NetworkTrafficLog.update(flow, received = packet.length)
                    }
                } catch (_: IOException) {
                    release(local); release(remote); release(control)
                }
            }
            val send = thread(name = "vpn-udp-send") {
                val packet = DatagramPacket(ByteArray(65535), 65535)
                try {
                    while (!closed) {
                        packet.length = packet.data.size
                        local.receive(packet)
                        val peer = packet.socketAddress as InetSocketAddress
                        synchronized(peerLock) {
                            if (clientAddress == null) clientAddress = peer
                        }
                        if (peer != synchronized(peerLock) { clientAddress }) continue
                        val stream = java.io.ByteArrayInputStream(packet.data, packet.offset, packet.length)
                        val data = DataInputStream(stream)
                        if (data.readUnsignedShort() != 0 || data.readUnsignedByte() != 0) continue
                        val host = address(data)
                        val port = data.readUnsignedShort()
                        val target = InetSocketAddress(host, port)
                        if (!flows.containsKey(target) && flows.size >= 64) continue
                        val flow = flows.getOrPut(target) { NetworkTrafficLog.open(host, port, "UDP") }
                        val payload = stream.readBytes()
                        remote.send(DatagramPacket(payload, payload.size, target))
                        NetworkTrafficLog.update(flow, sent = payload.size)
                    }
                } catch (_: IOException) {
                    release(local); release(remote); release(control)
                }
            }
            control.soTimeout = 0
            while (control.getInputStream().read() != -1) { }
            release(local); release(remote)
            send.join(1000); receive.join(1000)
        } finally {
            release(local); release(remote)
            flows.values.forEach { NetworkTrafficLog.update(it, status = "closed") }
        }
    }

    private fun address(input: DataInputStream): String = when (input.readUnsignedByte()) {
        1 -> InetAddress.getByAddress(ByteArray(4).also(input::readFully)).hostAddress!!
        4 -> InetAddress.getByAddress(ByteArray(16).also(input::readFully)).hostAddress!!
        3 -> ByteArray(input.readUnsignedByte()).also(input::readFully).toString(Charsets.UTF_8)
        else -> throw IOException("Unsupported SOCKS address")
    }

    private fun reply(output: DataOutputStream, status: Int, port: Int) {
        output.write(byteArrayOf(5, status.toByte(), 0, 1, 127, 0, 0, 1, (port shr 8).toByte(), port.toByte()))
    }

    private fun release(resource: Closeable) {
        resources.remove(resource)
        try { resource.close() } catch (_: IOException) { }
    }
    override fun close() {
        closed = true
        listener.close()
        resources.forEach(::release)
    }
}
