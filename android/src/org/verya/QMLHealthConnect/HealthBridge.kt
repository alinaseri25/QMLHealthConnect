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
import androidx.health.connect.client.records.MenstruationFlowRecord
import androidx.health.connect.client.records.MenstruationPeriodRecord

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

    // ══════════════════════════════════════════════════════════════
    // منبع واحد حقیقت برای مجوزها
    // هر entry: Pair(permissionString, nameForJson)
    // ══════════════════════════════════════════════════════════════
    private val PERMISSION_META = listOf(
        Pair(HealthPermission.getReadPermission(HeightRecord::class),              "readHeight"),
        Pair(HealthPermission.getWritePermission(HeightRecord::class),             "writeHeight"),
        Pair(HealthPermission.getReadPermission(WeightRecord::class),              "readWeight"),
        Pair(HealthPermission.getWritePermission(WeightRecord::class),             "writeWeight"),
        Pair(HealthPermission.getReadPermission(BloodPressureRecord::class),       "readBloodPressure"),
        Pair(HealthPermission.getWritePermission(BloodPressureRecord::class),      "writeBloodPressure"),
        Pair(HealthPermission.getReadPermission(HeartRateRecord::class),           "readHeartRate"),
        Pair(HealthPermission.getWritePermission(HeartRateRecord::class),          "writeHeartRate"),
        Pair(HealthPermission.getReadPermission(BloodGlucoseRecord::class),        "readBloodGlucose"),
        Pair(HealthPermission.getWritePermission(BloodGlucoseRecord::class),       "writeBloodGlucose"),
        Pair(HealthPermission.getReadPermission(OxygenSaturationRecord::class),    "readOxygenSaturation"),
        Pair(HealthPermission.getWritePermission(OxygenSaturationRecord::class),   "writeOxygenSaturation"),
        Pair(HealthPermission.getReadPermission(MenstruationPeriodRecord::class),  "readMenstruationPeriod"),
        Pair(HealthPermission.getWritePermission(MenstruationPeriodRecord::class), "writeMenstruationPeriod"),
        Pair(HealthPermission.getReadPermission(MenstruationFlowRecord::class),    "readMenstruationFlow"),
        Pair(HealthPermission.getWritePermission(MenstruationFlowRecord::class),   "writeMenstruationFlow")
    )

    // مشتق‌شده از PERMISSION_META — همیشه هماهنگ
    val PERMISSIONS: Set<String> = PERMISSION_META.map { it.first }.toSet()

    private var appContext: Context? = null
    private var healthConnectClient: HealthConnectClient? = null
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    var permissionCallback: ((Boolean) -> Unit)? = null

    // ─────────────────────────────────────────────────────────────
    // HELPERS
    // ─────────────────────────────────────────────────────────────
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

    // ─────────────────────────────────────────────────────────────
    // PERMISSIONS — checkPermissions: خروجی JSON برای C++
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun checkPermissions(): String {
        val client = healthConnectClient ?: return """{"error":"CLIENT_NULL","allGranted":false}"""
        return try {
            val granted = runBlocking(Dispatchers.IO) {
                client.permissionController.getGrantedPermissions()
            }

            val permArray    = JSONArray()
            var grantedCount = 0

            PERMISSION_META.forEach { (permString, name) ->
                val isGranted = granted.contains(permString)
                if (isGranted) grantedCount++
                permArray.put(JSONObject().apply {
                    put("name",    name)
                    put("granted", isGranted)
                })
            }

            JSONObject().apply {
                put("allGranted",   grantedCount == PERMISSION_META.size)
                put("grantedCount", grantedCount)
                put("totalCount",   PERMISSION_META.size)
                put("permissions",  permArray)
            }.toString()

        } catch (e: Exception) {
            Log.e(TAG, "❌ checkPermissions failed", e)
            JSONObject().apply {
                put("error",      e.message ?: "UNKNOWN_ERROR")
                put("allGranted", false)
            }.toString()
        }
    }

    // ─────────────────────────────────────────────────────────────
    // PERMISSIONS — requestPermissions
    // ─────────────────────────────────────────────────────────────
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
            // ✅ از List استفاده می‌کنیم نه Map — تا رکوردهای هم‌زمان گم نشن
            val records = mutableListOf<BloodGlucoseRecord>()
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

                records.addAll(response.records)

                val newToken = response.pageToken
                pageCount++

                if (newToken == pageToken && newToken != null) {
                    Log.w(TAG, "⚠️ Glucose: pageToken unchanged — SDK bug detected. Stopping.")
                    break
                }
                pageToken = newToken

            } while (pageToken != null && pageCount < MAX_PAGES)

            if (records.isEmpty()) return "NO_BLOOD_GLUCOSE_DATA"

            // ✅ مرتب‌سازی بر اساس زمان (چون دیگه sortedMap نداریم)
            records.sortBy { it.time }

            val arr = JSONArray()
            records.forEach { record ->
                arr.put(JSONObject().apply {
                    put("time",            record.time.toString())
                    put("glucose",         record.level.inMilligramsPerDeciliter)
                    put("specimenSource",  record.specimenSource)
                    put("mealType",        record.mealType)
                    put("relationToMeal",  record.relationToMeal)
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

    // ─────────────────────────────────────────────────────────────
    // WRITE MENSTRUATION PERIOD
    // ثبت بازه کامل دوره قاعدگی (startTime تا endTime)
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun writeMenstruationPeriod(
        startTimeIso: String,
        endTimeIso: String
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            val startInstant = Instant.parse(startTimeIso)
            val endInstant   = Instant.parse(endTimeIso)

            if (!endInstant.isAfter(startInstant)) {
                return "ERROR: endTime must be after startTime"
            }

            // حداکثر طول منطقی دوره: 15 روز
            val diffDays = ChronoUnit.DAYS.between(startInstant, endInstant)
            if (diffDays > 15) {
                return "ERROR: Period duration too long ($diffDays days). Max is 15 days."
            }

            val startZoneOffset = ZoneId.systemDefault().rules.getOffset(startInstant)
            val endZoneOffset   = ZoneId.systemDefault().rules.getOffset(endInstant)

            val record = MenstruationPeriodRecord(
                startTime       = startInstant,
                startZoneOffset = startZoneOffset,
                endTime         = endInstant,
                endZoneOffset   = endZoneOffset
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(record))
            }

            "SUCCESS: Menstruation period saved from $startInstant to $endInstant"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error writing menstruation period", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing menstruation period", e)
            "ERROR: ${e.message}"
        }
    }

    // ─────────────────────────────────────────────────────────────
    // WRITE MENSTRUATION FLOW
    // ثبت شدت خونریزی در یک لحظه مشخص
    // flowLevel: 0=UNKNOWN, 1=LIGHT, 2=MEDIUM, 3=HEAVY
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun writeMenstruationFlow(
        timeIso: String,
        flowLevel: Int
    ): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"
        return try {
            // اعتبارسنجی flowLevel — دقیقاً مثل validation های بقیه توابع
            if (flowLevel < 0 || flowLevel > 3) {
                return "ERROR: Invalid flowLevel ($flowLevel). Must be 0-3 " +
                       "(0=UNKNOWN, 1=LIGHT, 2=MEDIUM, 3=HEAVY)"
            }

            val instant    = Instant.parse(timeIso)
            val zoneOffset = ZoneId.systemDefault().rules.getOffset(instant)

            val flow = when (flowLevel) {
                1    -> MenstruationFlowRecord.FLOW_LIGHT
                2    -> MenstruationFlowRecord.FLOW_MEDIUM
                3    -> MenstruationFlowRecord.FLOW_HEAVY
                else -> MenstruationFlowRecord.FLOW_UNKNOWN
            }

            val record = MenstruationFlowRecord(
                time       = instant,
                zoneOffset = zoneOffset,
                flow       = flow
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(record))
            }

            "SUCCESS: Menstruation flow level $flowLevel saved at $instant"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error writing menstruation flow", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing menstruation flow", e)
            "ERROR: ${e.message}"
        }
    }

    // ─────────────────────────────────────────────────────────────
    // READ MENSTRUATION DATA — با pagination، هم‌سبک با readHeartRate
    // خروجی JSON ترکیبی از periods و flows:
    // {
    //   "periods": [ { "start": "...", "end": "..." }, ... ],
    //   "flows":   [ { "time": "...", "flow": 2 }, ... ]
    // }
    // ─────────────────────────────────────────────────────────────
    @JvmStatic
    fun readMenstruationData(startTime: String?, endTime: String?): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            val result = runBlocking {
                val timeFilter = createTimeFilter(startTime, endTime)

                // ── خواندن دوره‌ها ──────────────────────────────────────
                val periodsResponse = safeReadBlocking(
                    client,
                    ReadRecordsRequest(
                        recordType       = MenstruationPeriodRecord::class,
                        timeRangeFilter  = timeFilter
                    )
                )

                // ── خواندن جریان‌ها ─────────────────────────────────────
                val flowsResponse = safeReadBlocking(
                    client,
                    ReadRecordsRequest(
                        recordType       = MenstruationFlowRecord::class,
                        timeRangeFilter  = timeFilter
                    )
                )

                val periodsArr = JSONArray()
                for (record in periodsResponse.records) {
                    val obj = JSONObject()
                    // ✅ کلیدهای صحیح: "start" و "end"
                    obj.put("start", record.startTime.toString())
                    obj.put("end",   record.endTime.toString())
                    periodsArr.put(obj)

                    Log.d("HealthBridge", "[Kotlin] period: ${record.startTime} → ${record.endTime}")
                }

                val flowsArr = JSONArray()
                for (record in flowsResponse.records) {
                    val obj = JSONObject()
                    // ✅ کلید صحیح: "time" (نه "timeMs")
                    // ✅ مقدار صحیح: record.flow (نه record.level)
                    obj.put("time",  record.time.toString())
                    obj.put("level", record.flow)   // ← این مقدار 1، 2 یا 3 است

                    Log.d("HealthBridge", "[Kotlin] flow: time=${record.time} flow=${record.flow}")
                    flowsArr.put(obj)
                }

                val root = JSONObject()
                root.put("periods", periodsArr)
                root.put("flows",   flowsArr)
                root.toString()
            }
            result
        } catch (e: Exception) {
            Log.e("HealthBridge", "readMenstruationData error: ${e.message}")
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
