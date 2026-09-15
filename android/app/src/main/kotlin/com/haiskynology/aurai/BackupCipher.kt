package com.haiskynology.aurai

import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/** Portable encryption: restore never depends on the old Android Keystore. */
object BackupCipher {
    private val magic = "AURAI001".toByteArray(Charsets.US_ASCII)
    private const val BLOCK = 1024 * 1024
    private fun key(password: String, salt: ByteArray): SecretKeySpec {
        val spec = PBEKeySpec(password.toCharArray(), salt, 210000, 256)
        val bytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        spec.clearPassword()
        return SecretKeySpec(bytes, "AES").also { bytes.fill(0) }
    }
    private fun crypt(mode: Int, key: SecretKeySpec, header: ByteArray, index: Int, bytes: ByteArray): ByteArray {
        val counter = ByteBuffer.allocate(4).putInt(index).array()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(mode, key, GCMParameterSpec(128, header.takeLast(8).toByteArray() + counter))
        cipher.updateAAD(header + counter)
        return cipher.doFinal(bytes)
    }
    fun encrypt(output: OutputStream, password: String, write: (OutputStream) -> Unit) {
        val random = SecureRandom()
        val salt = ByteArray(16).also(random::nextBytes)
        val header = magic + salt + ByteArray(8).also(random::nextBytes)
        val key = key(password, salt)
        val target = DataOutputStream(output)
        target.write(header)
        // Independently authenticated chunks keep large media backups bounded in memory.
        val chunks = object : OutputStream() {
            val buffer = ByteArray(BLOCK)
            var count = 0
            var index = 0
            fun emit(bytes: ByteArray) {
                check(index < Int.MAX_VALUE) { "备份文件过大" }
                val encrypted = crypt(Cipher.ENCRYPT_MODE, key, header, index++, bytes)
                target.writeInt(encrypted.size); target.write(encrypted)
            }
            override fun write(value: Int) { write(byteArrayOf(value.toByte()), 0, 1) }
            override fun write(bytes: ByteArray, offset: Int, length: Int) {
                var at = offset
                var left = length
                while (left > 0) {
                    val size = minOf(left, BLOCK - count)
                    bytes.copyInto(buffer, count, at, at + size)
                    count += size; at += size; left -= size
                    if (count == BLOCK) { emit(buffer); count = 0 }
                }
            }
            // The owner finishes after ZipOutputStream closes, including its central directory.
            override fun close() = Unit
            fun finish() {
                if (count > 0) emit(buffer.copyOf(count))
                emit(ByteArray(0)) // Authenticated end marker detects truncation at a chunk boundary.
                buffer.fill(0)
                target.flush()
            }
        }
        write(chunks)
        chunks.finish()
    }
    fun decrypt(input: InputStream, output: OutputStream, password: String) {
        val source = DataInputStream(input)
        val header = ByteArray(32).also(source::readFully)
        require(header.copyOfRange(0, 8).contentEquals(magic)) { "不是支持的 Aurai 备份文件" }
        val key = key(password, header.copyOfRange(8, 24))
        var index = 0
        while (true) {
            val size = source.readInt()
            require(size in 16..BLOCK + 16 && index < Int.MAX_VALUE) { "备份数据格式无效" }
            val bytes = ByteArray(size).also(source::readFully)
            val plain = crypt(Cipher.DECRYPT_MODE, key, header, index++, bytes)
            if (plain.isEmpty()) { require(source.read() == -1) { "备份包含多余数据" }; break }
            output.write(plain)
        }
        // Verify every chunk and the end marker before inspecting or installing the archive.
    }
}
