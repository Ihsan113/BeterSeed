package com.betterseed.app

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pref = ReminderScheduler.prefs(context)
        if (!pref.getBoolean("reminder_enabled", false)) return
        val id = intent.getStringExtra("habit_id") ?: return
        val habit = ReminderScheduler.findHabit(context, id) ?: return
        if (!habit.optBoolean("reminderEnabled", false)) return
        // Rearm tomorrow before checking whether today's habit is complete.
        ReminderScheduler.scheduleOne(context, habit)
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        if (pref.getString("habits_day", "") == today && habit.optBoolean("completed", false)) return
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        ReminderScheduler.createChannel(context)
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = launch?.let {
            PendingIntent.getActivity(context, 9031, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ReminderScheduler.CHANNEL)
        } else {
            Notification.Builder(context)
        }
        builder.setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("A moment for your habit 🌱")
            .setContentText(habit.optString("title", "Time to grow your BetterSeed garden"))
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            builder.setPriority(Notification.PRIORITY_DEFAULT)
        }
        if (pending != null) builder.setContentIntent(pending)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify("habit_$id", 1, builder.build())
    }
}
