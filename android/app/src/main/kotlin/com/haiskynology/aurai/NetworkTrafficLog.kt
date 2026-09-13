package com.haiskynology.aurai

import java.time.Instant

/** Metadata only. Never retains payloads, credentials, cookies, or decrypted content. */
object NetworkTrafficLog {
    private val entries = ArrayDeque<Flow>()
    private var sequence = 0L
    class Flow(val id: Long, val host: String, val port: Int, val protocol: String) {
        val startedAt = Instant.now().toString()
        var sent = 0L
        var received = 0L
        var status = "connecting"
    }
    @Synchronized fun open(host: String, port: Int, protocol: String): Flow {
        val flow = Flow(++sequence, host, port, protocol)
        entries.addLast(flow)
        if (entries.size > 500) entries.removeFirst()
        return flow
    }
    @Synchronized fun update(flow: Flow, sent: Int = 0, received: Int = 0, status: String = "active") {
        flow.sent += sent
        flow.received += received
        flow.status = status
    }
    @Synchronized fun read(limit: Int, after: Long): Map<String, Any?> {
        require(limit in 1..100 && after >= 0)
        val selected = entries.filter { it.id > after }.take(limit)
        return mapOf(
            "records" to selected.map { flow -> mapOf(
                "sequence" to flow.id, "startedAt" to flow.startedAt,
                "host" to flow.host, "port" to flow.port, "protocol" to flow.protocol,
                "sentBytes" to flow.sent, "receivedBytes" to flow.received, "status" to flow.status,
            ) },
            "nextCursor" to (selected.lastOrNull()?.id ?: after),
            "retainedCount" to entries.size,
            "oldestCursor" to entries.firstOrNull()?.id,
            "scope" to "Connection metadata only; host may be an IP. No HTTPS contents, URLs, headers or bodies. Aurai itself is excluded.",
        )
    }
    @Synchronized fun clear() { entries.clear() }
}
