package com.example.app

import android.os.Looper
import androidx.media3.common.Player
import androidx.media3.common.SimpleBasePlayer
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Stub player whose only job is to make the system treat us as an active media app so
 * Bluetooth headset media-button events get routed to our [androidx.media3.session.MediaSession].
 * No actual audio is played here — PTT recording is handled at the Flutter layer.
 */
class PttPlayer : SimpleBasePlayer(Looper.getMainLooper()) {

    private var playWhenReady = true

    override fun getState(): State {
        return State.Builder()
            .setAvailableCommands(
                Player.Commands.Builder()
                    .add(Player.COMMAND_PLAY_PAUSE)
                    .add(Player.COMMAND_SET_MEDIA_ITEM)
                    .build()
            )
            .setPlaybackState(Player.STATE_READY)
            .setPlayWhenReady(playWhenReady, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
            .build()
    }

    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
        this.playWhenReady = playWhenReady
        invalidateState()
        return Futures.immediateVoidFuture()
    }
}
