package com.example.app

import android.view.KeyEvent

/**
 * Bridges PTT input events from the long-lived [PttMediaSessionService] to whichever
 * [MainActivity] instance is currently attached to the Flutter engine.
 */
object PttEventBus {
    /** Raw key events (BT play/pause, headsethook) that carry a real DOWN/UP action. */
    @Volatile var listener: ((KeyEvent) -> Unit)? = null

    /**
     * Discrete "the user pressed something once" events that carry no press/release pair.
     * Bluetooth headset volume buttons land here: with AVRCP absolute volume the headset
     * sends a volume step to the audio system, so a single callback is all we ever get —
     * there is no hold duration to observe. Consumers must treat these as toggles.
     */
    @Volatile var discreteListener: (() -> Unit)? = null

    fun emit(event: KeyEvent) {
        listener?.invoke(event)
    }

    fun emitDiscrete() {
        discreteListener?.invoke()
    }
}
