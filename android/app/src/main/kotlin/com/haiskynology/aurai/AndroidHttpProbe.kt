package com.haiskynology.aurai

import android.net.ConnectivityManager
import android.net.Network
import java.io.EOFException
import java.net.ConnectException
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Proxy
import java.net.Socket
import java.net.SocketTimeoutException
import java.net.URI
import java.net.UnknownHostException
import java.security.cert.CertificateException
import java.security.cert.X509Certificate
import java.time.Instant
import java.util.concurrent.atomic.AtomicReference
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLHandshakeException
import javax.net.ssl.SSLPeerUnverifiedException
import javax.net.ssl.SSLSocket

class AndroidHttpProbe(
    private val connectivityManager: ConnectivityManager,
    private val activeSocket: AtomicReference<Socket?>,
) {
    fun run(
        url: String,
        method: String,
        attempts: Int,
        intervalMs: Int,
        networkHandle: Long?,
        route: String,
        proxyHost: String?,
        proxyPort: Int?,
    ): Map<String, Any?> {
        val uri = URI(url)
        require(uri.scheme == "https") { "httpProbe currently supports HTTPS URLs" }
        require(uri.host != null) { "URL must contain a hostname" }
        require(method == "GET" || method == "HEAD") { "method must be GET or HEAD" }
        require(attempts in 1..60) { "attempts must be between 1 and 60" }
        require(intervalMs in 0..30_000) { "intervalMs must be between 0 and 30000" }
        require(route == "android" || route == "socks5") { "route must be android or socks5" }
        if (route == "socks5") {
            require(proxyHost != null) { "proxyHost is required for socks5" }
            require(proxyPort in 1..65_535) { "proxyPort must be between 1 and 65535" }
            require(networkHandle == null) { "networkHandle cannot be combined with socks5" }
        }

        val network = networkHandle?.let(::findNetwork)
        val proxy = if (route == "socks5") {
            Proxy(Proxy.Type.SOCKS, InetSocketAddress(proxyHost, proxyPort!!))
        } else {
            null
        }
        val outcomes = buildList {
            repeat(attempts) { index ->
                add(runOnce(uri, method, index + 1, network, proxy))
                if (index + 1 < attempts && intervalMs > 0) Thread.sleep(intervalMs.toLong())
            }
        }
        val successes = outcomes.filter { it["transportSuccess"] == true }
        val failures = outcomes.filter { it["transportSuccess"] == false }
        return mapOf(
            "url" to url,
            "method" to method,
            "networkHandle" to networkHandle,
            "route" to route,
            "proxyHost" to proxyHost,
            "proxyPort" to proxyPort,
            "requestedAttempts" to attempts,
            "successfulAttempts" to successes.size,
            "failedAttempts" to failures.size,
            "firstFailureAt" to failures.firstOrNull()?.get("startedAt"),
            "lastFailureAt" to failures.lastOrNull()?.get("startedAt"),
            "longestFailureStreak" to longestFailureStreak(outcomes),
            "failureCountsByStage" to failures
                .groupingBy { it["failedStage"] as String }
                .eachCount(),
            "attempts" to outcomes,
        )
    }

    private fun runOnce(
        uri: URI,
        method: String,
        attempt: Int,
        network: Network?,
        proxy: Proxy?,
    ): Map<String, Any?> {
        val started = System.nanoTime()
        val startedAt = Instant.now().toString()
        var stage = "dns"
        var stageStarted = started
        var resolvedAddresses = emptyList<String>()
        var dnsDurationMs: Long? = null
        var tcpDurationMs: Long? = null
        var localAddress: String? = null
        var localPort: Int? = null
        var socketPeerAddress: String? = null
        var socketPeerPort: Int? = null
        return try {
            val dnsStarted = System.nanoTime()
            val addresses = if (proxy == null) resolve(uri.host, network) else emptyList()
            resolvedAddresses = addresses.mapNotNull(InetAddress::getHostAddress)
            dnsDurationMs = elapsedMs(dnsStarted)

            stage = if (proxy == null) "tcp_connect" else "proxy_connect"
            stageStarted = System.nanoTime()
            val tcpStarted = System.nanoTime()
            val rawSocket = when {
                proxy != null -> Socket(proxy)
                network != null -> network.socketFactory.createSocket()
                else -> Socket()
            }
            activeSocket.set(rawSocket)
            val destination = if (proxy == null) {
                InetSocketAddress(addresses.first(), effectivePort(uri))
            } else {
                InetSocketAddress.createUnresolved(uri.host, effectivePort(uri))
            }
            rawSocket.connect(destination, TIMEOUT_MS)
            tcpDurationMs = elapsedMs(tcpStarted)
            localAddress = rawSocket.localAddress.hostAddress
            localPort = rawSocket.localPort
            socketPeerAddress = rawSocket.inetAddress.hostAddress
            socketPeerPort = rawSocket.port

            stage = "tls_handshake"
            stageStarted = System.nanoTime()
            val tlsStarted = System.nanoTime()
            val socket = SSLContext.getDefault().socketFactory.createSocket(
                rawSocket,
                uri.host,
                effectivePort(uri),
                true,
            ) as SSLSocket
            activeSocket.set(socket)
            socket.soTimeout = TIMEOUT_MS
            socket.sslParameters = socket.sslParameters.apply {
                serverNames = listOf(SNIHostName(uri.host))
                endpointIdentificationAlgorithm = "HTTPS"
                applicationProtocols = arrayOf("http/1.1")
            }
            socket.startHandshake()
            val tlsDurationMs = elapsedMs(tlsStarted)

            stage = "http_response"
            stageStarted = System.nanoTime()
            val httpStarted = System.nanoTime()
            socket.outputStream.write(requestBytes(uri, method))
            socket.outputStream.flush()
            val statusLine = socket.inputStream.bufferedReader(Charsets.ISO_8859_1).readLine()
                ?: throw EOFException("connection closed before HTTP response")
            val statusCode = statusLine.split(' ')[1].toInt()
            val httpDurationMs = elapsedMs(httpStarted)
            val certificate = socket.session.peerCertificates.first() as X509Certificate

            mapOf(
                "attempt" to attempt,
                "startedAt" to startedAt,
                "completedAt" to Instant.now().toString(),
                "transportSuccess" to true,
                "statusCode" to statusCode,
                "httpSuccess" to (statusCode in 200..399),
                "resolvedAddresses" to resolvedAddresses,
                "dnsMode" to if (proxy == null) "android" else "proxy",
                "localAddress" to localAddress,
                "localPort" to localPort,
                "socketPeerAddress" to socketPeerAddress,
                "socketPeerPort" to socketPeerPort,
                "dnsDurationMs" to dnsDurationMs,
                "tcpDurationMs" to tcpDurationMs,
                "tlsDurationMs" to tlsDurationMs,
                "httpResponseDurationMs" to httpDurationMs,
                "totalDurationMs" to elapsedMs(started),
                "protocol" to socket.session.protocol,
                "cipherSuite" to socket.session.cipherSuite,
                "certificateSubject" to certificate.subjectX500Principal.name,
                "certificateIssuer" to certificate.issuerX500Principal.name,
                "certificateNotBefore" to certificate.notBefore.toInstant().toString(),
                "certificateNotAfter" to certificate.notAfter.toInstant().toString(),
            )
        } catch (error: Exception) {
            val failedStage = classifyFailure(stage, error)
            mapOf(
                "attempt" to attempt,
                "startedAt" to startedAt,
                "completedAt" to Instant.now().toString(),
                "transportSuccess" to false,
                "failedStage" to failedStage,
                "failedStageDurationMs" to elapsedMs(stageStarted),
                "resolvedAddresses" to resolvedAddresses,
                "dnsMode" to if (proxy == null) "android" else "proxy",
                "dnsDurationMs" to dnsDurationMs,
                "tcpDurationMs" to tcpDurationMs,
                "localAddress" to localAddress,
                "localPort" to localPort,
                "socketPeerAddress" to socketPeerAddress,
                "socketPeerPort" to socketPeerPort,
                "errorType" to error.javaClass.simpleName,
                "error" to (error.message ?: error.javaClass.simpleName),
                "errorChain" to errorChain(error),
                "totalDurationMs" to elapsedMs(started),
            )
        } finally {
            activeSocket.getAndSet(null)?.close()
        }
    }

    private fun resolve(host: String, network: Network?): List<InetAddress> =
        (network?.getAllByName(host) ?: InetAddress.getAllByName(host)).toList()

    private fun findNetwork(handle: Long): Network =
        connectivityManager.allNetworks.single { it.networkHandle == handle }

    private fun effectivePort(uri: URI): Int = if (uri.port == -1) 443 else uri.port

    private fun requestBytes(uri: URI, method: String): ByteArray {
        val path = (uri.rawPath.ifEmpty { "/" }) +
            if (uri.rawQuery == null) "" else "?${uri.rawQuery}"
        val host = if (effectivePort(uri) == 443) uri.host else "${uri.host}:${effectivePort(uri)}"
        return buildString {
            append("$method $path HTTP/1.1\r\n")
            append("Host: $host\r\n")
            append("User-Agent: Aurai/1\r\n")
            append("Accept: */*\r\n")
            append("Connection: close\r\n\r\n")
        }.toByteArray(Charsets.US_ASCII)
    }

    private fun classifyFailure(stage: String, error: Exception): String = when {
        error is UnknownHostException -> "dns"
        error is ConnectException -> stage
        error is SSLPeerUnverifiedException -> "tls_certificate"
        error is SSLHandshakeException && error.hasCertificateCause() -> "tls_certificate"
        error is SSLHandshakeException -> stage
        error is SocketTimeoutException -> "${stage}_timeout"
        else -> stage
    }

    private fun Throwable.hasCertificateCause(): Boolean {
        var current: Throwable? = this
        while (current != null) {
            if (current is CertificateException) return true
            current = current.cause
        }
        return false
    }

    private fun errorChain(error: Throwable): List<Map<String, String>> {
        val chain = mutableListOf<Map<String, String>>()
        var current: Throwable? = error
        while (current != null && chain.size < 6) {
            chain += mapOf(
                "type" to current.javaClass.simpleName,
                "message" to (current.message ?: current.javaClass.simpleName),
            )
            current = current.cause
        }
        return chain
    }

    private fun longestFailureStreak(outcomes: List<Map<String, Any?>>): Int {
        var longest = 0
        var current = 0
        outcomes.forEach { outcome ->
            if (outcome["transportSuccess"] == false) {
                current += 1
                if (current > longest) longest = current
            } else {
                current = 0
            }
        }
        return longest
    }

    private fun elapsedMs(started: Long): Long = (System.nanoTime() - started) / 1_000_000

    companion object {
        private const val TIMEOUT_MS = 10_000
    }
}
