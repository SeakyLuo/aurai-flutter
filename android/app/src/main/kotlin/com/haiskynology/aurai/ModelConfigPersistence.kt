package com.haiskynology.aurai

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase

/** The encrypted configuration shares the AI selection's SQLite commit boundary. */
object ModelConfigPersistence {
    const val KEY = "model_config_json"
    const val LEGACY_KEY = "encrypted_model_config"

    fun read(context: Context, key: String = KEY): String? {
        val file = context.getDatabasePath("aurai.sqlite")
        if (!file.exists()) return null
        return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
            val initialized = db.rawQuery("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'app_state'", null).use { it.moveToFirst() }
            if (!initialized) return@use null
            db.query("app_state", arrayOf("value"), "key = ?", arrayOf(key), null, null, null).use {
                if (it.moveToFirst()) it.getString(0) else null
            }
        }
    }

    fun write(context: Context, config: String) {
        SQLiteDatabase.openDatabase(context.getDatabasePath("aurai.sqlite").path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
            val values = ContentValues().apply { put("key", KEY); put("value", config) }
            check(db.insertWithOnConflict("app_state", null, values, SQLiteDatabase.CONFLICT_REPLACE) != -1L) { "无法保存模型设置" }
        }
    }
}
