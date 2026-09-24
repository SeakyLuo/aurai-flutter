package com.haiskynology.aurai

import android.app.Application
import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.Socket
import java.security.KeyStore
import java.security.cert.X509Certificate
import java.time.Instant
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.atomic.AtomicReference
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HttpsURLConnection
import javax.net.ssl.SNIHostName
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManager
import javax.net.ssl.TrustManagerFactory
import javax.net.ssl.X509TrustManager

class AuraiApplication : Application() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val activeTask = AtomicReference<Future<*>?>()
    private val activeResult = AtomicReference<MethodChannel.Result?>()
    private val activeSocket = AtomicReference<Socket?>()
    private val shellJobs by lazy { AppShellJobs(this) }
    private lateinit var agentBridge: AndroidAgentBridge
    private lateinit var httpProbe: AndroidHttpProbe
    private val networkEvents = ArrayDeque<Map<String, Any?>>()
    private val networkCallback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) = recordNetworkEvent("available", network)
        override fun onLost(network: Network) = recordNetworkEvent("lost", network)
        override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
            recordNetworkEvent("capabilitiesChanged", network, capabilities = capabilities)
        }
        override fun onLinkPropertiesChanged(network: Network, links: LinkProperties) {
            recordNetworkEvent("linkPropertiesChanged", network, links = links)
        }
    }

    lateinit var flutterEngine: FlutterEngine
        private set

    override fun onCreate() {
        super.onCreate()
        if (java.io.File("/proc/self/cmdline").readText().trimEnd('\u0000').let { it.endsWith(":device_script") || it.endsWith(":documents") }) return
        DataBackupArchive(this).applyPending()
        FlutterInjector.instance().flutterLoader().startInitialization(this)
        FlutterInjector.instance().flutterLoader().ensureInitializationComplete(this, null)
        flutterEngine = FlutterEngine(this)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        DataManagementAccess(this, flutterEngine.dartExecutor.binaryMessenger, ::loadModelConfig)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "aurai/html_game", HtmlGameViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        ScheduledTasks.initialize(this, flutterEngine.dartExecutor.binaryMessenger)
        agentBridge = AndroidAgentBridge(this)
        httpProbe = AndroidHttpProbe(
            getSystemService(ConnectivityManager::class.java),
            activeSocket,
        )
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        activeChannel = channel
        channel.setMethodCallHandler(::handleMethodCall)
        getSystemService(ConnectivityManager::class.java).registerNetworkCallback(
            NetworkRequest.Builder().build(),
            networkCallback,
        )
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
    }

    private val scriptRunner by lazy { AndroidScriptRunner(this) }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "transformModelRequest" -> Thread {
                try {
                    val output = ModelRequestTransform.run(call.argument<String>("script")!!, call.argument<String>("input")!!)
                    android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(output) }
                } catch (error: Exception) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post { result.error("request_transform", error.message, null) }
                }
            }.start()

            "inspectAndroidApi" -> result.success(AndroidApiInspector.inspect(
                call.argument<String>("className")!!,
                call.argument<String>("filter")!!,
                call.argument<Int>("offset")!!,
            ))
            "executeAndroidScript" -> scriptRunner.execute(
                call.argument<String>("callId")!!,
                call.argument<String>("script")!!,
                call.argument<String>("conversationId")!!,
                call.argument<Int>("timeoutSeconds") ?: 10,
                result,
            )
            "cancelAndroidScript" -> {
                scriptRunner.cancel(call.argument<String>("callId")!!)
                result.success(null)
            }
            "sendNotification" -> result.success(
                AgentNotifications(this).send(
                    call.argument<String>("title")!!,
                    call.argument<String>("body")!!,
                    call.argument<String>("conversationId")!!,
                    call.argument<ByteArray>("avatar")!!,
                ),
            )
            "takeNotificationConversation" -> {
                result.success(pendingNotificationConversation)
                pendingNotificationConversation = null
            }
            "getNetworkState" -> startTask(result, ::readNetworkState)
            "getNetworkEvents" -> result.success(readNetworkEvents())
            "dnsLookup" -> {
                val host = call.argument<String>("host")!!
                val networkHandle = call.argument<Number>("networkHandle")?.toLong()
                startTask(result) { dnsLookup(host, networkHandle) }
            }
            "tlsProbe" -> {
                val host = call.argument<String>("host")!!
                val port = call.argument<Int>("port")!!
                val attempts = call.argument<Int>("attempts")!!
                val networkHandle = call.argument<Number>("networkHandle")?.toLong()
                startTask(result) { tlsProbe(host, port, attempts, networkHandle) }
            }
            "httpProbe" -> {
                val url = call.argument<String>("url")!!
                val method = call.argument<String>("method")!!
                val attempts = call.argument<Int>("attempts")!!
                val intervalMs = call.argument<Int>("intervalMs")!!
                val networkHandle = call.argument<Number>("networkHandle")?.toLong()
                val route = call.argument<String>("route")!!
                val proxyHost = call.argument<String>("proxyHost")
                val proxyPort = call.argument<Int>("proxyPort")
                startTask(result) {
                    httpProbe.run(
                        url,
                        method,
                        attempts,
                        intervalMs,
                        networkHandle,
                        route,
                        proxyHost,
                        proxyPort,
                    )
                }
            }
            "shell" -> {
                val command = call.argument<String>("command")!!
                shellJobs.execute(call.argument<String>("id")!!, command, result)
            }
            "cancelAppShell" -> {
                shellJobs.cancel(call.argument<String>("id")!!)
                result.success(null)
            }
            "cancelCurrentProbe" -> {
                cancelCurrentProbe(notify = true)
                result.success(null)
            }
            "loadAppState" -> result.success(preferences().getString(APP_STATE_KEY, null))
            "clearLegacyAppState" -> {
                preferences().edit().remove(APP_STATE_KEY).apply()
                result.success(null)
            }
            "loadModelConfig" -> result.success(loadModelConfig())
            "saveModelConfig" -> {
                try {
                    saveModelConfig(call.argument<String>("config")!!)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("secure_storage_error", "无法安全保存模型配置", null)
                }
            }
            else -> if (!agentBridge.handle(call, result)) result.notImplemented()
        }
    }

    private fun startTask(
        result: MethodChannel.Result,
        operation: () -> Map<String, Any?>,
    ) {
        activeResult.set(result)
        val task = executor.submit {
            try {
                val value = operation()
                completeTask(result) { it.success(value) }
            } catch (error: InterruptedException) {
                completeTask(result) { it.error("cancelled", "任务已停止", null) }
            } catch (error: Exception) {
                completeTask(result) {
                    it.error("network_error", error.message ?: error.javaClass.simpleName, null)
                }
            }
        }
        activeTask.set(task)
    }

    private fun completeTask(
        expected: MethodChannel.Result,
        reply: (MethodChannel.Result) -> Unit,
    ) {
        if (activeResult.compareAndSet(expected, null)) {
            activeTask.set(null)
            activeSocket.set(null)
            mainHandler.post { reply(expected) }
        }
    }

    private fun cancelCurrentProbe(notify: Boolean) {
        activeSocket.getAndSet(null)?.close()
        activeTask.getAndSet(null)?.cancel(true)
        val result = activeResult.getAndSet(null)
        if (notify && result != null) {
            mainHandler.post { result.error("cancelled", "任务已停止", null) }
        }
    }

    private fun readNetworkState(): Map<String, Any?> {
        val manager = getSystemService(ConnectivityManager::class.java)
        val active = manager.activeNetwork
        val networks = manager.allNetworks.map { network ->
            describeNetwork(manager, network, network == active)
        }
        return mapOf(
            "connected" to (active != null),
            "activeNetwork" to active?.let { describeNetwork(manager, it, true) },
            "networks" to networks,
            "capturedAt" to Instant.now().toString(),
        )
    }

    private fun readNetworkEvents(): Map<String, Any?> = synchronized(networkEvents) {
        mapOf(
            "scope" to "since_aurai_process_started",
            "eventCount" to networkEvents.size,
            "events" to networkEvents.toList(),
        )
    }

    private fun recordNetworkEvent(
        type: String,
        network: Network,
        capabilities: NetworkCapabilities? = null,
        links: LinkProperties? = null,
    ) {
        val event = mapOf(
            "type" to type,
            "capturedAt" to Instant.now().toString(),
            "networkHandle" to network.networkHandle,
            "transports" to capabilities?.let(::transportNames),
            "validated" to capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED),
            "internet" to capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET),
            "interfaceName" to links?.interfaceName,
            "dnsServers" to links?.dnsServers?.mapNotNull(InetAddress::getHostAddress),
            "routes" to links?.routes?.map { it.toString() },
            "privateDnsActive" to links?.isPrivateDnsActive,
            "privateDnsServer" to links?.privateDnsServerName,
        )
        synchronized(networkEvents) {
            if (networkEvents.size == MAX_NETWORK_EVENTS) networkEvents.removeFirst()
            networkEvents.addLast(event)
        }
    }

    private fun describeNetwork(
        manager: ConnectivityManager,
        network: Network,
        active: Boolean,
    ): Map<String, Any?> {
        val capabilities = manager.getNetworkCapabilities(network)
        val links = manager.getLinkProperties(network)
        return mapOf(
            "active" to active,
            "networkHandle" to network.networkHandle,
            "transports" to transportNames(capabilities),
            "internet" to capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET),
            "validated" to capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED),
            "captivePortal" to capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL),
            "metered" to (capabilities?.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) == false),
            "interfaceName" to links?.interfaceName,
            "dnsServers" to links?.dnsServers?.mapNotNull(InetAddress::getHostAddress),
            "addresses" to links?.linkAddresses?.map { it.toString() },
            "routes" to links?.routes?.map { it.toString() },
            "privateDnsActive" to links?.isPrivateDnsActive,
            "privateDnsServer" to links?.privateDnsServerName,
            "proxy" to links?.httpProxy?.toString(),
        )
    }

    private fun transportNames(capabilities: NetworkCapabilities?): List<String> {
        if (capabilities == null) return emptyList()
        return buildList {
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) add("wifi")
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) add("cellular")
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) add("vpn")
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)) add("ethernet")
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_BLUETOOTH)) add("bluetooth")
        }
    }

    private fun dnsLookup(host: String, networkHandle: Long?): Map<String, Any?> {
        val started = System.nanoTime()
        val network = networkHandle?.let(::findNetwork)
        val addresses = (network?.getAllByName(host) ?: InetAddress.getAllByName(host))
            .mapNotNull(InetAddress::getHostAddress)
        return mapOf(
            "host" to host,
            "networkHandle" to networkHandle,
            "addresses" to addresses,
            "durationMs" to elapsedMs(started),
        )
    }

    private fun tlsProbe(host: String, port: Int, attempts: Int, networkHandle: Long?): Map<String, Any?> {
        val outcomes = (1..attempts).map { attempt ->
            tlsProbeOnce(host, port, networkHandle) + mapOf("attempt" to attempt)
        }
        val failures = outcomes.filter { it["success"] == false }
        return mapOf(
            "host" to host,
            "port" to port,
            "networkHandle" to networkHandle,
            "requestedAttempts" to attempts,
            "successfulAttempts" to outcomes.count { it["success"] == true },
            "failedAttempts" to failures.size,
            "failureCountsByStage" to failures
                .groupingBy { it["failedStage"] as String }
                .eachCount(),
            "attempts" to outcomes,
        )
    }

    private fun tlsProbeOnce(host: String, port: Int, networkHandle: Long?): Map<String, Any?> {
        val started = System.nanoTime()
        val startedAt = Instant.now().toString()
        var stage = "dns"
        var stageStarted = started
        var resolvedAddresses = emptyList<String>()
        var dnsDurationMs: Long? = null
        var tcpDurationMs: Long? = null
        var localAddress: String? = null
        var localPort: Int? = null
        var remoteAddress: String? = null
        return try {
            val network = networkHandle?.let(::findNetwork)
            val dnsStarted = System.nanoTime()
            val addresses = (network?.getAllByName(host) ?: InetAddress.getAllByName(host)).toList()
            resolvedAddresses = addresses.mapNotNull(InetAddress::getHostAddress)
            dnsDurationMs = elapsedMs(dnsStarted)

            stage = "tcp_connect"
            stageStarted = System.nanoTime()
            val rawSocket = network?.socketFactory?.createSocket() ?: Socket()
            activeSocket.set(rawSocket)
            val tcpStarted = System.nanoTime()
            rawSocket.connect(InetSocketAddress(addresses.first(), port), PROBE_TIMEOUT_MS)
            tcpDurationMs = elapsedMs(tcpStarted)
            localAddress = rawSocket.localAddress.hostAddress
            localPort = rawSocket.localPort
            remoteAddress = rawSocket.inetAddress.hostAddress

            stage = "tls_handshake"
            stageStarted = System.nanoTime()
            val diagnosticTrustManager = DiagnosticTrustManager()
            val tlsContext = SSLContext.getInstance("TLS")
            tlsContext.init(null, arrayOf<TrustManager>(diagnosticTrustManager), null)
            val tlsStarted = System.nanoTime()
            val socket = tlsContext.socketFactory.createSocket(rawSocket, host, port, true) as SSLSocket
            activeSocket.set(socket)
            socket.soTimeout = PROBE_TIMEOUT_MS
            val parameters = socket.sslParameters
            if (!IP_LITERAL.matches(host)) {
                parameters.serverNames = listOf(SNIHostName(host))
            }
            parameters.applicationProtocols = arrayOf("h2", "http/1.1")
            socket.sslParameters = parameters
            socket.startHandshake()
            val tlsDurationMs = elapsedMs(tlsStarted)
            val session = socket.session
            val chain = session.peerCertificates.map { it as X509Certificate }
            val trustError = validateSystemTrust(chain)
            val hostnameMatches = HttpsURLConnection.getDefaultHostnameVerifier().verify(host, session)
            val leaf = chain.first()
            val validNow = try {
                leaf.checkValidity()
                true
            } catch (_: Exception) {
                false
            }
            mapOf(
                "success" to true,
                "startedAt" to startedAt,
                "completedAt" to Instant.now().toString(),
                "resolvedAddresses" to resolvedAddresses,
                "dnsDurationMs" to dnsDurationMs,
                "localAddress" to localAddress,
                "localPort" to localPort,
                "remoteAddress" to remoteAddress,
                "tcpDurationMs" to tcpDurationMs,
                "tlsDurationMs" to tlsDurationMs,
                "protocol" to session.protocol,
                "cipherSuite" to session.cipherSuite,
                "applicationProtocol" to socket.applicationProtocol,
                "hostnameMatches" to hostnameMatches,
                "validNow" to validNow,
                "systemTrusted" to (trustError == null),
                "trustError" to trustError,
                "certificateChain" to chain.map(::certificateDetails),
            )
        } catch (error: Exception) {
            mapOf(
                "success" to false,
                "startedAt" to startedAt,
                "completedAt" to Instant.now().toString(),
                "failedStage" to stage,
                "failedStageDurationMs" to elapsedMs(stageStarted),
                "resolvedAddresses" to resolvedAddresses,
                "dnsDurationMs" to dnsDurationMs,
                "localAddress" to localAddress,
                "localPort" to localPort,
                "remoteAddress" to remoteAddress,
                "tcpDurationMs" to tcpDurationMs,
                "errorType" to error.javaClass.simpleName,
                "error" to (error.message ?: error.javaClass.simpleName),
                "errorChain" to errorChain(error),
                "totalDurationMs" to elapsedMs(started),
            )
        } finally {
            activeSocket.getAndSet(null)?.close()
        }
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

    private fun findNetwork(handle: Long): Network {
        val manager = getSystemService(ConnectivityManager::class.java)
        return manager.allNetworks.single { it.networkHandle == handle }
    }

    private fun validateSystemTrust(chain: List<X509Certificate>): String? {
        val factory = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
        factory.init(null as KeyStore?)
        val trustManager = factory.trustManagers.filterIsInstance<X509TrustManager>().single()
        return try {
            trustManager.checkServerTrusted(chain.toTypedArray(), chain.first().publicKey.algorithm)
            null
        } catch (error: Exception) {
            error.message ?: error.javaClass.simpleName
        }
    }

    private fun certificateDetails(certificate: X509Certificate): Map<String, Any?> {
        val san = certificate.subjectAlternativeNames?.map { entry ->
            mapOf(
                "type" to when (entry[0] as Int) {
                    2 -> "dns"
                    7 -> "ip"
                    else -> "other"
                },
                "value" to entry[1].toString(),
            )
        } ?: emptyList()
        return mapOf(
            "subject" to certificate.subjectX500Principal.name,
            "issuer" to certificate.issuerX500Principal.name,
            "serialNumber" to certificate.serialNumber.toString(16),
            "notBefore" to certificate.notBefore.toInstant().toString(),
            "notAfter" to certificate.notAfter.toInstant().toString(),
            "signatureAlgorithm" to certificate.sigAlgName,
            "subjectAlternativeNames" to san,
        )
    }

    private fun elapsedMs(started: Long): Long = (System.nanoTime() - started) / 1_000_000

    private fun preferences() = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    private fun saveModelConfig(config: String) {
        ModelConfigPersistence.write(this, config)
    }

    private fun loadModelConfig(): String? {
        // Preferences are read only for configurations saved before database storage.
        ModelConfigPersistence.read(this)?.let { return it }
        val payload = ModelConfigPersistence.read(this, ModelConfigPersistence.LEGACY_KEY)
            ?: preferences().getString(MODEL_CONFIG_KEY, null) ?: return null
        val config = decryptModelConfig(payload)
        ModelConfigPersistence.write(this, config)
        return config
    }

    private fun decryptModelConfig(payload: String): String {
        val parts = payload.split('.', limit = 2)
        val cipher = Cipher.getInstance(CIPHER_TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateSecretKey(),
            GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)),
        )
        return String(
            cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)),
            Charsets.UTF_8,
        )
    }

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(KEY_ALIAS, null)
        if (existing != null) return existing as SecretKey
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    private class DiagnosticTrustManager : X509TrustManager {
        override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) = Unit
        override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) = Unit
        override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
    }

    companion object {
        private const val CHANNEL_NAME = "com.haiskynology.aurai/platform"
        const val ENGINE_ID = "aurai_agent_engine"
        private const val PREFERENCES_NAME = "aurai"
        private const val APP_STATE_KEY = "app_state"
        private const val MODEL_CONFIG_KEY = "model_config"
        private const val KEY_ALIAS = "aurai_model_config_key"
        private const val CIPHER_TRANSFORMATION = "AES/GCM/NoPadding"
        private const val PROBE_TIMEOUT_MS = 10_000
        private const val MAX_NETWORK_EVENTS = 100
        private val IP_LITERAL = Regex("^[0-9a-fA-F:.]+$")
        private var activeChannel: MethodChannel? = null

        private var pendingNotificationConversation: String? = null

        fun notificationOpened(conversationId: String) {
            pendingNotificationConversation = conversationId
            activeChannel?.invokeMethod("notificationOpened", null)
        }

        fun requestAgentStop(conversationId: String? = null) {
            activeChannel?.invokeMethod("stopAgent", conversationId)
        }
    }
}
