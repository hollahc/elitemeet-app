package net.elitemeet.app

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val audioChannel = "net.elitemeet.app/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannel).setMethodCallHandler { call, result ->
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            when (call.method) {
                // Called when a call connects: voice-call audio mode, earpiece by default.
                "startCallAudio" -> {
                    audio.mode = AudioManager.MODE_IN_COMMUNICATION
                    setSpeaker(audio, call.argument<Boolean>("speaker") ?: false)
                    result.success(true)
                }
                "setSpeakerphone" -> {
                    audio.mode = AudioManager.MODE_IN_COMMUNICATION
                    setSpeaker(audio, call.argument<Boolean>("on") ?: false)
                    result.success(true)
                }
                // Called when the call ends: give audio back to the system.
                "stopCallAudio" -> {
                    setSpeaker(audio, false)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) audio.clearCommunicationDevice()
                    audio.mode = AudioManager.MODE_NORMAL
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setSpeaker(audio: AudioManager, on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val wanted = if (on) AudioDeviceInfo.TYPE_BUILTIN_SPEAKER else AudioDeviceInfo.TYPE_BUILTIN_EARPIECE
            val device = audio.availableCommunicationDevices.firstOrNull { it.type == wanted }
            if (device != null) audio.setCommunicationDevice(device) else audio.clearCommunicationDevice()
        } else {
            @Suppress("DEPRECATION")
            audio.isSpeakerphoneOn = on
        }
    }
}
