package com.example.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
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
    private lateinit var channel: MethodChannel
    private var isRecording = false
    private var lastPressTime = 0L
    private val DOUBLE_PRESS_INTERVAL = 300L
    private var pttMode = "toggle"
    private var pttButton = "volume"
    private var preventScreenLock = true

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setPTTMode" -> {
                    pttMode = call.arguments as String
                    Log.d("PTT", "PTT mode set to: $pttMode")
                    result.success(null)
                }
                "updatePTTConfiguration" -> {
                    @Suppress("UNCHECKED_CAST")
                    val args = call.arguments as? Map<String, Any>
                    if (args != null) {
                        pttMode = args["mode"] as? String ?: pttMode
                        pttButton = args["button"] as? String ?: pttButton
                        preventScreenLock = args["preventScreenLock"] as? Boolean ?: preventScreenLock

                        Log.d("PTT", "Configuration updated: mode=$pttMode, button=$pttButton, preventScreenLock=$preventScreenLock")

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

        PttEventBus.listener = { keyEvent -> handleKeyEventForPTT(keyEvent) }

        checkPermissionsAndStartService()
        Log.d("PTT", "Flutter engine configured")
    }

    private fun checkPermissionsAndStartService() {
        val permissions = mutableListOf(
            Manifest.permission.RECORD_AUDIO,
            Manifest.permission.BLUETOOTH_CONNECT
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val needed = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (needed.isNotEmpty()) {
            Log.d("PTT", "Requesting permissions: $needed")
            ActivityCompat.requestPermissions(this, needed.toTypedArray(), PERMISSION_REQUEST_CODE)
        } else {
            startMediaSessionService()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            startMediaSessionService()
        }
    }

    private fun startMediaSessionService() {
        val intent = Intent(this, PttMediaSessionService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        Log.d("PTT", "PttMediaSessionService start requested")
    }

    // Volume buttons are activity-scoped (the Service can't intercept volume keys without
    // an Accessibility Service). Keep them here.
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (pttButton == "volume" &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)) {
            handleKeyEventForPTT(event.withKeyCode(keyCode))
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (pttButton == "volume" &&
            (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP)) {
            val synthetic = KeyEvent(
                event.downTime, event.eventTime, KeyEvent.ACTION_UP, keyCode, event.repeatCount
            )
            handleKeyEventForPTT(synthetic)
            return true
        }
        return super.onKeyUp(keyCode, event)
    }

    private fun KeyEvent.withKeyCode(newKeyCode: Int): KeyEvent {
        return KeyEvent(this.downTime, this.eventTime, this.action, newKeyCode, this.repeatCount)
    }

    private fun handleKeyEventForPTT(keyEvent: KeyEvent) {
        val currentTime = System.currentTimeMillis()

        // BT headset play/pause buttons can't reliably express hold duration: most earbuds
        // (and many over-ear models) emit ACTION_DOWN+ACTION_UP back-to-back at the moment
        // of release. Force toggle semantics for those keycodes regardless of pttMode so
        // a single tap = single state flip, instead of a green flash that reverts.
        val isMediaKey = when (keyEvent.keyCode) {
            KeyEvent.KEYCODE_HEADSETHOOK,
            KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE,
            KeyEvent.KEYCODE_MEDIA_PLAY,
            KeyEvent.KEYCODE_MEDIA_PAUSE -> true
            else -> false
        }
        val effectiveMode = if (isMediaKey) "toggle" else pttMode

        Log.d("PTT", "KeyEvent kc=${keyEvent.keyCode} action=${keyEvent.action} repeat=${keyEvent.repeatCount} mediaKey=$isMediaKey effectiveMode=$effectiveMode isRecording=$isRecording")

        when (effectiveMode) {
            "toggle" -> {
                if (keyEvent.action == KeyEvent.ACTION_DOWN && keyEvent.repeatCount == 0) {
                    if (currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL) {
                        Log.d("PTT", "Toggle debounced (Δ=${currentTime - lastPressTime}ms)")
                        return
                    }
                    lastPressTime = currentTime
                    isRecording = !isRecording
                    val method = if (isRecording) "pttPressed" else "pttReleased"
                    Log.d("PTT", "Toggle → $method")
                    runOnUiThread { channel.invokeMethod(method, null) }
                }
            }
            "hold" -> {
                when (keyEvent.action) {
                    KeyEvent.ACTION_DOWN -> {
                        if (keyEvent.repeatCount == 0 && !isRecording) {
                            if (currentTime - lastPressTime < DOUBLE_PRESS_INTERVAL) {
                                Log.d("PTT", "Hold DOWN debounced (Δ=${currentTime - lastPressTime}ms)")
                                return
                            }
                            lastPressTime = currentTime
                            isRecording = true
                            Log.d("PTT", "Hold → pttPressed")
                            runOnUiThread { channel.invokeMethod("pttPressed", null) }
                        }
                    }
                    KeyEvent.ACTION_UP -> {
                        if (isRecording) {
                            isRecording = false
                            Log.d("PTT", "Hold → pttReleased")
                            runOnUiThread { channel.invokeMethod("pttReleased", null) }
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        PttEventBus.listener = null
        super.onDestroy()
    }
}
