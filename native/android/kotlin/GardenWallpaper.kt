package com.betterseed.app

import android.app.Activity
import android.app.WallpaperManager
import android.graphics.BitmapFactory
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Applies only an explicitly confirmed still image, without storage permissions. */
class GardenWallpaper(private val activity: Activity) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val busy = AtomicBoolean(false)
    @Volatile private var closed = false

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val manager = WallpaperManager.getInstance(activity)
        val supported = Build.VERSION.SDK_INT < 23 || manager.isWallpaperSupported
        val allowed = Build.VERSION.SDK_INT < 24 || manager.isSetWallpaperAllowed
        when (call.method) {
            "capabilities" -> result.success(mapOf(
                "supported" to supported,
                "allowed" to (supported && allowed),
                "lockScreen" to (Build.VERSION.SDK_INT >= 24)
            ))
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

    fun close() {
        closed = true
        worker.shutdown()
    }
}
