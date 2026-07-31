package com.example.app

import android.view.KeyEvent

object PttEventBus {
    @Volatile var listener: ((KeyEvent) -> Unit)? = null

    fun emit(event: KeyEvent) {
        listener?.invoke(event)
    }
}
