package com.haiskynology.aurai

import java.security.MessageDigest

object DocumentRevision {
    fun hash(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes)
        .joinToString("") { "%02x".format(it) }

    fun require(bytes: ByteArray, expected: String) {
        kotlin.require(expected.matches(Regex("[0-9a-f]{64}"))) { "文件 revision 无效" }
        kotlin.require(hash(bytes) == expected) { "文件已被其他操作修改，请重新读取后再修改" }
    }
}
