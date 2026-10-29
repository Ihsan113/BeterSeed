package com.betterseed.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import android.provider.OpenableColumns
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var gardenWallpaper: GardenWallpaper? = null
    private val channelName = "betterseed/device_features"
    private val notificationRequest = 9033
    private var pendingResult: MethodChannel.Result? = null
    private val backupCreateRequest = 9034
    private val backupOpenRequest = 9035
    private val backupMaxBytes = 4 * 1024 * 1024
    private var pendingBackup: MethodChannel.Result? = null
    private var pendingBackupJson: String? = null
    private val musicOpenRequest = 9036
    private val musicMaxBytes = 25 * 1024 * 1024
    private var pendingMusic: MethodChannel.Result? = null

    private fun musicFile(): File = File(File(filesDir, "betterseed_music"), "custom_background.mp3")

    private fun savedMusic(): Map<String, String>? {
        val file = musicFile()
        if (!file.isFile || file.length() == 0L) return null
        val name = getSharedPreferences("betterseed_local_music", MODE_PRIVATE)
            .getString("display_name", "Imported MP3") ?: "Imported MP3"
        return mapOf("path" to file.absolutePath, "name" to name)
    }


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        gardenWallpaper?.close()
        val wallpaper = GardenWallpaper(this)
        gardenWallpaper = wallpaper
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "betterseed/wallpaper")
            .setMethodCallHandler(wallpaper::handle)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "betterseed/music_files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getImportedMp3" -> result.success(savedMusic())
                    "pickMp3" -> {
                        if (pendingMusic != null) {
                            result.error("MUSIC_BUSY", "A music picker is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingMusic = result
                        try {
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "audio/mpeg"
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }, musicOpenRequest)
                        } catch (e: Exception) {
                            pendingMusic = null
                            result.error("PICKER_UNAVAILABLE", "No MP3 picker available", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "betterseed/backup_documents")
            .setMethodCallHandler { call, result ->
                if (pendingBackup != null) {
                    result.error("BACKUP_BUSY", "File picker is already open", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "createBackup" -> {
                        val text = call.argument<String>("json")
                        val name = call.argument<String>("name")
                        if (text == null || name.isNullOrBlank() || text.toByteArray(Charsets.UTF_8).size > backupMaxBytes) {
                            result.error("BACKUP_INVALID", "Invalid backup content or filename", null)
                            return@setMethodCallHandler
                        }
                        pendingBackup = result
                        pendingBackupJson = text
                        try {
                            startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/json"
                                putExtra(Intent.EXTRA_TITLE, name)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            }, backupCreateRequest)
                        } catch (e: Exception) {
                            pendingBackup = null
                            pendingBackupJson = null
                            result.error("PICKER_UNAVAILABLE", "No file picker available", null)
                        }
                    }
                    "openBackup" -> {
                        pendingBackup = result
                        try {
                            startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*" // Accept JSON also when providers label it text/plain.
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }, backupOpenRequest)
                        } catch (e: Exception) {
                            pendingBackup = null
                            result.error("PICKER_UNAVAILABLE", "No file picker available", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getReminder" -> {
                    result.success(mapOf(
                        "enabled" to ReminderScheduler.prefs(this).getBoolean("reminder_enabled", false),
                        "permissionGranted" to notificationGranted()
                    ))
                }
                "setReminder" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled && !notificationGranted() && Build.VERSION.SDK_INT >= 33) {
                        if (pendingResult != null) {
                            result.error("REQUEST_IN_PROGRESS", "Permission dialog already open", null)
                        } else {
                            pendingResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), notificationRequest)
                        }
                    } else {
                        ReminderScheduler.setMaster(this, enabled)
                        result.success(mapOf("enabled" to enabled, "permissionGranted" to notificationGranted()))
                    }
                }
                "syncHabitReminders" -> {
                    try {
                        val habits = call.argument<List<Map<String, Any?>>>("habits") ?: emptyList()
                        val array = JSONArray()
                        for (h in habits) {
                            array.put(JSONObject().apply {
                                put("id", h["id"]?.toString() ?: "")
                                put("title", h["title"]?.toString() ?: "")
                                put("completed", h["completed"] == true)
                                put("reminderEnabled", h["reminderEnabled"] == true)
                                put("reminderHour", (h["reminderHour"] as? Number)?.toInt() ?: 20)
                                put("reminderMinute", (h["reminderMinute"] as? Number)?.toInt() ?: 0)
                            })
                        }
                        ReminderScheduler.syncHabits(this, array, call.argument<String>("day") ?: "")
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("REMINDER_SYNC", e.message ?: "Sync failed", null)
                    }
                }
                "updateWidget" -> {
                    val pref = ReminderScheduler.prefs(this)
                    pref.edit()
                        .putInt("widget_water", (call.argument<Int>("water") ?: 0).coerceAtLeast(0))
                        .putInt("widget_stage", (call.argument<Int>("stage") ?: 1).coerceIn(1, 6))
                        .putInt("widget_done", (call.argument<Int>("done") ?: 0).coerceAtLeast(0))
                        .putInt("widget_total", (call.argument<Int>("total") ?: 0).coerceAtLeast(0))
                        .putString("widget_day", call.argument<String>("day") ?: "")
                        .putString("widget_theme", call.argument<String>("theme") ?: "default")
                        .putString("widget_tree_asset", call.argument<String>("treeAsset") ?: "")
                        .apply()
                    BetterSeedWidget.updateAll(this)
                    result.success(null)
                }
                "pinWidget" -> {
                    if (Build.VERSION.SDK_INT < 26) {
                        result.success(false)
                    } else {
                        val manager = AppWidgetManager.getInstance(this)
                        val component = ComponentName(this, BetterSeedWidget::class.java)
                        result.success(manager.isRequestPinAppWidgetSupported &&
                            manager.requestPinAppWidget(component, null, null))
                    }
                }
                "widgetInstalled" -> {
                    val manager = AppWidgetManager.getInstance(this)
                    result.success(manager.getAppWidgetIds(
                        ComponentName(this, BetterSeedWidget::class.java)).isNotEmpty())
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        gardenWallpaper?.close()
        gardenWallpaper = null
        super.onDestroy()
    }

    @Deprecated("Uses Android SAF document selection results")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == musicOpenRequest) {
            val reply = pendingMusic ?: return
            pendingMusic = null
            if (resultCode != Activity.RESULT_OK || data?.data == null) {
                reply.success(null)
                return
            }
            val uri = data.data ?: return reply.success(null)
            var displayName = "Imported MP3"
            val target = musicFile()
            val staged = File(target.parentFile, "custom_background.tmp")
            try {
                contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME,
                    OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameColumn >= 0) displayName = cursor.getString(nameColumn) ?: displayName
                        val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                        if (sizeColumn >= 0 && !cursor.isNull(sizeColumn) &&
                            cursor.getLong(sizeColumn) > musicMaxBytes) {
                            reply.error("MUSIC_TOO_LARGE", "Maximum MP3 size is 25 MB", null)
                            return
                        }
                    }
                }
                if (!displayName.lowercase(java.util.Locale.ROOT).endsWith(".mp3")) {
                    reply.error("MUSIC_FORMAT", "Choose an MP3 file", null)
                    return
                }
                target.parentFile?.mkdirs()
                var length = 0L
                val probe = ByteArray(3)
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(staged).use { output ->
                        val buffer = ByteArray(16384)
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            length += n
                            if (length > musicMaxBytes) error("MP3_TOO_LARGE")
                            output.write(buffer, 0, n)
                        }
                        output.fd.sync()
                    }
                } ?: error("No access to selected MP3")
                staged.inputStream().use { it.read(probe) }
                val looksMp3 = (probe[0] == 'I'.code.toByte() &&
                    probe[1] == 'D'.code.toByte() && probe[2] == '3'.code.toByte()) ||
                    ((probe[0].toInt() and 0xFF) == 0xFF &&
                     (probe[1].toInt() and 0xE0) == 0xE0)
                if (length < 256 || !looksMp3) error("NOT_MP3")
                if (!staged.renameTo(target)) error("Unable to save MP3")
                displayName = displayName.take(96)
                getSharedPreferences("betterseed_local_music", MODE_PRIVATE).edit()
                    .putString("display_name", displayName).apply()
                reply.success(mapOf("path" to target.absolutePath, "name" to displayName))
            } catch (e: Exception) {
                reply.error("MUSIC_IMPORT_FAILED", "Could not import MP3. Check format and 25 MB limit", null)
            } finally {
                staged.delete()
            }
            return
        }
        if (requestCode != backupCreateRequest && requestCode != backupOpenRequest) return
        val reply = pendingBackup ?: return
        val content = pendingBackupJson
        pendingBackup = null
        pendingBackupJson = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            if (requestCode == backupCreateRequest) reply.success(false) else reply.success(null)
            return
        }
        try {
            val uri = data.data ?: error("Missing document URI")
            if (requestCode == backupCreateRequest) {
                val json = content ?: error("Missing backup payload")
                val stream = contentResolver.openOutputStream(uri, "wt")
                    ?: error("Unable to write selected document")
                stream.use { it.write(json.toByteArray(Charsets.UTF_8)); it.flush() }
                reply.success(true)
            } else {
                val input = contentResolver.openInputStream(uri)
                    ?: error("Unable to open selected document")
                val bytes = ByteArrayOutputStream()
                input.use { stream ->
                    val chunk = ByteArray(8192)
                    while (true) {
                        val n = stream.read(chunk)
                        if (n == -1) break
                        if (bytes.size() + n > backupMaxBytes) {
                            reply.error("BACKUP_TOO_LARGE", "Backup file exceeds 4 MB", null)
                            return
                        }
                        bytes.write(chunk, 0, n)
                    }
                }
                reply.success(bytes.toByteArray().toString(Charsets.UTF_8))
            }
        } catch (e: Exception) {
            reply.error("DOCUMENT_IO", "Could not read or write selected document", null)
        }
    }

    private fun notificationGranted(): Boolean =
        Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != notificationRequest) return
        val result = pendingResult ?: return
        pendingResult = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        ReminderScheduler.setMaster(this, granted)
        result.success(mapOf("enabled" to granted, "permissionGranted" to granted))
    }
}
