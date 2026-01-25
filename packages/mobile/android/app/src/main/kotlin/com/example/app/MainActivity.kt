package com.example.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.os.Bundle
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.support.v4.media.MediaMetadataCompat
import android.util.Log
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.peloton/ptt"
    private val PERMISSION_REQUEST_CODE = 123
    private val LONG_PRESS_TIMEOUT = 200L // 200ms - shorter than OS timeout
    private lateinit var mediaSession: MediaSessionCompat
    private lateinit var channel: MethodChannel
    private var isRecording = false
    private var lastPressTime = 0L
    private val DOUBLE_PRESS_INTERVAL = 300L // 300ms to prevent accidental double press
    private var pttMode = "toggle" // Current PTT mode (toggle or hold)
    private var pttButton = "volumeDown" // Current PTT button configuration
    private var preventScreenLock = true // Keep screen on during rides

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Setup method call handler for Flutter->Android communication
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setPTTMode" -> {
                    pttMode = call.arguments as String
                    Log.d("PTT", "PTT mode set to: $pttMode")
                    result.success(null)
                }
                "updatePTTConfiguration" -> {
                    val args = call.arguments as? Map<String, Any>
                    if (args != null) {
                        pttMode = args["mode"] as? String ?: pttMode
                        pttButton = args["button"] as? String ?: pttButton
                        preventScreenLock = args["preventScreenLock"] as? Boolean ?: preventScreenLock

                        Log.d("PTT", "Configuration updated: mode=$pttMode, button=$pttButton, preventScreenLock=$preventScreenLock")

                        // Update screen lock behavior
                        if (preventScreenLock) {
                            window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }

                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Invalid arguments", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        checkPermissionsAndSetupMediaSession()
        Log.d("PTT", "Flutter engine configured and permission check initiated")
    }
    
    private fun checkPermissionsAndSetupMediaSession() {
        val permissions = arrayOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.BLUETOOTH_CONNECT
        )
        
        val permissionsNeeded = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        
        if (permissionsNeeded.isNotEmpty()) {
            Log.d("PTT", "Requesting permissions: $permissionsNeeded")
            ActivityCompat.requestPermissions(this, permissionsNeeded.toTypedArray(), PERMISSION_REQUEST_CODE)
        } else {
            Log.d("PTT", "All permissions granted, setting up MediaSession")
            setupMediaSession()
        }
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            Log.d("PTT", "Permissions result - all granted: $allGranted")
            if (allGranted) {
                setupMediaSession()
            } else {
                Log.w("PTT", "Some permissions were denied")
                // Still try to setup media session as RECORD_AUDIO might not be critical for button events
                setupMediaSession()
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("PTT", "onNewIntent called with action: ${intent.action}")
        if (Intent.ACTION_MEDIA_BUTTON == intent.action) {
            Log.d("PTT", "Media button intent received in onNewIntent")
            mediaSession.controller.dispatchMediaButtonEvent(
                intent.getParcelableExtra(Intent.EXTRA_KEY_EVENT)!!
            )
        }
    }

    private fun setupMediaSession() {
        Log.d("PTT", "Setting up MediaSession...")
        mediaSession = MediaSessionCompat(this, "PelotonPTT")
        
        // Set flags to make our session more aggressive
        mediaSession.setFlags(
            MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or 
            MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
        )
        
        // Set playback state to enable media button events with higher priority
        val playbackState = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or 
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_STOP or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS
            )
            .setState(PlaybackStateCompat.STATE_PLAYING, 0, 1.0f) // Set to PLAYING for higher priority
            .build()
        
        mediaSession.setPlaybackState(playbackState)
        Log.d("PTT", "Playback state set: ${playbackState.state}")
        
        // Set metadata to make our session more prominent
        val metadata = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, "Peloton PTT Active")
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, "Push-to-Talk Ready")
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Peloton Communicator")
            .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, 1000000) // Long duration
            .build()
        mediaSession.setMetadata(metadata)
        
        mediaSession.setCallback(object : MediaSessionCompat.Callback() {
            override fun onPlay() {
                Log.d("PTT", "MediaSession: Play command received")
                if (pttButton == "playPause") {
                    handleMediaButtonPress()
                }
            }

            override fun onPause() {
                Log.d("PTT", "MediaSession: Pause command received")
                if (pttButton == "playPause") {
                    handleMediaButtonPress()
                }
            }

            override fun onMediaButtonEvent(mediaButtonEvent: Intent): Boolean {
                val keyEvent = mediaButtonEvent.getParcelableExtra<KeyEvent>(Intent.EXTRA_KEY_EVENT)
                keyEvent?.let {
                    Log.d("PTT", "MediaSession: Media button event: keyCode=${it.keyCode}, action=${it.action}")
                    if (pttButton == "playPause") {
                        when (it.keyCode) {
                            KeyEvent.KEYCODE_HEADSETHOOK,
                            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                            KeyEvent.KEYCODE_MEDIA_PLAY,
                            KeyEvent.KEYCODE_MEDIA_PAUSE -> {
                                // Use same handler as volume buttons
                                handleKeyEventForPTT(it)
                                return true
                            }
                        }
                    }
                }
                return super.onMediaButtonEvent(mediaButtonEvent)
            }
        })
        
        // Request audio focus BEFORE activating session
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        val result = audioManager.requestAudioFocus(
            { focusChange ->
                Log.d("PTT", "Audio focus changed: $focusChange")
                when (focusChange) {
                    AudioManager.AUDIOFOCUS_GAIN -> {
                        Log.d("PTT", "Audio focus gained - our app is now active")
                        mediaSession.isActive = true
                    }
                    AudioManager.AUDIOFOCUS_LOSS -> {
                        Log.d("PTT", "Audio focus lost permanently")
                    }
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                        Log.d("PTT", "Audio focus lost temporarily")
                    }
                }
            },
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN
        )
        Log.d("PTT", "Audio focus request result: $result")
        
        // Only activate if we got audio focus
        if (result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            mediaSession.isActive = true
            Log.d("PTT", "MediaSession activated successfully")
        } else {
            Log.e("PTT", "Failed to get audio focus, but activating session anyway")
            mediaSession.isActive = true
        }
        
        Log.d("PTT", "MediaSession setup complete and active")
    }

    private fun handleMediaButtonPress() {
        // For headset button toggle mode (MediaSession callbacks don't distinguish ACTION_UP/DOWN)
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL) {
            Log.d("PTT", "Media button press ignored - too soon")
            return
        }

        lastPressTime = currentTime
        isRecording = !isRecording

        if (isRecording) {
            Log.d("PTT", "Starting recording (media button)")
            channel.invokeMethod("pttPressed", null)
        } else {
            Log.d("PTT", "Stopping recording (media button)")
            channel.invokeMethod("pttReleased", null)
        }
    }

    private fun handlePTTButtonEvent(keyEvent: KeyEvent) {
        val currentTime = System.currentTimeMillis()
        
        when (pttMode) {
            "toggle" -> {
                // Toggle mode: Only handle ACTION_DOWN to avoid duplicate events
                if (keyEvent.action == KeyEvent.ACTION_DOWN) {
                    // Prevent accidental double press
                    if (currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL) {
                        Log.d("PTT", "Button press ignored - too soon after last press")
                        return
                    }
                    
                    lastPressTime = currentTime
                    
                    // Toggle recording state
                    isRecording = !isRecording
                    
                    if (isRecording) {
                        Log.d("PTT", "Starting recording (toggle mode)")
                        channel.invokeMethod("pttPressed", null)
                    } else {
                        Log.d("PTT", "Stopping recording (toggle mode)")
                        channel.invokeMethod("pttReleased", null)
                    }
                }
            }
            "hold" -> {
                // Hold mode: Handle both press and release
                when (keyEvent.action) {
                    KeyEvent.ACTION_DOWN -> {
                        if (!isRecording) {
                            // Prevent accidental double press
                            if (currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL) {
                                Log.d("PTT", "Button press ignored - too soon after last press")
                                return
                            }
                            
                            lastPressTime = currentTime
                            isRecording = true
                            Log.d("PTT", "Starting recording (hold mode)")
                            channel.invokeMethod("pttPressed", null)
                        }
                    }
                    KeyEvent.ACTION_UP -> {
                        if (isRecording) {
                            isRecording = false
                            Log.d("PTT", "Stopping recording (hold mode)")
                            channel.invokeMethod("pttReleased", null)
                        }
                    }
                }
            }
        }
    }

    // Override onKeyDown to catch volume buttons
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        Log.d("PTT", "onKeyDown: keyCode=$keyCode, action=${event.action}, repeatCount=${event.repeatCount}")

        // Check if this is a volume button and we're configured to use volume buttons
        if (pttButton == "volume" &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)) {
            Log.d("PTT", "Volume button DOWN detected (keyCode=$keyCode)")

            // Handle PTT for volume buttons
            handleKeyEventForPTT(event.withKeyCode(keyCode))
            return true // Consume the event to prevent system volume change
        }

        return super.onKeyDown(keyCode, event)
    }

    // Override onKeyUp to catch volume button releases
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        Log.d("PTT", "onKeyUp: keyCode=$keyCode, action=${event.action}")

        // Check if this is a volume button and we're configured to use volume buttons
        if (pttButton == "volume" &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)) {
            Log.d("PTT", "Volume button UP detected (keyCode=$keyCode)")

            // Handle PTT for volume buttons
            val syntheticEvent = KeyEvent(
                event.downTime,
                event.eventTime,
                KeyEvent.ACTION_UP,
                keyCode,
                event.repeatCount
            )
            handleKeyEventForPTT(syntheticEvent)
            return true // Consume the event
        }

        return super.onKeyUp(keyCode, event)
    }

    // Override dispatchKeyEvent to intercept media button events BEFORE system handlers
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        Log.d("PTT", "dispatchKeyEvent: keyCode=${event.keyCode}, action=${event.action}, repeatCount=${event.repeatCount}")

        // Only handle play/pause buttons through dispatchKeyEvent (volume handled via onKeyDown/Up)
        if (pttButton == "playPause") {
            val shouldHandle = event.keyCode in listOf(
                KeyEvent.KEYCODE_HEADSETHOOK,
                KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
                KeyEvent.KEYCODE_MEDIA_PLAY,
                KeyEvent.KEYCODE_MEDIA_PAUSE
            )

            if (shouldHandle) {
                Log.d("PTT", "Handling PTT event for button: $pttButton, action: ${event.action}")

                // Handle both DOWN and UP events explicitly
                when (event.action) {
                    KeyEvent.ACTION_DOWN -> {
                        // Check if this is a long press by examining event repeat count
                        if (event.repeatCount > 0) {
                            Log.d("PTT", "Long press detected (repeat=${event.repeatCount}) - consuming to prevent voice assistant")
                            return true // Consume to prevent voice assistant
                        }
                        // Handle press
                        handleKeyEventForPTT(event)
                        return true
                    }
                    KeyEvent.ACTION_UP -> {
                        // CRITICAL: Handle release for hold mode
                        Log.d("PTT", "ACTION_UP detected - handling release")
                        handleKeyEventForPTT(event)
                        return true
                    }
                }
            }
        }

        // For all other keys, use default handling
        return super.dispatchKeyEvent(event)
    }

    // Helper extension to create KeyEvent with different keyCode
    private fun KeyEvent.withKeyCode(newKeyCode: Int): KeyEvent {
        return KeyEvent(this.downTime, this.eventTime, this.action, newKeyCode, this.repeatCount)
    }

    // Separate method to handle key events for PTT
    private fun handleKeyEventForPTT(keyEvent: KeyEvent) {
        val currentTime = System.currentTimeMillis()

        when (pttMode) {
            "toggle" -> {
                // Toggle mode: Only handle ACTION_DOWN to avoid duplicate events
                if (keyEvent.action == KeyEvent.ACTION_DOWN && keyEvent.repeatCount == 0) {
                    // Prevent accidental double press
                    if (currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL) {
                        Log.d("PTT", "Button press ignored - too soon after last press")
                        return
                    }

                    lastPressTime = currentTime

                    // Toggle recording state
                    isRecording = !isRecording

                    if (isRecording) {
                        Log.d("PTT", "Starting recording (toggle mode)")
                        channel.invokeMethod("pttPressed", null)
                    } else {
                        Log.d("PTT", "Stopping recording (toggle mode)")
                        channel.invokeMethod("pttReleased", null)
                    }
                }
            }
            "hold" -> {
                // Hold mode: Handle both press and release
                when (keyEvent.action) {
                    KeyEvent.ACTION_DOWN -> {
                        // Only handle initial press (repeatCount == 0) to avoid triggering on long press
                        if (keyEvent.repeatCount == 0 && !isRecording) {
                            // Prevent accidental double press
                            if (currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL) {
                                Log.d("PTT", "Button press ignored - too soon after last press")
                                return
                            }

                            lastPressTime = currentTime
                            isRecording = true
                            Log.d("PTT", "Starting recording (hold mode)")
                            channel.invokeMethod("pttPressed", null)
                        }
                    }
                    KeyEvent.ACTION_UP -> {
                        if (isRecording) {
                            isRecording = false
                            Log.d("PTT", "Stopping recording (hold mode)")
                            channel.invokeMethod("pttReleased", null)
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::mediaSession.isInitialized) {
            mediaSession.release()
        }
    }
}
