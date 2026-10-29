package com.betterseed.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.util.Log
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Read-only, battery-friendly widget. Default art bundled; installed packs private. */
class BetterSeedWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateOne(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager,
                                           appWidgetId: Int, newOptions: android.os.Bundle) {
        super.onAppWidgetOptionsChanged(context, manager, appWidgetId, newOptions)
        updateOne(context, manager, appWidgetId)
    }

    companion object {
        private val treeArt = intArrayOf(
            R.drawable.widget_tree_0, R.drawable.widget_tree_1,
            R.drawable.widget_tree_2, R.drawable.widget_tree_3,
            R.drawable.widget_tree_4, R.drawable.widget_tree_5
        )

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, BetterSeedWidget::class.java))
            ids.forEach { updateOne(context, manager, it) }
        }

        // Only Flutter-owned logical tree paths are accepted. Optional pack
        // images are read from the app-private directory after installation.
        private fun bundledTree(context: Context, path: String, installedPath: String): Bitmap? {
            if (!path.matches(Regex("assets/images/trees/(skins/[a-z0-9_]+/)?stage_[0-5]_(seed|sprout|sapling|young|mature|legendary)\\.(png|webp)")) || path.contains("..")) return null
            return try {
                val pack = Regex("assets/images/trees/skins/([a-z0-9_]+)/").find(path)?.groupValues?.get(1)
                val file = if (pack != null) {
                    val root = File(context.filesDir, "garden_packs").canonicalFile
                    val folder = File(root, pack).canonicalFile
                    if (folder.parentFile != root || !File(folder, "installed.json").isFile) return null
                    val expected = File(folder, path).canonicalFile
                    val selected = if (installedPath.isBlank()) expected else File(installedPath).canonicalFile
                    // A channel argument cannot point outside this installed pack.
                    if (selected != expected || !selected.path.startsWith(folder.path + File.separator) || !selected.isFile) return null
                    selected
                } else null
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                if (file != null) file.inputStream().use { BitmapFactory.decodeStream(it, null, bounds) }
                else context.assets.open("flutter_assets/$path").use { BitmapFactory.decodeStream(it, null, bounds) }
                if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
                // BitmapFactory.Options.inSampleSize defaults to 0. Always
                // start from 1 before using it as a divisor, otherwise a
                // valid installed PNG throws ArithmeticException and falls
                // back silently to the bundled Default Garden tree.
                val options = BitmapFactory.Options().apply { inSampleSize = 1 }
                while (bounds.outWidth / options.inSampleSize > 256 || bounds.outHeight / options.inSampleSize > 256) {
                    options.inSampleSize *= 2
                }
                if (file != null) file.inputStream().use { BitmapFactory.decodeStream(it, null, options) }
                else context.assets.open("flutter_assets/$path").use { BitmapFactory.decodeStream(it, null, options) }
            } catch (error: Exception) {
                // Keep widget alive and record why the fallback was used.
                Log.w("BetterSeedWidget", "Tree image fallback: ${error.javaClass.simpleName}")
                null
            }
        }

        private fun updateOne(context: Context, manager: AppWidgetManager, id: Int) {
            val pref = ReminderScheduler.prefs(context)
            val drops = pref.getInt("widget_water", 0).coerceAtLeast(0)
            val stage = pref.getInt("widget_stage", 1).coerceIn(1, 6)
            val currentDay = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val done = if (pref.getString("widget_day", "") == currentDay) {
                pref.getInt("widget_done", 0).coerceAtLeast(0)
            } else 0
            val total = pref.getInt("widget_total", 0).coerceAtLeast(0)
            val views = RemoteViews(context.packageName, R.layout.betterseed_widget)
            views.setTextViewText(R.id.widget_water, "💧 $drops water")
            views.setTextViewText(R.id.widget_stage, "Stage $stage / 6")
            views.setTextViewText(R.id.widget_habits, "$done / $total habits done")
            views.setImageViewResource(R.id.widget_tree_art, treeArt[stage - 1])
            bundledTree(context, pref.getString("widget_tree_asset", "") ?: "",
                pref.getString("widget_tree_file", "") ?: "")?.let {
                views.setImageViewBitmap(R.id.widget_tree_art, it)
            }
            views.setProgressBar(R.id.widget_habit_progress, 100,
                if (total == 0) 0 else (100 * done / total).toInt().coerceIn(0, 100), false)
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                views.setOnClickPendingIntent(R.id.widget_root,
                    PendingIntent.getActivity(context, 9032, launch,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
            manager.updateAppWidget(id, views)
        }
    }
}
