package com.betterseed.app

import android.content.Context
import android.content.ComponentName
import android.app.WallpaperManager
import android.os.Build
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/** Immutable, private snapshots. Pending previews never replace an active scene.
 * No account data, remote URLs, file paths from Flutter, or CDN dependencies. */
object LiveWallpaperStore {
    const val PREFS = "betterseed_live_wallpaper"
    private const val ACTIVE = "active"
    private const val PENDING = "pending"
    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    fun isSelected(context: Context): Boolean {
        val manager = WallpaperManager.getInstance(context)
        val component = ComponentName(context, BetterSeedLiveWallpaperService::class.java)
        return manager.wallpaperInfo?.component == component ||
            (Build.VERSION.SDK_INT >= 34 && manager.getWallpaperInfo(WallpaperManager.FLAG_LOCK)?.component == component)
    }
    private fun root(context: Context) = File(context.noBackupFilesDir, "live_wallpaper").apply { mkdirs() }
    private fun folder(context: Context, id: String): File {
        require(Regex("[a-f0-9-]{36}").matches(id))
        return File(root(context), id)
    }

    private fun validate(bytes: ByteArray, maxBytes: Int, maxSide: Int, maxPixels: Long, pngOnly: Boolean) {
        require(bytes.isNotEmpty() && bytes.size <= maxBytes)
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        require(bounds.outWidth in 1..maxSide && bounds.outHeight in 1..maxSide &&
            bounds.outWidth.toLong() * bounds.outHeight <= maxPixels)
        require(if (pngOnly) bounds.outMimeType == "image/png" else
            bounds.outMimeType in setOf("image/png", "image/webp"))
    }

    @Synchronized
    fun stage(context: Context, png: ByteArray, butterfly: ByteArray,
              glow: Int, spark: Int, core: Int, previouslyActive: Boolean) {
        validate(png, 20 * 1024 * 1024, 4096, 10_000_000, true)
        validate(butterfly, 4 * 1024 * 1024, 2048, 4_000_000, false)
        val id = UUID.randomUUID().toString()
        val dir = folder(context, id).apply { check(mkdirs()) }
        try {
            for ((name, bytes) in listOf("garden.png" to png, "butterfly.png" to butterfly,
                "scene.json" to JSONObject().put("version", 1).put("glow", glow)
                    .put("spark", spark).put("core", core).toString().toByteArray())) {
                FileOutputStream(File(dir, name)).use { it.write(bytes); it.fd.sync() }
            }
            // Decode before publishing, so truncated/invalid pixel data cannot replace a scene.
            decode(File(dir, "garden.png"), 2560).recycle()
            decode(File(dir, "butterfly.png"), 256).recycle()
            check(prefs(context).edit().putString(PENDING, id)
                .putBoolean("previously_active", previouslyActive).commit())
            cleanup(context)
        } catch (e: Throwable) {
            dir.deleteRecursively()
            throw e
        }
    }

    @Synchronized
    fun finish(context: Context, confirmed: Boolean): Boolean {
        val pref = prefs(context)
        val pending = pref.getString(PENDING, null) ?: return false
        val editor = pref.edit().remove(PENDING).remove("previously_active")
        if (confirmed) editor.putString(ACTIVE, pending)
        check(editor.commit())
        cleanup(context)
        return confirmed
    }

    fun previouslyActive(context: Context) = prefs(context).getBoolean("previously_active", false)

    @Synchronized
    fun hasPending(context: Context) = prefs(context).contains(PENDING)

    private fun cleanup(context: Context) {
        val pref = prefs(context)
        val keep = setOf(pref.getString(ACTIVE, null), pref.getString(PENDING, null))
        root(context).listFiles()?.filter { it.isDirectory && it.name !in keep }?.forEach { it.deleteRecursively() }
    }

    private fun decode(file: File, maxSide: Int): Bitmap {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, options)
        require(options.outWidth > 0 && options.outHeight > 0)
        options.inSampleSize = 1
        while (maxOf(options.outWidth, options.outHeight) / options.inSampleSize > maxSide)
            options.inSampleSize *= 2
        options.inJustDecodeBounds = false
        return requireNotNull(BitmapFactory.decodeFile(file.path, options))
    }

    data class Scene(val garden: Bitmap, val butterfly: Bitmap, val glow: Int, val spark: Int, val core: Int) {
        fun recycle() { garden.recycle(); butterfly.recycle() }
    }

    @Synchronized
    fun load(context: Context, preview: Boolean): Scene? {
        val pref = prefs(context)
        val id = (if (preview) pref.getString(PENDING, null) else null)
            ?: pref.getString(ACTIVE, null) ?: return null
        val dir = folder(context, id)
        val data = JSONObject(File(dir, "scene.json").readText())
        require(data.getInt("version") == 1)
        val garden = decode(File(dir, "garden.png"), 2560)
        try {
            return Scene(garden, decode(File(dir, "butterfly.png"), 256),
                data.getInt("glow"), data.getInt("spark"), data.getInt("core"))
        } catch (e: Throwable) { garden.recycle(); throw e }
    }
}
