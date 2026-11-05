package com.footiq.footiq

import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.provider.Settings
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var soundPool: SoundPool? = null
    private val loadedSounds = mutableMapOf<String, Int>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val pool = SoundPool.Builder()
            .setMaxStreams(6)
            .setAudioAttributes(attrs)
            .build()
        soundPool = pool

        pool.setOnLoadCompleteListener { sp, sampleId, status ->
            if (status == 0) {
                sp.play(sampleId, 0.70f, 0.70f, 1, 0, 1f)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "footiq/sound")
            .setMethodCallHandler { call, result ->
                if (call.method == "play") {
                    val name = call.argument<String>("name") ?: "click"
                    playAssetSound(name)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // Mikrofon izni reddedildiyse oyuncuyu uygulamanın Ayarlar sayfasına götürür.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "footiq/system")
            .setMethodCallHandler { call, result ->
                if (call.method == "openAppSettings") {
                    try {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun playAssetSound(name: String) {
        val pool = soundPool ?: return
        val cached = loadedSounds[name]
        if (cached != null) {
            pool.play(cached, 0.70f, 0.70f, 1, 0, 1f)
            return
        }
        val loader = FlutterInjector.instance().flutterLoader()
        for (ext in listOf("mp3", "wav", "ogg")) {
            val key = loader.getLookupKeyForAsset("assets/sounds/$name.$ext")
            try {
                assets.openFd(key).use { afd ->
                    val id = pool.load(afd, 1)
                    loadedSounds[name] = id
                    return
                }
            } catch (_: Exception) {
                // Diğer uzantıyı dene
            }
        }
    }

    override fun onDestroy() {
        soundPool?.release()
        soundPool = null
        super.onDestroy()
    }
}
