package com.example.app

/**
 * PTT configuration shared between [MainActivity] (which receives it over the
 * MethodChannel) and [PttMediaSessionService] / [PttPlayer], which run in the same
 * process but outlive the activity.
 *
 * [PttPlayer] reads [button] to decide whether to claim remote volume control, so the
 * media session only intercepts volume keys while the user has actually selected the
 * volume button for PTT.
 */
object PttConfig {
    @Volatile var mode: String = "toggle"
    @Volatile var button: String = "volumeDown"

    /** Invoked when [button] changes so the player can re-publish its device info. */
    @Volatile var onButtonChanged: (() -> Unit)? = null

    val volumeButtonSelected: Boolean
        get() = button == "volume"

    fun update(mode: String, button: String) {
        val buttonChanged = this.button != button
        this.mode = mode
        this.button = button
        if (buttonChanged) onButtonChanged?.invoke()
    }
}
