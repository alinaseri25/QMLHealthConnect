package org.verya.QMLHealthConnect

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.WeightRecord
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
        HealthPermission.getWritePermission(WeightRecord::class)
    )

    @JvmStatic
    fun init(context: Context) {
        appContext = context.applicationContext

        try {
            val availability = HealthConnectClient.getSdkStatus(appContext!!)

            when (availability) {
                HealthConnectClient.SDK_UNAVAILABLE -> {
                    Log.e(TAG, "Health Connect is not available")
                    return
                }
                HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> {
                    Log.w(TAG, "Health Connect needs update")
                }
            }

            healthConnectClient = HealthConnectClient.getOrCreate(appContext!!)
            Log.d(TAG, "✅ Health Connect initialized")

        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to initialize", e)
            healthConnectClient = null
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
     * ✅ درخواست Permission با استفاده از Intent مستقیم
     */
    @JvmStatic
    fun requestPermissions(activity: Activity): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

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

                    // ✅ استفاده از Intent مستقیم
                    val packageName = "com.google.android.apps.healthdata"
                    val intent = Intent("androidx.health.ACTION_REQUEST_PERMISSIONS").apply {
                        setPackage(packageName)
                        putExtra(
                            "androidx.health.EXTRA_PERMISSIONS",
                            toRequest.toTypedArray()
                        )
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
            val start = Instant.parse("2000-01-01T00:00:00.000Z")//end.minus(365, ChronoUnit.DAYS)

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
            val start = Instant.parse("2000-01-01T00:00:00.000Z")//end.minus(365, ChronoUnit.DAYS)

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
     * ✅ نوشتن داده تست برای Height
     */
    @JvmStatic
    fun writeTestHeight(): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            Log.d(TAG, "📝 Writing test height...")

            val heightRecord = HeightRecord(
                height = androidx.health.connect.client.units.Length.meters(1.75),
                time = Instant.now(),
                zoneOffset = ZoneId.systemDefault().rules.getOffset(Instant.now())
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(heightRecord))
            }

            Log.d(TAG, "✅ Test height written: 1.75m")
            "TEST_HEIGHT_WRITTEN: 1.75m"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error: No write permission", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing height", e)
            "ERROR: ${e.message}"
        }
    }

    /**
     * ✅ نوشتن داده تست برای Weight
     */
    @JvmStatic
    fun writeTestWeight(): String {
        val client = healthConnectClient ?: return "CLIENT_NULL"

        return try {
            Log.d(TAG, "📝 Writing test weight...")

            val weightRecord = WeightRecord(
                weight = androidx.health.connect.client.units.Mass.kilograms(70.0),
                time = Instant.now(),
                zoneOffset = ZoneId.systemDefault().rules.getOffset(Instant.now())
            )

            runBlocking(Dispatchers.IO) {
                client.insertRecords(listOf(weightRecord))
            }

            Log.d(TAG, "✅ Test weight written: 70kg")
            "TEST_WEIGHT_WRITTEN: 70kg"

        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security error: No write permission", e)
            "SECURITY_ERROR"
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error writing weight", e)
            "ERROR: ${e.message}"
        }
    }
}
