package com.avdibook.app

import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity : AudioServiceActivity() {
	private val channelName = "avdibook/audio_fx"
	private var audioSessionId: Int? = null
	private var equalizer: Equalizer? = null
	private var loudnessEnhancer: LoudnessEnhancer? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				try {
					when (call.method) {
						"setAudioSessionId" -> {
							val id = call.argument<Int>("id")
							if (id == null || id <= 0) {
								releaseEffects()
							} else {
								attachEffects(id)
							}
							result.success(null)
						}

						"setEqualizerEnabled" -> {
							val enabled = call.argument<Boolean>("enabled") ?: false
							equalizer?.enabled = enabled
							result.success(null)
						}

						"setEqualizerPreset" -> {
							val preset = call.argument<Int>("preset") ?: 0
							equalizer?.let {
								if (preset in 0 until it.numberOfPresets) {
									it.usePreset(preset.toShort())
								}
							}
							result.success(null)
						}

						"getEqualizerPresets" -> {
							val eq = equalizer
							if (eq == null) {
								result.success(listOf<String>())
							} else {
								val names = mutableListOf<String>()
								for (i in 0 until eq.numberOfPresets) {
									names.add(eq.getPresetName(i.toShort()).toString())
								}
								result.success(names)
							}
						}

						"setLoudnessBoost" -> {
							val boost = call.argument<Int>("gainMb") ?: 0
							loudnessEnhancer?.setTargetGain(boost)
							result.success(null)
						}

						else -> result.notImplemented()
					}
				} catch (_: Throwable) {
					result.success(null)
				}
			}
	}

	private fun attachEffects(id: Int) {
		if (audioSessionId == id && equalizer != null && loudnessEnhancer != null) {
			return
		}

		releaseEffects()
		audioSessionId = id

		equalizer = Equalizer(0, id).apply {
			enabled = false
		}

		loudnessEnhancer = LoudnessEnhancer(id).apply {
			enabled = true
			setTargetGain(0)
		}
	}

	private fun releaseEffects() {
		equalizer?.release()
		equalizer = null

		loudnessEnhancer?.release()
		loudnessEnhancer = null

		audioSessionId = null
	}

	override fun onDestroy() {
		releaseEffects()
		super.onDestroy()
	}
}
