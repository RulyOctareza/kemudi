package io.github.rulyoctareza.kemudi

import android.app.PictureInPictureParams
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.speech.RecognizerIntent
import android.util.Rational
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity shares audio_service's cached FlutterEngine, so the media session
// (steering-wheel buttons, notification) keeps running after this activity is destroyed.
class MainActivity : AudioServiceActivity() {
    private val channelName = "io.github.rulyoctareza.kemudi/pip"
    private var methodChannel: MethodChannel? = null
    private var isAutoPipEnabled = false

    // The Dart call waiting for the speech recognizer; non-null while it is open.
    private var speechResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "enterPip" -> result.success(enterPipMode())
                "isPipSupported" -> result.success(isPipSupported())
                "setAutoPip" -> {
                    isAutoPipEnabled = call.argument<Boolean>("enabled") ?: false
                    result.success(true)
                }
                // Back on the dashboard: behave like Home and keep the activity alive.
                "minimize" -> result.success(moveTaskToBack(true))
                "recognizeSpeech" -> recognizeSpeech(result)
                else -> result.notImplemented()
            }
        }
    }

    // The engine outlives this activity; drop the handler so it does not keep a destroyed
    // activity alive. A recreated activity registers a fresh one.
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        speechResult?.success(null)
        speechResult = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun isPipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun enterPipMode(): Boolean {
        if (!isPipSupported()) return false
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(16, 9))
                .build()
            enterPictureInPictureMode(params)
        } catch (e: RuntimeException) {
            // IllegalStateException when not resumed, IllegalArgumentException on bad params.
            false
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Opening the speech recognizer is not leaving the app.
        if (isAutoPipEnabled && speechResult == null) {
            enterPipMode()
        }
    }

    // Android's own speech dialog: it asks for the microphone itself, so the app needs
    // no RECORD_AUDIO permission. Answers with the heard text, null when cancelled, and
    // an error when the phone has no recognizer.
    private fun recognizeSpeech(result: MethodChannel.Result) {
        if (speechResult != null) {
            result.success(null)
            return
        }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id-ID")
            .putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            .addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION)
        speechResult = result
        try {
            startActivityForResult(intent, SPEECH_REQUEST)
        } catch (e: ActivityNotFoundException) {
            speechResult = null
            result.error("unavailable", "No speech recognizer on this phone", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != SPEECH_REQUEST) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val heard = if (resultCode == RESULT_OK) {
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()
        } else {
            null
        }
        speechResult?.success(heard)
        speechResult = null
    }

    private companion object {
        const val SPEECH_REQUEST = 4101
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        methodChannel?.invokeMethod("onPipModeChanged", isInPictureInPictureMode)
    }
}
