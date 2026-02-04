package org.verya.QMLHealthConnect

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.*
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

object HealthBridge {

    private const val TAG = "HealthBridge"
    const val REQUEST_CODE_PERMISSIONS = 1001

    private var appContext: Context? = null
    private var healthConnectClient: HealthConnectClient? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    var permissionCallback: ((Boolean) -> Unit)? = null

    val PERMISSIONS = setOf(
        HealthPermission.getReadPermission(HeightRecord::class),
        HealthPermission.getWritePermission(HeightRecord::class),
        HealthPermission.getReadPermission(WeightRecord::class),
        HealthPermission.getWritePermission(WeightRecord::class),
        HealthPermission.getReadPermission(BloodPressureRecord::class),
        HealthPermission.getWritePermission(BloodPressureRecord::class)
    )

    @JvmStatic
    fun isHealthConnectInstalled(): Boolean {
        val context = appContext ?: return false
        val packageName = if (android.os.Build.VERSION.SDK_INT >= 34) {
            "com.android.healthconnect.controller"
        } else {
            "com.google.android.apps.healthdata"
        }
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    @JvmStatic
    fun getHealthConnectVersion(): String {
        val context = appContext ?: return "CONTEXT_NULL"
        val packageName = if (android.os.Build.VERSION.SDK_INT >= 34) {
            "com.android.healthconnect.controller"
        } else {
            "com.google.android.apps.healthdata"
        }
        return try {
            context.packageManager.getPackageInfo(packageName, 0).versionName ?: "UNKNOWN"
        } catch (e: Exception) {
            "NOT_INSTALLED"
        }
    }

    @JvmStatic
    fun getHealthConnectPackageName(): String? {
        val context = appContext ?: return null
        val pm = context.packageManager

        val candidates = listOf(
            "com.android.healthconnect.controller", // Android 14+
            "com.google.android.apps.healthdata"    // Android 9–13
        )

        for (pkg in candidates) {
            try {
                pm.getPackageInfo(pkg, 0)
                return pkg
            } catch (_: Exception) {}
        }
        return null
    }

    @JvmStatic
    fun init(context: Context): String {
        appContext = context.applicationContext

        if (android.os.Build.VERSION.SDK_INT < 28) {
            Log.e(TAG, "Android too old")
            return "ANDROID_TOO_OLD"
        }

        if (android.os.Build.VERSION.SDK_INT < 34) {
            if (!isHealthConnectInstalled()) {
                Log.e(TAG, "HC not installed")
                return "HC_NOT_INSTALLED"
            }
        }

        return try {
            when (HealthConnectClient.getSdkStatus(appContext!!)) {
                HealthConnectClient.SDK_UNAVAILABLE -> "HC_UNAVAILABLE"
                HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "HC_NEEDS_UPDATE"
                HealthConnectClient.SDK_AVAILABLE -> {
                    healthConnectClient = HealthConnectClient.getOrCreate(appContext!!)
                    Log.d(TAG, "✅ Initialized")
                    "INIT_OK"
                }
                else -> "HC_UNKNOWN"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Init error", e)
            "INIT_ERROR"
        }
    }

    @JvmStatic
    fun testCall(): String {
        return "✅ JNI Bridge Working! SDK=${getAvailability()}"
    }

    @JvmStatic
    fun isInitialized(): String {
        return when {
            appContext == null -> "CONTEXT_NULL"
            healthConnectClient == null -> "CLIENT_NULL"
            else -> "INIT_OK"
        }
    }

    @JvmStatic
    fun getAvailability(): String {
        if (appContext == null) return "CONTEXT_NULL"

        return try {
            when (HealthConnectClient.getSdkStatus(appContext!!)) {
                HealthConnectClient.SDK_AVAILABLE -> "HC_AVAILABLE"
                HealthConnectClient.SDK_UNAVAILABLE -> "HC_UNAVAILABLE"
                HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "HC_UPDATE_REQUIRED"
                else -> "HC_UNKNOWN"
            }
        } catch (e: Exception) {
            "ERROR: ${e.message}"
        }
    }

    @JvmStatic
    fun checkPermissions(): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            val granted = runBlocking(Dispatchers.IO) {
                client.permissionController.getGrantedPermissions()
            }

            val grantedCount = granted.size
            val totalCount = PERMISSIONS.size

            if (grantedCount == totalCount) {
                "ALL_GRANTED ($grantedCount/$totalCount)"
            } else {
                val missing = PERMISSIONS - granted
                val missingNames = missing.joinToString(", ") {
                    it.substringAfterLast('.')
                }
                "PARTIAL ($grantedCount/$totalCount)\nMissing: $missingNames"
            }

        } catch (e: Exception) {
            Log.e(TAG, "Permission check failed", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ درخواست Permission با استفاده از Intent مستقیم (FIXED)
     */
    @JvmStatic
    fun requestPermissions(activity: Activity): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        // ✅ بررسی package name
        val hcPackage = getHealthConnectPackageName()
            ?: return "HC_NOT_INSTALLED"

        return try {
            scope.launch(Dispatchers.IO) {
                try {
                    val granted = client.permissionController.getGrantedPermissions()
                    val toRequest = PERMISSIONS - granted

                    if (toRequest.isEmpty()) {
                        Log.d(TAG, "✅ All permissions already granted")
                        withContext(Dispatchers.Main) {
                            permissionCallback?.invoke(true)
                            permissionCallback = null
                        }
                        return@launch
                    }

                    Log.d(TAG, "📋 Requesting ${toRequest.size} permissions...")
                    Log.d(TAG, "🎯 Using HC package: $hcPackage")

                    // ✅ ساخت Intent درست (بدون تعریف دوباره)
                    val intent = Intent("androidx.health.ACTION_REQUEST_PERMISSIONS").apply {
                        setPackage(hcPackage)
                        putExtra(
                            "androidx.health.EXTRA_PERMISSIONS",
                            toRequest.toTypedArray()
                        )
                    }

                    // ✅ بررسی اینکه intent قابل حل است
                    val resolveInfo = activity.packageManager.resolveActivity(
                        intent,
                        0
                    )

                    if (resolveInfo == null) {
                        Log.e(TAG, "❌ Permission intent cannot be resolved!")
                        Log.e(TAG, "📦 HC Package: $hcPackage")
                        Log.e(TAG, "🔍 Try installing HC from Play Store")

                        withContext(Dispatchers.Main) {
                            permissionCallback?.invoke(false)
                            permissionCallback = null
                        }
                        return@launch
                    }

                    // ✅ اجرای intent
                    withContext(Dispatchers.Main) {
                        activity.startActivityForResult(intent, REQUEST_CODE_PERMISSIONS)
                        Log.d(TAG, "✅ Permission dialog launched!")
                    }

                } catch (e: Exception) {
                    Log.e(TAG, "❌ Permission request failed", e)
                    withContext(Dispatchers.Main) {
                        permissionCallback?.invoke(false)
                        permissionCallback = null
                    }
                }
            }

            "PERMISSION_REQUEST_LAUNCHED"

        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to launch permission request", e)
            "ERROR: ${e.message}"
        }
    }

    @JvmStatic
    fun onPermissionResult(requestCode: Int, resultCode: Int) {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            val success = resultCode == Activity.RESULT_OK
            Log.d(TAG, "🔔 Permission result: success=$success")
            permissionCallback?.invoke(success)
            permissionCallback = null
        }
    }

    /**
     * ✅ خواندن قد با بازه زمانی 1 سال
     */
    @JvmStatic
    fun readHeight(): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            Log.d(TAG, "📏 Reading height data...")

            val end = Instant.now()
            val start = Instant.parse("2000-01-01T00:00:00.000Z")

            Log.d(TAG, "⏰ Time range: $start to $end")

            val request = ReadRecordsRequest(
                recordType = HeightRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end)
            )

            val response = runBlocking(Dispatchers.IO) {
                client.readRecords(request)
            }

            Log.d(TAG, "📊 Found ${response.records.size} height records")

            if (response.records.isEmpty()) {
                return "NO_HEIGHT_DATA"
            }

            val arr = JSONArray()
            response.records.forEach { record ->
                val meters = record.height.inMeters
                Log.d(TAG, "  ➤ Height: $meters m at ${record.time}")

                val obj = JSONObject().apply {
                    put("height_m", meters)
                    put("time", record.time.toString())
                }
                arr.put(obj)
            }

            arr.toString()

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error: No permission", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading height", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ خواندن وزن با بازه زمانی 1 سال
     */
    @JvmStatic
    fun readWeight(): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            Log.d(TAG, "⚖️ Reading weight data...")

            val end = Instant.now()
            val start = Instant.parse("2000-01-01T00:00:00.000Z")

            Log.d(TAG, "⏰ Time range: $start to $end")

            val request = ReadRecordsRequest(
                recordType = WeightRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end)
            )

            val response = runBlocking(Dispatchers.IO) {
                client.readRecords(request)
            }

            Log.d(TAG, "📊 Found ${response.records.size} weight records")

            if (response.records.isEmpty()) {
                return "NO_WEIGHT_DATA"
            }

            val arr = JSONArray()
            response.records.forEach { record ->
                val kg = record.weight.inKilograms
                Log.d(TAG, "  ➤ Weight: $kg kg at ${record.time}")

                val obj = JSONObject().apply {
                    put("weight_kg", kg)
                    put("time", record.time.toString())
                }
                arr.put(obj)
            }

            arr.toString()

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error: No permission", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading weight", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ نوشتن قد با مقدار دلخواه
     */
    @JvmStatic
    fun writeHeight(heightMeters: Double): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (heightMeters < 0.1 || heightMeters > 3) {
                return "ERROR: Invalid height value ($heightMeters m). Must be between 0.1 and 3 meters."
            }

            Log.d(TAG, "📝 Writing height: $heightMeters m")

            val heightRecord = HeightRecord(
                height = androidx.health.connect.client.units.Length.meters(heightMeters),
                time = Instant.now(),
                zoneOffset = ZoneId.systemDefault().rules.getOffset(Instant.now())
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(heightRecord))
            }

            Log.d(TAG, "✅ Height written successfully: $heightMeters m")
            "SUCCESS: Height $heightMeters m saved at ${Instant.now()}"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error: No write permission", e)
            "SECURITY_ERROR: No write permission for height"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing height", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ نوشتن وزن با مقدار دلخواه
     */
    @JvmStatic
    fun writeWeight(weightKg: Double): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (weightKg < 0.1 || weightKg > 300.0) {
                return "ERROR: Invalid weight value ($weightKg kg). Must be between 0.1 and 300 kg."
            }

            Log.d(TAG, "📝 Writing weight: $weightKg kg")

            val weightRecord = WeightRecord(
                weight = androidx.health.connect.client.units.Mass.kilograms(weightKg),
                time = Instant.now(),
                zoneOffset = ZoneId.systemDefault().rules.getOffset(Instant.now())
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(weightRecord))
            }

            Log.d(TAG, "✅ Weight written successfully: $weightKg kg")
            "SUCCESS: Weight $weightKg kg saved at ${Instant.now()}"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error: No write permission", e)
            "SECURITY_ERROR: No write permission for weight"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing weight", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ خواندن فشار خون با بازه زمانی گسترده
     */
    @JvmStatic
    fun readBloodPressure(): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            Log.d(TAG, "🩺 Reading blood pressure data...")

            val end = Instant.now()
            val start = Instant.parse("2000-01-01T00:00:00.000Z")

            Log.d(TAG, "⏰ Time range: $start to $end")

            val request = ReadRecordsRequest(
                recordType = BloodPressureRecord::class,
                timeRangeFilter = TimeRangeFilter.between(start, end)
            )

            val response = runBlocking(Dispatchers.IO) {
                client.readRecords(request)
            }

            Log.d(TAG, "📊 Found ${response.records.size} blood pressure records")

            if (response.records.isEmpty()) {
                return "NO_BP_DATA"
            }

            val arr = JSONArray()
            response.records.forEach { record ->
                val systolic = record.systolic.inMillimetersOfMercury
                val diastolic = record.diastolic.inMillimetersOfMercury

                Log.d(TAG, "  ➤ BP: $systolic/$diastolic mmHg at ${record.time}")

                val obj = JSONObject().apply {
                    put("systolic_mmhg", systolic)
                    put("diastolic_mmhg", diastolic)
                    put("time", record.time.toString())
                    put("body_position", record.bodyPosition ?: 0)
                    put("measurement_location", record.measurementLocation ?: 0)
                }
                arr.put(obj)
            }

            arr.toString()

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error: No permission", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading blood pressure", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ نوشتن فشار خون
     */
    @JvmStatic
    fun writeBloodPressure(systolicMmHg: Double, diastolicMmHg: Double): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (systolicMmHg < 80 || systolicMmHg > 200) {
                return "ERROR: Invalid systolic value ($systolicMmHg). Must be 80-200 mmHg."
            }

            if (diastolicMmHg < 40 || diastolicMmHg > 130) {
                return "ERROR: Invalid diastolic value ($diastolicMmHg). Must be 40-130 mmHg."
            }

            if (systolicMmHg <= diastolicMmHg) {
                return "ERROR: Systolic must be greater than diastolic."
            }

            Log.d(TAG, "📝 Writing blood pressure: $systolicMmHg/$diastolicMmHg mmHg")

            val bpRecord = BloodPressureRecord(
                systolic = androidx.health.connect.client.units.Pressure.millimetersOfMercury(systolicMmHg),
                diastolic = androidx.health.connect.client.units.Pressure.millimetersOfMercury(diastolicMmHg),
                time = Instant.now(),
                zoneOffset = ZoneId.systemDefault().rules.getOffset(Instant.now()),
                bodyPosition = BloodPressureRecord.BODY_POSITION_STANDING_UP,
                measurementLocation = BloodPressureRecord.MEASUREMENT_LOCATION_LEFT_WRIST
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(bpRecord))
            }

            Log.d(TAG, "✅ Blood pressure written: $systolicMmHg/$diastolicMmHg mmHg")
            "SUCCESS: BP $systolicMmHg/$diastolicMmHg mmHg saved at ${Instant.now()}"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error: No write permission", e)
            "SECURITY_ERROR: No write permission for blood pressure"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing blood pressure", e)
            "ERROR: ${e.message}"
        }
    }

    @JvmStatic
    fun openHealthConnectInStore(activity: Activity): String {
        val packageName = if (android.os.Build.VERSION.SDK_INT >= 34) {
            "com.android.healthconnect.controller"
        } else {
            "com.google.android.apps.healthdata"
        }

        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = android.net.Uri.parse("market://details?id=$packageName")
                setPackage("com.android.vending")
            }
            activity.startActivity(intent)
            "STORE_OPENED"
        } catch (e: Exception) {
            try {
                val webIntent = Intent(Intent.ACTION_VIEW).apply {
                    data = android.net.Uri.parse("https://play.google.com/store/apps/details?id=$packageName")
                }
                activity.startActivity(webIntent)
                "BROWSER_OPENED"
            } catch (e2: Exception) {
                "OPEN_FAILED"
            }
        }
    }
}
