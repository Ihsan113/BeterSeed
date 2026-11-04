package com.betterseed.app

import android.app.Application
import android.graphics.Bitmap
import android.graphics.Color
import org.robolectric.RuntimeEnvironment
import java.io.ByteArrayOutputStream
import java.io.File
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LiveWallpaperStoreTest {
    private lateinit var app: Application
    @Before fun before() {
        app = RuntimeEnvironment.getApplication()
        LiveWallpaperStore.prefs(app).edit().clear().commit()
        File(app.noBackupFilesDir, "live_wallpaper").deleteRecursively()
    }
    @After fun after() { before() }
    private fun image(color: Int): ByteArray {
        val bitmap = Bitmap.createBitmap(18, 32, Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(color)
        val output = ByteArrayOutputStream()
        assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, output))
        bitmap.recycle()
        return output.toByteArray()
    }
    private fun stage(color: Int, previous: Boolean = false) {
        LiveWallpaperStore.stage(app, image(color), image(Color.WHITE),
            Color.YELLOW, Color.GREEN, Color.WHITE, previous)
    }
    private fun color(preview: Boolean): Int? {
        val scene = LiveWallpaperStore.load(app, preview) ?: return null
        try { return scene.garden.getPixel(0, 0) } finally { scene.recycle() }
    }

    @Test fun previewDoesNotReplaceTheActiveWallpaperAndCancelPreservesIt() {
        stage(Color.RED)
        assertNull(color(false))
        assertEquals(Color.RED, color(true))
        assertTrue(LiveWallpaperStore.finish(app, true))
        stage(Color.BLUE, true)
        assertTrue(LiveWallpaperStore.previouslyActive(app))
        assertEquals(Color.RED, color(false))
        assertEquals(Color.BLUE, color(true))
        assertFalse(LiveWallpaperStore.finish(app, false))
        assertEquals(Color.RED, color(false))
        assertEquals(Color.RED, color(true))
        assertFalse(LiveWallpaperStore.hasPending(app))
    }

    @Test fun confirmedScenePersistsWithoutAnySourcePackAndCleansOldSnapshots() {
        stage(Color.RED)
        LiveWallpaperStore.finish(app, true)
        stage(Color.BLUE, true)
        assertTrue(LiveWallpaperStore.finish(app, true))
        assertEquals(Color.BLUE, color(false))
        val files = File(app.noBackupFilesDir, "live_wallpaper").listFiles()!!
        assertEquals(1, files.size)
        assertEquals(setOf("scene.json", "butterfly.png", "garden.png"), files[0].list()!!.toSet())
        assertFalse(LiveWallpaperStore.finish(app, true))
        assertEquals(Color.BLUE, color(false))
    }

    @Test fun invalidImagesCannotPublishOrOverwriteAValidSnapshot() {
        stage(Color.RED)
        LiveWallpaperStore.finish(app, true)
        for (bytes in listOf(byteArrayOf(), byteArrayOf(1, 2, 3), image(Color.BLUE).copyOf(32))) {
            try {
                LiveWallpaperStore.stage(app, bytes, image(Color.WHITE), 0, 0, 0, true)
                fail("Invalid image was accepted")
            } catch (_: IllegalArgumentException) { }
            assertFalse(LiveWallpaperStore.hasPending(app))
            assertEquals(Color.RED, color(false))
        }
    }

    @Test fun abandonedPreviewIsReplacedWithoutGrowingPrivateStorage() {
        stage(Color.RED)
        stage(Color.BLUE)
        assertNull(color(false))
        assertEquals(Color.BLUE, color(true))
        assertEquals(1, File(app.noBackupFilesDir, "live_wallpaper").listFiles()!!.size)
        LiveWallpaperStore.finish(app, false)
        assertTrue(File(app.noBackupFilesDir, "live_wallpaper").listFiles()!!.isEmpty())
    }
}
