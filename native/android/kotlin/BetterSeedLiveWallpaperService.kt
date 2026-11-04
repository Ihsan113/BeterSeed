package com.betterseed.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/** A silent, offline Canvas wallpaper. No Flutter engine, video decoder, audio,
 * wake lock, alarm, network or foreground service is needed for playback. */
class BetterSeedLiveWallpaperService : WallpaperService() {
    override fun onCreateEngine(): Engine = GardenEngine()

    inner class GardenEngine : Engine(), SharedPreferences.OnSharedPreferenceChangeListener {
        private val main = Handler(Looper.getMainLooper())
        private val loader = Executors.newSingleThreadExecutor()
        private val power by lazy { getSystemService(Context.POWER_SERVICE) as PowerManager }
        private var scene: LiveWallpaperStore.Scene? = null
        private var visible = false
        private var surfaceReady = false
        private var destroyed = false
        private var generation = 0
        private var time = 0.0
        private var lastFrame = 0L
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        private val destination = RectF()
        private val source = Rect()
        private val frame = Runnable { drawFrame() }
        private val screen = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) { redraw() }
        }

        override fun onCreate(holder: SurfaceHolder) {
            super.onCreate(holder)
            setTouchEventsEnabled(false)
            setOffsetNotificationsEnabled(false)
            LiveWallpaperStore.prefs(this@BetterSeedLiveWallpaperService)
                .registerOnSharedPreferenceChangeListener(this)
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_SCREEN_ON)
                addAction(Intent.ACTION_SCREEN_OFF)
                addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
            }
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(screen, filter, Context.RECEIVER_NOT_EXPORTED)
            else @Suppress("DEPRECATION") registerReceiver(screen, filter)
            reload()
        }

        override fun onSharedPreferenceChanged(prefs: SharedPreferences?, key: String?) {
            if (key == "active" || (isPreview && key == "pending")) reload()
        }

        private fun reload() {
            if (destroyed) return
            val current = ++generation
            val preview = isPreview
            loader.execute {
                val next = try {
                    // Recover first activation if Android recreated the Activity/process in its picker.
                    val selected = LiveWallpaperStore.isSelected(this@BetterSeedLiveWallpaperService)
                    if (!preview && selected && LiveWallpaperStore.hasPending(this@BetterSeedLiveWallpaperService) &&
                        !LiveWallpaperStore.previouslyActive(this@BetterSeedLiveWallpaperService))
                        LiveWallpaperStore.finish(this@BetterSeedLiveWallpaperService, true)
                    LiveWallpaperStore.load(this@BetterSeedLiveWallpaperService, preview)
                } catch (_: Exception) { null } catch (_: OutOfMemoryError) { null }
                main.post {
                    if (destroyed || generation != current) { next?.recycle(); return@post }
                    val old = scene
                    scene = next
                    old?.recycle()
                    redraw()
                }
            }
        }

        override fun onVisibilityChanged(isVisible: Boolean) {
            visible = isVisible
            redraw()
        }
        override fun onSurfaceCreated(holder: SurfaceHolder) {
            super.onSurfaceCreated(holder)
            surfaceReady = true
            redraw()
        }
        override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
            super.onSurfaceChanged(holder, format, width, height)
            redraw()
        }
        override fun onSurfaceDestroyed(holder: SurfaceHolder) {
            surfaceReady = false
            main.removeCallbacks(frame)
            super.onSurfaceDestroyed(holder)
        }
        private fun redraw() {
            main.removeCallbacks(frame)
            lastFrame = 0
            if (!destroyed && visible && surfaceReady && power.isInteractive) drawFrame()
        }

        private fun drawFrame() {
            if (destroyed || !visible || !surfaceReady || !power.isInteractive) return
            val animate = !power.isPowerSaveMode && Settings.Global.getFloat(contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE, 1f) != 0f
            val now = SystemClock.uptimeMillis()
            if (lastFrame != 0L && animate) time += ((now - lastFrame).coerceAtMost(100)) / 1000.0
            lastFrame = now
            var canvas: Canvas? = null
            try {
                canvas = if (Build.VERSION.SDK_INT >= 26) {
                    try { surfaceHolder.lockHardwareCanvas() }
                    catch (_: Exception) { surfaceHolder.lockCanvas() }
                } else surfaceHolder.lockCanvas()
                if (canvas != null) render(canvas)
            } catch (_: IllegalArgumentException) {
                // Launcher can destroy its surface between the callback and lockCanvas.
            } catch (_: IllegalStateException) {
            } finally {
                if (canvas != null) try { surfaceHolder.unlockCanvasAndPost(canvas) } catch (_: Exception) { }
            }
            if (animate && scene != null && !destroyed && visible && surfaceReady)
                main.postDelayed(frame, 42L) // At most 24 fps; no callbacks while hidden/screen off.
        }

        private fun render(canvas: Canvas) {
            canvas.drawColor(Color.rgb(7, 24, 32))
            val data = scene
            if (data == null) {
                paint.color = Color.rgb(158, 247, 189)
                paint.textAlign = Paint.Align.CENTER
                paint.textSize = 16f * resources.displayMetrics.scaledDensity
                canvas.drawText(BetterSeedLocale.context(this@BetterSeedLiveWallpaperService)
                    .getString(com.betterseed.app.R.string.live_wallpaper_setup),
                    canvas.width / 2f, canvas.height / 2f, paint)
                return
            }
            paint.color = Color.WHITE
            val w = data.garden.width.toFloat()
            val h = data.garden.height.toFloat()
            val scale = maxOf(canvas.width / w, canvas.height / h)
            canvas.save()
            canvas.translate((canvas.width - w * scale) / 2, (canvas.height - h * scale) / 2)
            canvas.scale(scale, scale)
            canvas.drawBitmap(data.garden, 0f, 0f, paint)
            val unit = w / 390f
            for (i in 0 until 16) {
                val x = (w * (.09 + .82 * ((i * 37 + 11) % 97) / 97) + sin(time * .35 + i) * 10 * unit).toFloat()
                val y = (h * (.16 + .70 * ((i * 29 + 7) % 89) / 89) + cos(time * .28 + i) * 12 * unit).toFloat()
                val alpha = .35 + .5 * (.5 + .5 * sin(time * 1.4 + i))
                val radius = (1.3f + i % 3 * .4f) * unit
                paint.color = data.glow; paint.alpha = (255 * alpha * .16).toInt()
                canvas.drawCircle(x, y, radius * 4, paint)
                paint.color = data.spark; paint.alpha = (255 * alpha * .5).toInt()
                canvas.drawCircle(x, y, radius * 1.8f, paint)
                paint.color = data.core; paint.alpha = (255 * alpha).toInt()
                canvas.drawCircle(x, y, radius, paint)
            }
            paint.color = Color.WHITE
            source.set(0, 0, data.butterfly.width, data.butterfly.height)
            for (i in 0 until 3) {
                val anchorX = when (i) { 0 -> .22; 1 -> .76; else -> .52 }
                val anchorY = when (i) { 0 -> .42; 1 -> .32; else -> .65 }
                val width = w * when (i) { 0 -> .085f; 1 -> .075f; else -> .065f }
                val height = width * data.butterfly.height / data.butterfly.width
                canvas.save()
                canvas.translate((w * (anchorX + sin(time * .48 + i) * .025)).toFloat(),
                    (h * (anchorY + cos(time * .37 + i) * .02)).toFloat())
                canvas.rotate((sin(time * .6 + i) * .12 * 180 / Math.PI).toFloat())
                canvas.scale((.55 + .45 * abs(sin(time * 3 + i))).toFloat(), 1f)
                destination.set(-width / 2, -height / 2, width / 2, height / 2)
                canvas.drawBitmap(data.butterfly, source, destination, paint)
                canvas.restore()
            }
            canvas.restore()
        }

        override fun onDestroy() {
            destroyed = true
            ++generation
            main.removeCallbacks(frame)
            LiveWallpaperStore.prefs(this@BetterSeedLiveWallpaperService)
                .unregisterOnSharedPreferenceChangeListener(this)
            unregisterReceiver(screen)
            loader.shutdown()
            scene?.recycle()
            scene = null
            super.onDestroy()
        }
    }
}
