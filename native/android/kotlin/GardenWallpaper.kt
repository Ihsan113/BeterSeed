package com.betterseed.app

import android.app.Activity
import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Applies confirmed still images or opens Android's live preview, without storage permissions. */
class GardenWallpaper(private val activity: Activity) {
    companion object { const val LIVE_REQUEST = 9037 }
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val busy = AtomicBoolean(false)
    @Volatile private var closed = false
    private var liveResult: MethodChannel.Result? = null

    private fun liveSelected(): Boolean = LiveWallpaperStore.isSelected(activity)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val manager = WallpaperManager.getInstance(activity)
        val supported = Build.VERSION.SDK_INT < 23 || manager.isWallpaperSupported
        val allowed = Build.VERSION.SDK_INT < 24 || manager.isSetWallpaperAllowed
        when (call.method) {
            "capabilities" -> result.success(mapOf(
                "supported" to supported,
                "allowed" to (supported && allowed),
                "lockScreen" to (Build.VERSION.SDK_INT >= 24),
                "live" to (supported && allowed && activity.packageManager
                    .hasSystemFeature(PackageManager.FEATURE_LIVE_WALLPAPER))
            ))
            "previewLiveWallpaper" -> {
                if (!supported || !allowed) {
                    result.error("WALLPAPER_NOT_ALLOWED", "Wallpaper changes are not allowed", null)
                    return
                }
                if (!activity.packageManager.hasSystemFeature(PackageManager.FEATURE_LIVE_WALLPAPER)) {
                    result.error("WALLPAPER_UNSUPPORTED", "Live wallpaper is unavailable", null)
                    return
                }
                val png = call.argument<ByteArray>("png")
                val butterfly = call.argument<ByteArray>("butterfly")
                val glow = call.argument<Number>("glow")?.toLong()
                val spark = call.argument<Number>("spark")?.toLong()
                val core = call.argument<Number>("core")?.toLong()
                if (png == null || butterfly == null ||
                    listOf(glow, spark, core).any { it == null || it !in 0L..0xFFFFFFFFL }) {
                    result.error("WALLPAPER_INVALID_IMAGE", "Invalid wallpaper data", null)
                    return
                }
                if (closed || !busy.compareAndSet(false, true)) {
                    result.error("WALLPAPER_BUSY", "Wallpaper change already in progress", null)
                    return
                }
                val previous = liveSelected()
                worker.execute {
                    var error: String? = null
                    try {
                        LiveWallpaperStore.stage(activity, png, butterfly,
                            glow!!.toInt(), spark!!.toInt(), core!!.toInt(), previous)
                    } catch (_: IllegalArgumentException) { error = "WALLPAPER_INVALID_IMAGE" }
                    catch (_: OutOfMemoryError) { error = "WALLPAPER_INVALID_IMAGE" }
                    catch (_: Exception) { error = "WALLPAPER_FAILED" }
                    val failure = error
                    main.post {
                        if (closed) return@post
                        if (failure != null) {
                            busy.set(false)
                            result.error(failure, "Could not prepare live wallpaper", null)
                            return@post
                        }
                        liveResult = result
                        try {
                            activity.startActivityForResult(Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER)
                                .putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
                                    ComponentName(activity, BetterSeedLiveWallpaperService::class.java)), LIVE_REQUEST)
                        } catch (_: ActivityNotFoundException) { finishLive(false, "WALLPAPER_UNSUPPORTED") }
                        catch (_: SecurityException) { finishLive(false, "WALLPAPER_NOT_ALLOWED") }
                    }
                }
            }
            "setWallpaper" -> {
                if (!supported || !allowed) {
                    result.error("WALLPAPER_NOT_ALLOWED", "Wallpaper changes are not allowed", null)
                    return
                }
                val target = call.argument<String>("target")
                if (target !in setOf("home", "lock", "both") ||
                    (Build.VERSION.SDK_INT < 24 && target != "home")) {
                    result.error("WALLPAPER_UNSUPPORTED", "Unsupported wallpaper target", null)
                    return
                }
                val png = call.argument<ByteArray>("png")
                if (png == null || png.isEmpty() || png.size > 20 * 1024 * 1024) {
                    result.error("WALLPAPER_INVALID_IMAGE", "Invalid wallpaper image", null)
                    return
                }
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(png, 0, png.size, bounds)
                if (bounds.outMimeType != "image/png" || bounds.outWidth !in 1..4096 ||
                    bounds.outHeight !in 1..4096 || bounds.outWidth.toLong() * bounds.outHeight > 10_000_000) {
                    result.error("WALLPAPER_INVALID_IMAGE", "Invalid wallpaper dimensions", null)
                    return
                }
                if (closed || !busy.compareAndSet(false, true)) {
                    result.error("WALLPAPER_BUSY", "Wallpaper change already in progress", null)
                    return
                }
                worker.execute {
                    var error: String? = null
                    try {
                        ByteArrayInputStream(png).use { input ->
                            if (Build.VERSION.SDK_INT >= 24) {
                                val flags = when (target) {
                                    "lock" -> WallpaperManager.FLAG_LOCK
                                    "both" -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                                    else -> WallpaperManager.FLAG_SYSTEM
                                }
                                check(manager.setStream(input, null, false, flags) > 0)
                            } else {
                                @Suppress("DEPRECATION")
                                manager.setStream(input)
                            }
                        }
                    } catch (_: SecurityException) {
                        error = "WALLPAPER_NOT_ALLOWED"
                    } catch (_: OutOfMemoryError) {
                        error = "WALLPAPER_INVALID_IMAGE"
                    } catch (_: Exception) {
                        error = "WALLPAPER_FAILED"
                    }
                    val failure = error
                    main.post {
                        busy.set(false)
                        if (!closed) {
                            if (failure == null) result.success(true)
                            else result.error(failure, "Could not apply wallpaper", null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != LIVE_REQUEST) return false
        // Some launchers return CANCELED after applying. Accept that only on a
        // verified first activation; canceling an already active scene must not edit it.
        val confirmed = liveSelected() && (resultCode == Activity.RESULT_OK ||
            !LiveWallpaperStore.previouslyActive(activity))
        finishLive(confirmed)
        return true
    }

    private fun finishLive(confirmed: Boolean, failure: String? = null) {
        val reply = liveResult
        liveResult = null
        worker.execute {
            var error = failure
            try { LiveWallpaperStore.finish(activity, confirmed && failure == null) }
            catch (_: Exception) { error = "WALLPAPER_FAILED" }
            val resultError = error
            main.post {
                busy.set(false)
                if (!closed && reply != null) {
                    if (resultError != null) reply.error(resultError, "Could not update live wallpaper", null)
                    else reply.success(confirmed)
                }
            }
        }
    }

    fun close() {
        closed = true
        worker.shutdown()
    }
}
