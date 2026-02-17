package org.verya.QMLHealthConnect

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log

// ── Health Connect Client ──────────────────────────────────────
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter

// ── Health Connect Records ─────────────────────────────────────
import androidx.health.connect.client.records.Record          // ← برای generic <T : Record>
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.OxygenSaturationRecord

// ── Health Connect Response ────────────────────────────────────
import androidx.health.connect.client.response.ReadRecordsResponse  // ← برای return type

// ── Health Connect Units ───────────────────────────────────────
import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Pressure
import androidx.health.connect.client.units.BloodGlucose
import androidx.health.connect.client.units.Percentage

// ── Coroutines ─────────────────────────────────────────────────
import kotlinx.coroutines.*
import kotlinx.coroutines.delay                              // ← برای delay() در retry
import kotlinx.coroutines.sync.Mutex                        // ← برای readMutex
import kotlinx.coroutines.sync.withLock                     // ← برای mutex.withLock {}

// ── JSON ───────────────────────────────────────────────────────
import org.json.JSONArray
import org.json.JSONObject

// ── Java Time ─────────────────────────────────────────────────
import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit


object HealthBridge {

    private const val TAG = "HealthBridge"
    const val REQUEST_CODE_PERMISSIONS = 1001

    private const val SPECIMEN_SOURCE_CAPILLARY_BLOOD = 1
    private const val MEAL_TYPE_UNKNOWN = 0
    private const val RELATION_TO_MEAL_GENERAL = 0
    private val readMutex = kotlinx.coroutines.sync.Mutex()

    private suspend fun <T : androidx.health.connect.client.records.Record> safeReadBlocking(
        client: HealthConnectClient,
        request: ReadRecordsRequest<T>
    ): androidx.health.connect.client.response.ReadRecordsResponse<T> {
        var delayMs = 1000L
        repeat(5) { attempt ->
            try {
                return readMutex.withLock {
                    client.readRecords(request)
                }
            } catch (e: Exception) {
                val msg = e.message ?: ""
                if (msg.contains("Rate limit", ignoreCase = true) ||
                    msg.contains("quota", ignoreCase = true) ||
                    msg.contains("rejected", ignoreCase = true)
                ) {
                    Log.w(TAG, "⏳ Rate limited. Retry ${attempt + 1}/5 after ${delayMs}ms...")
                    kotlinx.coroutines.delay(delayMs)
                    delayMs = minOf(delayMs * 2, 15_000L)
                } else {
                    throw e
                }
            }
        }
        throw Exception("Rate limit: max retries exceeded")
    }

    // ═══════════════════════════════════════════════════════════
    // Helper: تبدیل ISO8601 String به Instant
    // ═══════════════════════════════════════════════════════════

    /**
     * تبدیل زمان از ISO8601 String به Instant
     *
     * @param isoString فرمت: "2024-01-01T00:00:00Z" یا "2024-01-01T00:00:00.000Z"
     * @return Instant یا null در صورت خطا
     */
    private fun parseInstant(isoString: String?): Instant? {
        if (isoString.isNullOrBlank()) return null

        return try {
            Instant.parse(isoString)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Invalid ISO8601 time format: $isoString", e)
            null
        }
    }

    /**
     * ساخت TimeRangeFilter با پارامترهای اختیاری
     *
     * @param startTime زمان شروع (ISO8601) - پیش‌فرض: "2000-01-01T00:00:00.000Z"
     * @param endTime زمان پایان (ISO8601) - پیش‌فرض: الان
     * @return TimeRangeFilter
     */
    private fun createTimeFilter(
        startTime: String? = null,
        endTime: String? = null
    ): TimeRangeFilter {
        val start = parseInstant(startTime) ?: Instant.parse("2000-01-01T00:00:00.000Z")
        val end = parseInstant(endTime) ?: Instant.now()

        // log.d(TAG, "⏰ Time range: $start to $end")

        return TimeRangeFilter.between(start, end)
    }

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
        HealthPermission.getWritePermission(BloodPressureRecord::class),
        HealthPermission.getReadPermission(HeartRateRecord::class),
        HealthPermission.getWritePermission(HeartRateRecord::class),
        HealthPermission.getReadPermission(BloodGlucoseRecord::class),
        HealthPermission.getWritePermission(BloodGlucoseRecord::class),
        HealthPermission.getReadPermission(OxygenSaturationRecord::class),
        HealthPermission.getWritePermission(OxygenSaturationRecord::class)
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
                    // log.d(TAG, "✅ Initialized")
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
     * ✅ درخواست Permission با روش Legacy (برای alpha10)
     */
    @JvmStatic
    fun requestPermissions(activity: Activity): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        val hcPackage = getHealthConnectPackageName() ?: return "HC_NOT_INSTALLED"

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

                    // ✅ روش Legacy - برای alpha10
                    val intent = Intent("androidx.health.ACTION_REQUEST_PERMISSIONS").apply {
                        setPackage(hcPackage)
                        putExtra(
                            "androidx.health.EXTRA_PERMISSIONS",
                            toRequest.toTypedArray()
                        )
                    }

                    withContext(Dispatchers.Main) {
                        activity.startActivityForResult(intent, REQUEST_CODE_PERMISSIONS)
                        Log.d(TAG, "✅ Permission request launched")
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
            // log.d(TAG, "🔔 Permission result: success=$success")
            permissionCallback?.invoke(success)
            permissionCallback = null
        }
    }

    /**
    * ✅ خواندن قد با بازه زمانی دلخواه
    *
    * @param startTime زمان شروع (ISO8601 format) - مثال: "2024-01-01T00:00:00.000Z"
    *                  پیش‌فرض: "2000-01-01T00:00:00.000Z"
    * @param endTime زمان پایان (ISO8601 format) - مثال: "2024-12-31T23:59:59.000Z"
    *                پیش‌فرض: زمان فعلی
    * @return JSON Array: [{"height_m": 1.75, "time": "2024-01-15T10:30:00Z"}, ...]
    *         یا "NO_HEIGHT_DATA" اگر داده‌ای نباشد
    */
    @JvmStatic
    fun readHeight(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val request = ReadRecordsRequest(
                recordType = HeightRecord::class,
                timeRangeFilter = createTimeFilter(startTime, endTime),
                ascendingOrder = true
            )
            val response = runBlocking(Dispatchers.IO) {
                safeReadBlocking(client, request)
            }
            if (response.records.isEmpty()) return "NO_HEIGHT_DATA"

            val arr = JSONArray()
            response.records.forEach { record ->
                arr.put(JSONObject().apply {
                    put("height_m", record.height.inMeters)
                    put("time", record.time.toString())
                })
            }
            arr.toString()
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error reading height", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading height", e)
            "ERROR: ${e.message}"
        }
    }

    /**
    * ✅ خواندن وزن با بازه زمانی دلخواه
    *
    * @param startTime زمان شروع (ISO8601)
    * @param endTime زمان پایان (ISO8601)
    * @return JSON Array: [{"weight_kg": 75.5, "time": "2024-01-15T10:30:00Z"}, ...]
    */
    @JvmStatic
    fun readWeight(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val request = ReadRecordsRequest(
                recordType = WeightRecord::class,
                timeRangeFilter = createTimeFilter(startTime, endTime),
                ascendingOrder = true
            )
            val response = runBlocking(Dispatchers.IO) {
                safeReadBlocking(client, request)
            }
            if (response.records.isEmpty()) return "NO_WEIGHT_DATA"

            val arr = JSONArray()
            response.records.forEach { record ->
                arr.put(JSONObject().apply {
                    put("weight_kg", record.weight.inKilograms)
                    put("time", record.time.toString())
                })
            }
            arr.toString()
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error reading weight", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading weight", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ نوشتن قد با زمان دلخواه
     */
    @JvmStatic
    fun writeHeight(heightMeters: Double, timeIso: String): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (heightMeters < 0.1 || heightMeters > 3) {
                return "ERROR: Invalid height value ($heightMeters m). Must be between 0.1 and 3 meters."
            }

            // ✅ تبدیل زمان ISO به Instant
            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)

            val heightRecord = HeightRecord(
                height = Length.meters(heightMeters),
                time = instant,
                zoneOffset = zoneOffset
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(heightRecord))
            }

            "SUCCESS: Height $heightMeters m saved at $instant"

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
    fun writeWeight(weightKg: Double, timeIso: String): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (weightKg < 0.1 || weightKg > 300.0) {
                return "ERROR: Invalid weight value ($weightKg kg). Must be between 0.1 and 300 kg."
            }

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)

            val weightRecord = WeightRecord(
                weight = Mass.kilograms(weightKg),
                time = instant,
                zoneOffset = zoneOffset
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(weightRecord))
            }

            "SUCCESS: Weight $weightKg kg saved at $instant"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing weight", e)
            "ERROR: ${e.message}"
        }
    }

    /**
    * ✅ خواندن فشار خون با بازه زمانی دلخواه
    *
    * @param startTime زمان شروع (ISO8601)
    * @param endTime زمان پایان (ISO8601)
    * @return JSON Array: [{"systolic": 120, "diastolic": 80, "time": "..."}, ...]
    */
    @JvmStatic
    fun readBloodPressure(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val request = ReadRecordsRequest(
                recordType = BloodPressureRecord::class,
                timeRangeFilter = createTimeFilter(startTime, endTime),
                ascendingOrder = true
            )
            val response = runBlocking(Dispatchers.IO) {
                safeReadBlocking(client, request)
            }
            if (response.records.isEmpty()) return "NO_BLOOD_PRESSURE_DATA"

            val arr = JSONArray()
            response.records.forEach { record ->
                arr.put(JSONObject().apply {
                    put("systolic", record.systolic.inMillimetersOfMercury)
                    put("diastolic", record.diastolic.inMillimetersOfMercury)
                    put("time", record.time.toString())
                })
            }
            arr.toString()
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error reading blood pressure", e)
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
    fun writeBloodPressure(
        systolicMmHg: Double,
        diastolicMmHg: Double,
        timeIso: String
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (systolicMmHg < 80 || systolicMmHg > 200) {
                return "ERROR: Invalid systolic ($systolicMmHg). Must be 80-200 mmHg."
            }

            if (diastolicMmHg < 40 || diastolicMmHg > 130) {
                return "ERROR: Invalid diastolic ($diastolicMmHg). Must be 40-130 mmHg."
            }

            if (systolicMmHg <= diastolicMmHg) {
                return "ERROR: Systolic must be > diastolic"
            }

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)

            val record = BloodPressureRecord(
                systolic = Pressure.millimetersOfMercury(systolicMmHg),
                diastolic = Pressure.millimetersOfMercury(diastolicMmHg),
                time = instant,
                zoneOffset = zoneOffset
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(record))
            }

            "SUCCESS: BP $systolicMmHg/$diastolicMmHg saved at $instant"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing BP", e)
            "ERROR: ${e.message}"
        }
    }


    /**
    * ✅ خواندن قند خون با بازه زمانی دلخواه
    *
    * @param startTime زمان شروع (ISO8601)
    * @param endTime زمان پایان (ISO8601)
    * @return JSON Array
    */
    @JvmStatic
    fun readBloodGlucose(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val request = ReadRecordsRequest(
                recordType = BloodGlucoseRecord::class,
                timeRangeFilter = createTimeFilter(startTime, endTime),
                ascendingOrder = true
            )
            val response = runBlocking(Dispatchers.IO) {
                safeReadBlocking(client, request)
            }
            if (response.records.isEmpty()) return "NO_BLOOD_GLUCOSE_DATA"

            val arr = JSONArray()
            response.records.forEach { record ->
                arr.put(JSONObject().apply {
                    put("mmol_per_l", record.level.inMillimolesPerLiter)
                    put("time", record.time.toString())
                })
            }
            arr.toString()
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error reading blood glucose", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading blood glucose", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ نوشتن قند خون با تمام جزئیات
     *
     * @param glucoseMgDl سطح قند خون به mg/dL (20-600)
     * @param specimenSource منبع نمونه (پیش‌فرض: خون مویرگی)
     * @param mealType نوع وعده غذایی (پیش‌فرض: نامشخص)
     * @param relationToMeal رابطه با غذا (پیش‌فرض: عمومی)
    */
    @JvmStatic
    fun writeBloodGlucose(
        glucoseMgDl: Double,
        specimenSource: Int,
        mealType: Int,
        relationToMeal: Int,
        timeIso: String
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (glucoseMgDl < 20.0 || glucoseMgDl > 600.0) {
                return "ERROR: Invalid glucose ($glucoseMgDl). Must be 20-600 mg/dL."
            }

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)

            val record = BloodGlucoseRecord(
                level = BloodGlucose.milligramsPerDeciliter(glucoseMgDl),
                specimenSource = specimenSource,
                mealType = mealType,
                relationToMeal = relationToMeal,
                time = instant,
                zoneOffset = zoneOffset
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(record))
            }

            "SUCCESS: Glucose $glucoseMgDl mg/dL saved at $instant"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing blood glucose", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ خواندن ضربان قلب با بازه زمانی دلخواه
     *
     * @param startTime زمان شروع (ISO8601)
     * @param endTime زمان پایان (ISO8601)
     * @return JSON Array: [{"bpm": 72, "time": "2024-01-15T10:30:00Z"}, ...]
    */
    @JvmStatic
    fun readHeartRate(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val request = ReadRecordsRequest(
                recordType = HeartRateRecord::class,
                timeRangeFilter = createTimeFilter(startTime, endTime),
                ascendingOrder = true
            )
            val response = runBlocking(Dispatchers.IO) {
                safeReadBlocking(client, request)
            }
            if (response.records.isEmpty()) return "NO_HEART_RATE_DATA"

            val arr = JSONArray()
            response.records.forEach { record ->
                record.samples.forEach { sample ->
                    arr.put(JSONObject().apply {
                        put("bpm", sample.beatsPerMinute)
                        put("time", sample.time.toString())
                    })
                }
            }
            if (arr.length() == 0) return "NO_HEART_RATE_DATA"
            arr.toString()
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error reading heart rate", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading heart rate", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ نوشتن ضربان قلب
     *
     * @param bpm ضربان قلب (30-250)
    */
    @JvmStatic
    fun writeHeartRate(bpm: Long, timeIso: String): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (bpm < 30 || bpm > 250) {
                return "ERROR: Invalid heart rate ($bpm). Must be 30-250 bpm."
            }

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)

            val record = HeartRateRecord(
                startTime = instant,
                startZoneOffset = zoneOffset,
                endTime = instant,
                endZoneOffset = zoneOffset,
                samples = listOf(
                    HeartRateRecord.Sample(
                        time = instant,
                        beatsPerMinute = bpm
                    )
                )
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(record))
            }

            "SUCCESS: Heart rate $bpm bpm saved at $instant"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing heart rate", e)
            "ERROR: ${e.message}"
        }
    }

    /**
    * ✅ خواندن رکوردهای اشباع اکسیژن خون (SpO₂)
    *
    * @return آرایهٔ JSON شامل درصد، زمان، نمونه‌ها و متادیتا؛ یا پیام خطا
    */
    @JvmStatic
    fun readOxygenSaturation(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val request = ReadRecordsRequest(
                recordType = OxygenSaturationRecord::class,
                timeRangeFilter = createTimeFilter(startTime, endTime),
                ascendingOrder = true
            )
            val response = runBlocking(Dispatchers.IO) {
                safeReadBlocking(client, request)
            }
            if (response.records.isEmpty()) return "NO_OXYGEN_DATA"

            val arr = JSONArray()
            response.records.forEach { record ->
                arr.put(JSONObject().apply {
                    put("percentage", record.percentage.value)
                    put("time", record.time.toString())
                })
            }
            arr.toString()
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error reading oxygen saturation", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading oxygen saturation", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ نوشتن یک رکورد اشباع اکسیژن خون (SpO₂)
     *
     * @param percentage درصد اشباع (۰ تا ۱۰۰)
     * @param timeIso زمان به فرمت ISO8601 (مثلاً 2024-02-16T08:30:00Z)
     */
    @JvmStatic
    fun writeOxygenSaturation(percentage: Double, timeIso: String): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            if (percentage < 50.0 || percentage > 100.0) {
                return "ERROR: Invalid SpO2 ($percentage). Must be 50-100%"
            }

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)

            val record = OxygenSaturationRecord(
                percentage = Percentage(percentage),
                time = instant,
                zoneOffset = zoneOffset
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(record))
            }

            "SUCCESS: Oxygen saturation $percentage% saved at $instant"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error while writing oxygen saturation", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing oxygen saturation", e)
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
