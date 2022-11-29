package com.example.app
import io.flutter.embedding.android.FlutterActivity
// package com.github.romdj.pelotoncommunicator.app.android.app.src.main

class MainActivity: FlutterActivity() {

}

private fun mapAction(keyCode: Int): MediaButtonAction? {
    println("Action button detected " + keyCode);
}

companion object {
    // var instance: MediaButtonsReceiver? = null
    // private var mediaSessionCompat : MediaSessionCompat? = null
}
