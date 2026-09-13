package com.haiskynology.aurai

object TunnelEngine {
    init { System.loadLibrary("aurai-tunnel") }
    external fun start(config: String, fd: Int): Boolean
    external fun isRunning(): Boolean
    external fun stop()
}
