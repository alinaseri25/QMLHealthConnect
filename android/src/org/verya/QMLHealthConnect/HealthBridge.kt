package org.verya.QMLHealthConnect

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log

import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter

import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.health.connect.client.records.BloodPressureRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.OxygenSaturationRecord

import androidx.health.connect.client.response.ReadRecordsResponse

import androidx.health.connect.client.units.Length
import androidx.health.connect.client.units.Mass
import androidx.health.connect.client.units.Pressure
import androidx.health.connect.client.units.BloodGlucose
import androidx.health.connect.client.units.Percentage

import kotlinx.coroutines.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

import org.json.JSONArray
import org.json.JSONObject

import java.time.Instant
import java.time.ZoneId
import java.time.temporal.ChronoUnit

object HealthBridge {

    private const val TAG = "HealthBridge"
    const val REQUEST_CODE_PERMISSIONS = 1001

    private const val SPECIMEN_SOURCE_CAPILLARY_BLOOD = 1
    private const val MEAL_TYPE_UNKNOWN = 0
    private const val RELATION_TO_MEAL_GENERAL = 0

    // ── سراسری: حداکثر صفحات برای همه توابع read ─────────────────
    private const val MAX_PAGES = 30

    private val readMutex = Mutex()

    private suspend fun <T : Record> safeReadBlocking(
        client: HealthConnectClient,
        request: ReadRecordsRequest<T>,
        maxRetries: Int = 5
    ): ReadRecordsResponse<T> {
        var delayMs = 1000L
        var lastException: Exception? = null

        repeat(maxRetries) {
            try {
                return readMutex.withLock {
                    client.readRecords(request)
                }
            } catch (e: Exception) {
                lastException = e
                val msg = e.message ?: ""
                val isRetryable = msg.contains("Rate limit", ignoreCase = true)
                        || msg.contains("quota", ignoreCase = true)
                        || msg.contains("rejected", ignoreCase = true)
                        || msg.contains("Binder", ignoreCase = true)
                        || msg.contains("Transaction", ignoreCase = true)
                        || msg.contains("timeout", ignoreCase = true)
                        || msg.contains("temporarily", ignoreCase = true)

                if (!isRetryable) throw e
                delay(delayMs)
                delayMs = (delayMs * 2).coerceAtMost(8000L)
            }
        }
        throw lastException ?: Exception("safeReadBlocking: max retries exceeded")
    }

    private fun createTimeFilter(
        startTime: String? = null,
        endTime: String? = null
    ): TimeRangeFilter {
        val start = parseInstant(startTime) ?: Instant.parse("2000-01-01T00:00:00.000Z")
        val end = parseInstant(endTime) ?: Instant.now()
        return TimeRangeFilter.between(start, end)
    }

    private fun parseInstant(isoString: String?): Instant? {
        return try {
            if (isoString.isNullOrBlank()) null else Instant.parse(isoString)
        } catch (e: Exception) {
            null
        }
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
        val packageName = if (android.os.Build.VERSION.SDK_INT >= 34)
            "com.android.healthconnect.controller"
        else
            "com.google.android.apps.healthdata"
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
        val packageName = if (android.os.Build.VERSION.SDK_INT >= 34)
            "com.android.healthconnect.controller"
        else
            "com.google.android.apps.healthdata"
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
            "com.android.healthconnect.controller",
            "com.google.android.apps.healthdata"
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
        return try {
            healthConnectClient = HealthConnectClient.getOrCreate(context.applicationContext)
            "INIT_SUCCESS"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Init failed", e)
            "INIT_ERROR: ${e.message}"
        }
    }

    @JvmStatic
    fun checkPermissions(): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val granted = runBlocking(Dispatchers.IO) {
                client.permissionController.getGrantedPermissions()
            }
            val grantedCount = granted.intersect(PERMISSIONS).size
            if (grantedCount == PERMISSIONS.size) "ALL_GRANTED ($grantedCount/${PERMISSIONS.size})"
            else "PARTIAL ($grantedCount/${PERMISSIONS.size})"
        } catch (e: Exception) {
            Log.e(TAG, "❌ checkPermissions failed", e)
            "ERROR: ${e.message}"
        }
    }

    @JvmStatic
    fun requestPermissions(activity: Activity): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            scope.launch {
                try {
                    val granted = client.permissionController.getGrantedPermissions()
                    val toRequest = PERMISSIONS - granted

                    if (toRequest.isEmpty()) {
                        withContext(Dispatchers.Main) {
                            permissionCallback?.invoke(true)
                            permissionCallback = null
                        }
                        return@launch
                    }

                    val hcPackage = getHealthConnectPackageName() ?: run {
                        withContext(Dispatchers.Main) {
                            permissionCallback?.invoke(false)
                            permissionCallback = null
                        }
                        return@launch
                    }

                    val intent = Intent("androidx.health.ACTION_REQUEST_PERMISSIONS").apply {
                        setPackage(hcPackage)
                        putExtra("androidx.health.EXTRA_PERMISSIONS", toRequest.toTypedArray())
                    }

                    withContext(Dispatchers.Main) {
                        activity.startActivityForResult(intent, REQUEST_CODE_PERMISSIONS)
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
            permissionCallback?.invoke(success)
            permissionCallback = null
        }
    }

    // ─────────────────────────────────────────────────────────────
    // READ HEIGHT — با pagination
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun readHeight(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val pointMap = sortedMapOf<Instant, Double>()
            var pageToken: String? = null
            var pageCount = 0

            do {
                val request = ReadRecordsRequest(
                    recordType = HeightRecord::class,
                    timeRangeFilter = createTimeFilter(startTime, endTime),
                    ascendingOrder = true,
                    pageSize = 1000,
                    pageToken = pageToken
                )
                val response = runBlocking(Dispatchers.IO) {
                    safeReadBlocking(client, request)
                }

                response.records.forEach { record ->
                    pointMap[record.time] = record.height.inMeters
                }

                val newToken = response.pageToken
                pageCount++

                if (newToken == pageToken && newToken != null) {
                    Log.w(TAG, "⚠️ Height: pageToken unchanged — SDK bug detected. Stopping.")
                    break
                }
                pageToken = newToken

            } while (pageToken != null && pageCount < MAX_PAGES)

            if (pointMap.isEmpty()) return "NO_HEIGHT_DATA"

            val arr = JSONArray()
            pointMap.forEach { (time, meters) ->
                arr.put(JSONObject().apply {
                    put("height_m", meters)
                    put("time", time.toString())
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

    // ─────────────────────────────────────────────────────────────
    // WRITE HEIGHT
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun writeHeight(heightMeters: Double, timeIso: String): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            if (heightMeters < 0.1 || heightMeters > 3.0)
                return "ERROR: Invalid height ($heightMeters). Must be 0.1-3.0 m"

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)
            val record = HeightRecord(
                height = Length.meters(heightMeters),
                time = instant,
                zoneOffset = zoneOffset
            )
            runBlocking(Dispatchers.IO) { client.insertRecords(listOf(record)) }
            "SUCCESS: Height $heightMeters m saved at $instant"
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error writing height", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing height", e)
            "ERROR: ${e.message}"
        }
    }

    // ─────────────────────────────────────────────────────────────
    // READ WEIGHT — با pagination
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun readWeight(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val pointMap = sortedMapOf<Instant, Double>()
            var pageToken: String? = null
            var pageCount = 0

            do {
                val request = ReadRecordsRequest(
                    recordType = WeightRecord::class,
                    timeRangeFilter = createTimeFilter(startTime, endTime),
                    ascendingOrder = true,
                    pageSize = 1000,
                    pageToken = pageToken
                )
                val response = runBlocking(Dispatchers.IO) {
                    safeReadBlocking(client, request)
                }

                response.records.forEach { record ->
                    pointMap[record.time] = record.weight.inKilograms
                }

                val newToken = response.pageToken
                pageCount++

                if (newToken == pageToken && newToken != null) {
                    Log.w(TAG, "⚠️ Weight: pageToken unchanged — SDK bug detected. Stopping.")
                    break
                }
                pageToken = newToken

            } while (pageToken != null && pageCount < MAX_PAGES)

            if (pointMap.isEmpty()) return "NO_WEIGHT_DATA"

            val arr = JSONArray()
            pointMap.forEach { (time, kg) ->
                arr.put(JSONObject().apply {
                    put("weight_kg", kg)
                    put("time", time.toString())
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

    // ─────────────────────────────────────────────────────────────
    // WRITE WEIGHT
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun writeWeight(weightKg: Double, timeIso: String): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            if (weightKg < 0.1 || weightKg > 300.0)
                return "ERROR: Invalid weight ($weightKg). Must be 0.1-300 kg"

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)
            val record = WeightRecord(
                weight = Mass.kilograms(weightKg),
                time = instant,
                zoneOffset = zoneOffset
            )
            runBlocking(Dispatchers.IO) { client.insertRecords(listOf(record)) }
            "SUCCESS: Weight $weightKg kg saved at $instant"
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error writing weight", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing weight", e)
            "ERROR: ${e.message}"
        }
    }

    // ─────────────────────────────────────────────────────────────
    // READ BLOOD PRESSURE — با pagination
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun readBloodPressure(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            data class BPPoint(val sys: Double, val dia: Double)
            val pointMap = sortedMapOf<Instant, BPPoint>()
            var pageToken: String? = null
            var pageCount = 0

            do {
                val request = ReadRecordsRequest(
                    recordType = BloodPressureRecord::class,
                    timeRangeFilter = createTimeFilter(startTime, endTime),
                    ascendingOrder = true,
                    pageSize = 1000,
                    pageToken = pageToken
                )
                val response = runBlocking(Dispatchers.IO) {
                    safeReadBlocking(client, request)
                }

                response.records.forEach { record ->
                    pointMap[record.time] = BPPoint(
                        record.systolic.inMillimetersOfMercury,
                        record.diastolic.inMillimetersOfMercury
                    )
                }

                val newToken = response.pageToken
                pageCount++

                if (newToken == pageToken && newToken != null) {
                    Log.w(TAG, "⚠️ BP: pageToken unchanged — SDK bug detected. Stopping.")
                    break
                }
                pageToken = newToken

            } while (pageToken != null && pageCount < MAX_PAGES)

            if (pointMap.isEmpty()) return "NO_BLOOD_PRESSURE_DATA"

            val arr = JSONArray()
            pointMap.forEach { (time, bp) ->
                arr.put(JSONObject().apply {
                    put("systolic", bp.sys)
                    put("diastolic", bp.dia)
                    put("time", time.toString())
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

    // ─────────────────────────────────────────────────────────────
    // WRITE BLOOD PRESSURE
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun writeBloodPressure(systolicMmHg: Double, diastolicMmHg: Double, timeIso: String): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            if (systolicMmHg < 80 || systolicMmHg > 200)
                return "ERROR: Invalid systolic ($systolicMmHg). Must be 80-200 mmHg"
            if (diastolicMmHg < 40 || diastolicMmHg > 130)
                return "ERROR: Invalid diastolic ($diastolicMmHg). Must be 40-130 mmHg."
            if (systolicMmHg <= diastolicMmHg)
                return "ERROR: Systolic must be > diastolic"

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)
            val record = BloodPressureRecord(
                systolic = Pressure.millimetersOfMercury(systolicMmHg),
                diastolic = Pressure.millimetersOfMercury(diastolicMmHg),
                time = instant,
                zoneOffset = zoneOffset
            )
            runBlocking(Dispatchers.IO) { client.insertRecords(listOf(record)) }
            "SUCCESS: BP $systolicMmHg/$diastolicMmHg saved at $instant"
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing BP", e)
            "ERROR: ${e.message}"
        }
    }

    // ─────────────────────────────────────────────────────────────
    // READ BLOOD GLUCOSE — با pagination
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun readBloodGlucose(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val pointMap = sortedMapOf<Instant, Double>()
            var pageToken: String? = null
            var pageCount = 0

            do {
                val request = ReadRecordsRequest(
                    recordType = BloodGlucoseRecord::class,
                    timeRangeFilter = createTimeFilter(startTime, endTime),
                    ascendingOrder = true,
                    pageSize = 1000,
                    pageToken = pageToken
                )
                val response = runBlocking(Dispatchers.IO) {
                    safeReadBlocking(client, request)
                }

                // ✅ FIX: تبدیل به mg/dL برای یکسان‌سازی با writeBloodGlucose
                // قبلاً: inMillimolesPerLiter → کلید "mmol_per_l"  (ناسازگار با write)
                // الان: inMilligramsPerDeciliter → کلید "mg_per_dl"  (سازگار با write)
                response.records.forEach { record ->
                    pointMap[record.time] = record.level.inMilligramsPerDeciliter
                }

                val newToken = response.pageToken
                pageCount++

                if (newToken == pageToken && newToken != null) {
                    Log.w(TAG, "⚠️ Glucose: pageToken unchanged — SDK bug detected. Stopping.")
                    break
                }
                pageToken = newToken

            } while (pageToken != null && pageCount < MAX_PAGES)

            if (pointMap.isEmpty()) return "NO_BLOOD_GLUCOSE_DATA"

            val arr = JSONArray()
            pointMap.forEach { (time, mgDl) ->
                arr.put(JSONObject().apply {
                    put("mg_per_dl", mgDl)
                    put("time", time.toString())
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

    // ─────────────────────────────────────────────────────────────
    // WRITE BLOOD GLUCOSE
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun writeBloodGlucose(
        glucoseMgDl: Double,
        timeIso: String,
        specimenSource: Int = SPECIMEN_SOURCE_CAPILLARY_BLOOD,
        mealType: Int = MEAL_TYPE_UNKNOWN,
        relationToMeal: Int = RELATION_TO_MEAL_GENERAL
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

    // ─────────────────────────────────────────────────────────────
    // READ HEART RATE — با pagination
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun readHeartRate(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val pointMap = sortedMapOf<Instant, Long>()
            var pageToken: String? = null
            var pageCount = 0

            do {
                val request = ReadRecordsRequest(
                    recordType = HeartRateRecord::class,
                    timeRangeFilter = createTimeFilter(startTime, endTime),
                    ascendingOrder = true,
                    pageSize = 1000,
                    pageToken = pageToken
                )
                val response = runBlocking(Dispatchers.IO) {
                    safeReadBlocking(client, request)
                }

                response.records.forEach { record ->
                    record.samples.forEach { sample ->
                        pointMap[sample.time] = sample.beatsPerMinute
                    }
                }

                val newToken = response.pageToken
                pageCount++

                if (newToken == pageToken && newToken != null) {
                    Log.w(TAG, "⚠️ HR: pageToken unchanged — SDK bug detected. Stopping.")
                    break
                }
                pageToken = newToken

            } while (pageToken != null && pageCount < MAX_PAGES)

            if (pointMap.isEmpty()) return "NO_HEART_RATE_DATA"

            val arr = JSONArray()
            pointMap.forEach { (time, bpm) ->
                arr.put(JSONObject().apply {
                    put("bpm", bpm)
                    put("time", time.toString())
                })
            }
            arr.toString()

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error reading heart rate", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error reading heart rate", e)
            "ERROR: ${e.message}"
        }
    }

    // ─────────────────────────────────────────────────────────────
    // WRITE HEART RATE
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun writeHeartRate(bpm: Long, timeIso: String): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            if (bpm < 30 || bpm > 250)
                return "ERROR: Invalid heart rate ($bpm). Must be 30-250 bpm"

            val instant = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)
            val sample = HeartRateRecord.Sample(time = instant, beatsPerMinute = bpm)
            val record = HeartRateRecord(
                samples = listOf(sample),
                startTime = instant,
                endTime = instant,
                startZoneOffset = zoneOffset,
                endZoneOffset = zoneOffset
            )
            runBlocking(Dispatchers.IO) { client.insertRecords(listOf(record)) }
            "SUCCESS: Heart rate $bpm bpm saved at $instant"
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error writing heart rate", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing heart rate", e)
            "ERROR: ${e.message}"
        }
    }

    // ─────────────────────────────────────────────────────────────
    // READ OXYGEN SATURATION — با pagination
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun readOxygenSaturation(
        startTime: String? = null,
        endTime: String? = null
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val pointMap = sortedMapOf<Instant, Double>()
            var pageToken: String? = null
            var pageCount = 0

            do {
                val request = ReadRecordsRequest(
                    recordType = OxygenSaturationRecord::class,
                    timeRangeFilter = createTimeFilter(startTime, endTime),
                    ascendingOrder = true,
                    pageSize = 1000,
                    pageToken = pageToken
                )
                val response = runBlocking(Dispatchers.IO) {
                    safeReadBlocking(client, request)
                }

                response.records.forEach { record ->
                    pointMap[record.time] = record.percentage.value
                }

                val newToken = response.pageToken
                pageCount++

                if (newToken == pageToken && newToken != null) {
                    Log.w(TAG, "⚠️ SpO2: pageToken unchanged — likely Android < 14 SDK bug. Stopping.")
                    break
                }
                pageToken = newToken

            } while (pageToken != null && pageCount < MAX_PAGES)

            if (pointMap.isEmpty()) return "NO_OXYGEN_DATA"

            val arr = JSONArray()
            pointMap.forEach { (time, percentage) ->
                arr.put(JSONObject().apply {
                    put("percentage", percentage)
                    put("time", time.toString())
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

    // ─────────────────────────────────────────────────────────────
    // WRITE OXYGEN SATURATION
    // ─────────────────────────────────────────────────────────────
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
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            "STORE_OPENED"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Cannot open store", e)
            "ERROR: ${e.message}"
        }
    }
}
