package com.betterseed.app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/** One independent, inexact local daily alarm for every opted-in habit.
 * No exact alarm permission. AlarmManager may delay reminders on battery saver.
 */
object ReminderScheduler {
    const val PREFS = "betterseed_native"
    const val CHANNEL = "betterseed_daily_habits"
    private const val HABITS = "habit_reminders_json"

    fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "Habit reminders", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Gentle reminders for the habits you choose"
                }
            )
        }
    }

    private fun savedHabits(context: Context): JSONArray = try {
        JSONArray(prefs(context).getString(HABITS, "[]") ?: "[]")
    } catch (_: Exception) {
        JSONArray()
    }

    private fun pendingIntent(context: Context, id: String): PendingIntent {
        // Intent.data differentiates habits reliably (requestCode alone need not).
        val intent = Intent(context, ReminderReceiver::class.java)
            .setAction("com.betterseed.app.HABIT_REMINDER")
            .setData(Uri.parse("betterseed://habit/${Uri.encode(id)}"))
            .putExtra("habit_id", id)
        return PendingIntent.getBroadcast(context, 9030, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    fun cancel(context: Context, id: String) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context, id))
    }

    private fun forEachHabit(array: JSONArray, action: (JSONObject) -> Unit) {
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            if (item.optString("id").isNotEmpty()) action(item)
        }
    }

    fun syncHabits(context: Context, newHabits: JSONArray, day: String) {
        // Cancel previous alarms before replacing records so deleted/edited
        // habits never leave ghost reminders behind.
        forEachHabit(savedHabits(context)) { cancel(context, it.optString("id")) }
        prefs(context).edit()
            .putString(HABITS, newHabits.toString())
            .putString("habits_day", day)
            .apply()
        scheduleAll(context)
    }

    fun setMaster(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean("reminder_enabled", enabled).apply()
        scheduleAll(context)
    }

    fun findHabit(context: Context, id: String): JSONObject? {
        val list = savedHabits(context)
        for (i in 0 until list.length()) {
            val item = list.optJSONObject(i) ?: continue
            if (item.optString("id") == id) return item
        }
        return null
    }

    fun scheduleAll(context: Context) {
        val list = savedHabits(context)
        forEachHabit(list) { cancel(context, it.optString("id")) }
        if (!prefs(context).getBoolean("reminder_enabled", false)) return
        createChannel(context)
        forEachHabit(list) { scheduleOne(context, it) }
    }

    fun scheduleOne(context: Context, item: JSONObject) {
        if (!prefs(context).getBoolean("reminder_enabled", false)) return
        if (!item.optBoolean("reminderEnabled", false)) return
        val id = item.optString("id")
        if (id.isEmpty()) return
        val hour = item.optInt("reminderHour", 20).coerceIn(0, 23)
        val minute = item.optInt("reminderMinute", 0).coerceIn(0, 59)
        val now = Calendar.getInstance()
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (!after(now)) add(Calendar.DAY_OF_YEAR, 1)
        }
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
                next.timeInMillis, pendingIntent(context, id))
        } else {
            manager.set(AlarmManager.RTC_WAKEUP,
                next.timeInMillis, pendingIntent(context, id))
        }
    }
}
