package org.verya.QMLHealthConnect

import android.content.Intent
import android.util.Log
import android.os.Bundle
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import org.qtproject.qt.android.bindings.QtActivity
import android.content.Context
import android.media.AudioManager
import android.os.PowerManager
import android.view.ViewGroup
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import org.json.JSONObject

class MainActivity : QtActivity() {

    private lateinit var rootView: View
    private val handler = Handler(Looper.getMainLooper())
    private var screenDimmed = false
    private var dimTimeoutMs: Long = 0L

    companion object {
        private var audioManager: AudioManager? = null
        private var previousMode: Int = AudioManager.MODE_NORMAL

        @JvmStatic
        fun enableEchoCancellation(context: Context) {
            audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            previousMode = audioManager?.mode ?: AudioManager.MODE_NORMAL
            audioManager?.mode = AudioManager.MODE_IN_COMMUNICATION
        }

        @JvmStatic
        fun disableEchoCancellation() {
            audioManager?.mode = previousMode
            audioManager = null
        }

        private var wakeLockInstance: PowerManager.WakeLock? = null
        private var instance: MainActivity? = null

        fun getInstance(): MainActivity? = instance

        @JvmStatic
        fun manageScreenAndWakeLock(context: Context, screenAlwaysOn: Boolean, wakeLock: Boolean) {
            val activity = instance ?: return
            // Log.d("Log","manageScreenAndWakeLock started")
            activity.screenAndWakeLock(context,screenAlwaysOn,wakeLock)
        }

        @JvmStatic
        fun setDimTimeoutFromQt(valueMs: Long) {
            val activity = instance ?: return
            activity.setDimTimeoutInternal(valueMs)
        }

        @JvmStatic
        fun requestAppPermissions(permissions: Array<String>, requestCode: Int) {
            instance?.let { activity ->
                ActivityCompat.requestPermissions(
                    activity,
                    permissions,
                    requestCode
                )
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val initResult = HealthBridge.init(this)
        Log.d("MainActivity", "HC Init: $initResult")

        instance = this

        rootView = window.decorView
        if(dimTimeoutMs > 0){
            startDimTimer()
        }

        hideSystemUI()
    }

    private fun startDimTimer() {
        // هر تایمر قبلی را لغو کن
        handler.removeCallbacksAndMessages(null)
        handler.postDelayed({
            dimScreen()
        }, dimTimeoutMs)
    }

    fun setDimTimeoutInternal(valueMs: Long) {
        dimTimeoutMs = valueMs

        if (valueMs <= 0) {
            // یعنی غیر فعالش کن
            handler.removeCallbacksAndMessages(null)
            brightenScreen()
            return
        }

        // اگر فعال است، تایمر جدید را دوباره شروع کن
        startDimTimer()
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        if (ev?.action == MotionEvent.ACTION_DOWN) {
            if (screenDimmed) {
                brightenScreen()
            }
            if (dimTimeoutMs > 0) {
                startDimTimer()
            }
        }
        return super.dispatchTouchEvent(ev)
    }

    private fun dimScreen() {
        if (screenDimmed) return
        val params = window.attributes
        params.screenBrightness = 0.0f    // تقریبا صفحه خاموش
        window.attributes = params
        screenDimmed = true
    }

    private fun brightenScreen() {
        val params = window.attributes
        // می‌توانی مقدار را از سیستم بگیری، ولی اینجا فول روشنایی می‌گذاریم
        params.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL
        window.attributes = params
        screenDimmed = false
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            // دوباره مخفی کن اگه کاربر از بالا سوایپ کرد
            hideSystemUI()
        }
    }

    private fun hideSystemUI() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            // Android 11+ (API 30+)
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.systemBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            // Android 10 و پایین‌تر
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }

        // Keep screen on (اختیاری - صفحه خاموش نشه)
        // window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    fun screenAndWakeLock(context: Context, screenAlwaysOn: Boolean, wakeLock: Boolean)
    {
        //Log.d("Log","screenAndWakeLock started")
        // مدیریت FLAG_KEEP_SCREEN_ON
        runOnUiThread {
            if (screenAlwaysOn) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                //Log.d("Log", "screenAndWakeLock Screen Always On")
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                //Log.d("Log", "screenAndWakeLock Screen Normal")
            }
        }

        // مدیریت PARTIAL_WAKE_LOCK
        if (wakeLock) {
            if (wakeLockInstance == null || wakeLockInstance?.isHeld == false) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLockInstance = powerManager.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "QMLHealthConnect::WakeLock"
                )
                wakeLockInstance?.acquire(5 * 60 * 1000L) // 5 دقیقه
            }
        } else {
            if (wakeLockInstance?.isHeld == true) {
                wakeLockInstance?.release()
            }
            wakeLockInstance = null
        }
    }

    override fun onDestroy() {
        if (instance === this) instance = null
            handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    )
    {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        val jsonPermissions = org.json.JSONArray()

        for (i in permissions.indices) {
            val permObj = org.json.JSONObject().apply {
                put("permission", permissions[i])
                put("granted", grantResults[i] == PackageManager.PERMISSION_GRANTED)
            }
            jsonPermissions.put(permObj)
        }

        // ساخت نتیجه نهایی
        val jsonResult = org.json.JSONObject().apply {
            put("requestCode", requestCode)
            put("results", jsonPermissions)
        }

        TestBridge.nativeOnPermissionResult(jsonResult.toString())
    }

}
