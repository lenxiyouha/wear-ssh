package dev.wearssh.app

import android.view.InputDevice
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Wear OS 交互层：
 *  - 转发旋转表冠 (rotary encoder) 滚动增量给 Flutter
 *  - 连接期间保持屏幕常亮，避免息屏断线
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { c ->
                c.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "keepScreenOn" -> {
                            val on = call.argument<Boolean>("on") ?: false
                            if (on) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            }
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onGenericMotionEvent(event: MotionEvent): Boolean {
        if ((event.source and InputDevice.SOURCE_ROTARY_ENCODER) != 0) {
            val delta = event.getAxisValue(MotionEvent.AXIS_SCROLL)
            if (delta != 0f) {
                channel?.invokeMethod("rotary", delta.toDouble())
            }
            return true
        }
        return super.onGenericMotionEvent(event)
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "dev.wearssh.app/wear"
    }
}
