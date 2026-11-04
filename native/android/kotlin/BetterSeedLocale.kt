package com.betterseed.app

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/** Follow the user's in-app choice, including when the process is not running. */
object BetterSeedLocale {
    fun context(base: Context): Context {
        val saved = ReminderScheduler.prefs(base).getString("widget_language", "en-US") ?: "en-US"
        val language = if (saved in setOf("en-US", "id", "ja", "de", "fr", "es-419", "pt-BR")) saved else "en-US"
        val config = Configuration(base.resources.configuration)
        config.setLocale(Locale.forLanguageTag(language))
        return base.createConfigurationContext(config)
    }
}
