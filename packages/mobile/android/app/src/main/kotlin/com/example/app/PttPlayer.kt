package com.example.app

import android.os.Looper
import android.util.Log
import androidx.media3.common.C
import androidx.media3.common.DeviceInfo
import androidx.media3.common.Player
import androidx.media3.common.SimpleBasePlayer
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * Stub player whose only job is to make the system treat us as an active media app so
 * Bluetooth headset media-button events get routed to our [androidx.media3.session.MediaSession].
 * No actual audio is played here — PTT transmission is handled at the Flutter layer.
 *
 * When the user selects the volume button for PTT, the player additionally advertises
 * *remote* device volume. That is the Media3 equivalent of a legacy `VolumeProvider`, and
 * it is the only way to observe Bluetooth headset volume buttons: under AVRCP absolute
 * volume the headset sends SET_ABSOLUTE_VOLUME straight to the audio system and no
 * KeyEvent ever reaches the app. Claiming remote volume makes the framework deliver those
 * steps here as [handleIncreaseDeviceVolume] / [handleDecreaseDeviceVolume] instead.
 *
 * Consequences, by design:
 * - Only discrete steps arrive, never a down/up pair, so headset volume PTT is
 *   toggle-only. This is a protocol limit, not an implementation gap.
 * - Volume is pinned to the middle of the range after every step so there is always
 *   headroom in both directions and the user's real media volume is never changed.
 * - Remote volume is claimed only while the volume button is selected, so we don't
 *   hijack system volume for users who drive PTT from the headset play/pause button.
 */
class PttPlayer : SimpleBasePlayer(Looper.getMainLooper()) {

    private var playWhenReady = true

    private val localDeviceInfo = DeviceInfo.Builder(DeviceInfo.PLAYBACK_TYPE_LOCAL).build()

    private val remoteDeviceInfo = DeviceInfo.Builder(DeviceInfo.PLAYBACK_TYPE_REMOTE)
        .setMinVolume(MIN_VOLUME)
        .setMaxVolume(MAX_VOLUME)
        .build()

    init {
        // Re-publish state when the selected PTT button changes so remote volume control
        // is claimed or released to match the current configuration.
        PttConfig.onButtonChanged = { invalidateState() }
    }

    override fun getState(): State {
        val interceptVolume = PttConfig.volumeButtonSelected
        val commands = Player.Commands.Builder()
            .add(Player.COMMAND_PLAY_PAUSE)
            .add(Player.COMMAND_SET_MEDIA_ITEM)
            .apply {
                if (interceptVolume) {
                    add(Player.COMMAND_GET_DEVICE_VOLUME)
                    add(Player.COMMAND_SET_DEVICE_VOLUME_WITH_FLAGS)
                    add(Player.COMMAND_ADJUST_DEVICE_VOLUME_WITH_FLAGS)
                }
            }
            .build()

        return State.Builder()
            .setAvailableCommands(commands)
            .setPlaybackState(Player.STATE_READY)
            .setPlayWhenReady(playWhenReady, Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST)
            .setDeviceInfo(if (interceptVolume) remoteDeviceInfo else localDeviceInfo)
            .setDeviceVolume(RESTING_VOLUME)
            .build()
    }

    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
        this.playWhenReady = playWhenReady
        invalidateState()
        return Futures.immediateVoidFuture()
    }

    override fun handleIncreaseDeviceVolume(@C.VolumeFlags flags: Int): ListenableFuture<*> {
        return handleVolumeStep("up")
    }

    override fun handleDecreaseDeviceVolume(@C.VolumeFlags flags: Int): ListenableFuture<*> {
        return handleVolumeStep("down")
    }

    override fun handleSetDeviceVolume(
        deviceVolume: Int,
        @C.VolumeFlags flags: Int
    ): ListenableFuture<*> {
        // Absolute-volume headsets report a target level rather than a step. Any change
        // away from our resting level is one physical button press.
        return if (deviceVolume == RESTING_VOLUME) {
            Futures.immediateVoidFuture()
        } else {
            handleVolumeStep(if (deviceVolume > RESTING_VOLUME) "up" else "down")
        }
    }

    private fun handleVolumeStep(direction: String): ListenableFuture<*> {
        Log.d(TAG, "Remote volume step ($direction) → discrete PTT toggle")
        PttEventBus.emitDiscrete()
        // Snap back to the resting level so the next press in either direction is seen.
        invalidateState()
        return Futures.immediateVoidFuture()
    }

    companion object {
        private const val TAG = "PTT"
        private const val MIN_VOLUME = 0
        private const val MAX_VOLUME = 20
        private const val RESTING_VOLUME = 10
    }
}
