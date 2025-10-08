package com.example.auramapuser

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.auramap.audio/headphone_detection"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isHeadsetConnected" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val isWiredHeadsetOn = audioManager.isWiredHeadsetOn
                    val isBluetoothA2dpOn = audioManager.isBluetoothA2dpOn
                    result.success(isWiredHeadsetOn || isBluetoothA2dpOn)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
