package com.example.app

import android.content.Intent
import android.util.Log
import android.view.KeyEvent
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionResult
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Foreground MediaSessionService that owns the PTT media session so Bluetooth headset
 * play/pause events keep arriving even when the activity is backgrounded or the screen
 * is off. Raw KeyEvents are forwarded to [PttEventBus] for the activity to translate
 * into Flutter MethodChannel calls.
 */
class PttMediaSessionService : MediaSessionService() {

    private var mediaSession: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val player = PttPlayer()
        mediaSession = MediaSession.Builder(this, player)
            .setId("PelotonPTT")
            .setCallback(PttSessionCallback())
            .build()
        Log.d(TAG, "MediaSession created")
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = mediaSession

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
            mediaSession = null
        }
        super.onDestroy()
    }

    private class PttSessionCallback : MediaSession.Callback {
        override fun onMediaButtonEvent(
            session: MediaSession,
            controllerInfo: MediaSession.ControllerInfo,
            intent: Intent
        ): Boolean {
            val key: KeyEvent? = @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)
            if (key == null) return false

            return when (key.keyCode) {
                KeyEvent.KEYCODE_HEADSETHOOK,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                KeyEvent.KEYCODE_MEDIA_PLAY,
                KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                    Log.d(TAG, "MediaButton intercepted: keyCode=${key.keyCode} action=${key.action}")
                    PttEventBus.emit(key)
                    true
                }
                else -> false
            }
        }

        override fun onConnect(
            session: MediaSession,
            controller: MediaSession.ControllerInfo
        ): MediaSession.ConnectionResult {
            return MediaSession.ConnectionResult.AcceptedResultBuilder(session).build()
        }
    }

    companion object {
        private const val TAG = "PTT"
    }
}
