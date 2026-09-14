package com.kina.care

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.Icon
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.kina.care.domain.model.Booking
import com.kina.care.presentation.common.NoInternetScreen
import com.kina.care.presentation.navigation.AppNavigation
import com.kina.care.presentation.util.LocalIsSinhala
import com.kina.care.presentation.util.NetworkMonitor
import com.kina.care.services.LocationTrackingService
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.ExistingPeriodicWorkPolicy
import com.kina.care.workers.MedicineReminderWorker
import java.util.concurrent.TimeUnit

class MainActivity : ComponentActivity() {

    private val CHANNEL_ID = "golden_hand_notifications"
    private var isListenerInitialized = false
    private var activeCaregiverListener: ListenerRegistration? = null
    private var lastGeofenceAlertTime = 0L

    private lateinit var sharedPreferences: SharedPreferences
    private lateinit var networkMonitor: NetworkMonitor

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        sharedPreferences = getSharedPreferences("KinaCarePrefs", Context.MODE_PRIVATE)
        createNotificationChannel()

        networkMonitor = NetworkMonitor(this)

        val reminderWorkRequest = PeriodicWorkRequestBuilder<MedicineReminderWorker>(15, TimeUnit.MINUTES).build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "MedicineReminder",
            ExistingPeriodicWorkPolicy.KEEP,
            reminderWorkRequest
        )

        setContent {
            MaterialTheme {
                val isSinhalaInitial = sharedPreferences.getBoolean("is_sinhala", false)
                val isSinhala = remember { mutableStateOf(isSinhalaInitial) }

                val isConnected by networkMonitor.isConnected.collectAsState()

                LaunchedEffect(isSinhala.value) {
                    sharedPreferences.edit().putBoolean("is_sinhala", isSinhala.value).apply()
                }

                var hasLocationPermission by remember {
                    mutableStateOf(
                        ContextCompat.checkSelfPermission(
                            this@MainActivity,
                            Manifest.permission.ACCESS_FINE_LOCATION
                        ) == PackageManager.PERMISSION_GRANTED
                    )
                }
                var userRole by remember { mutableStateOf("CLIENT") }
                var userHasActiveJob by remember { mutableStateOf(false) }

                val permissionLauncher =
                    rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { perms ->
                        hasLocationPermission =
                            perms[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
                                    perms[Manifest.permission.ACCESS_COARSE_LOCATION] == true
                    }

                var showLocationRationale by remember { mutableStateOf(false) }

                LaunchedEffect(Unit) {
                    if (!hasLocationPermission) {
                        showLocationRationale = true
                    } else {
                        val permissionsToRequest = mutableListOf<String>()
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
                            }
                        }
                        if (permissionsToRequest.isNotEmpty()) {
                            permissionLauncher.launch(permissionsToRequest.toTypedArray())
                        }
                    }
                }

                if (showLocationRationale) {
                    AlertDialog(
                        onDismissRequest = { 
                            showLocationRationale = false 
                            val permissionsToRequest = mutableListOf<String>()
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                    permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
                                }
                            }
                            if (permissionsToRequest.isNotEmpty()) {
                                permissionLauncher.launch(permissionsToRequest.toTypedArray())
                            }
                        },
                        title = { 
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Icon(Icons.Default.LocationOn, contentDescription = null, tint = Color(0xFF0EA5E9), modifier = Modifier.size(24.dp))
                                androidx.compose.foundation.layout.Spacer(modifier = Modifier.width(8.dp))
                                Text(if (isSinhala.value) "ස්ථානය (Location) තහවුරු කිරීම" else "Location Permission Required", fontWeight = FontWeight.Bold)
                            }
                        },
                        text = { 
                            Text(
                                if (isSinhala.value) 
                                    "සාත්තු සේවකයාට සේවාදායකයා සිටින නිවැරදිම ස්ථානය සැපයීමටත්, මෙම සේවකයා අදාළ ස්ථානයේ සැබැවින්ම සේවයේ යෙදී සිටින බව ඔබට අඳුරගැනීමටත් (tracking), හදිසි අවස්ථාවකදී (SOS) ට්‍රැක් කිරීමටත් මෙම ඇප් එකට පසුබිමින් පවා ඔබගේ Location ලබා ගැනීම අත්‍යවශ්‍ය වේ." 
                                else 
                                    "This app requires background location access to provide caregivers with exact client locations, allow clients to verify the caregiver's presence at the job site, and enable tracking during emergency SOS situations.",
                                color = Color.DarkGray
                            ) 
                        },
                        confirmButton = {
                            Button(onClick = {
                                showLocationRationale = false
                                val permissionsToRequest = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                    permissionsToRequest.add(Manifest.permission.POST_NOTIFICATIONS)
                                }
                                permissionLauncher.launch(permissionsToRequest.toTypedArray())
                            }) {
                                Text(if (isSinhala.value) "මම ප්‍රවේශ වීමට ඉඩ දෙමි" else "I Understand", fontWeight = FontWeight.Bold)
                            }
                        }
                    )
                }

                LaunchedEffect(hasLocationPermission, userRole, userHasActiveJob) {
                    val shouldTrack = (userRole == "CAREGIVER") || userHasActiveJob
                    val locationIntent =
                        Intent(this@MainActivity, LocationTrackingService::class.java)

                    try {
                        if (shouldTrack && hasLocationPermission) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(locationIntent)
                            } else {
                                startService(locationIntent)
                            }
                        } else {
                            stopService(locationIntent)
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }

                LaunchedEffect(Unit) {
                    val auth = FirebaseAuth.getInstance()
                    val firestore = FirebaseFirestore.getInstance()

                    auth.addAuthStateListener { firebaseAuth ->
                        val userId = firebaseAuth.currentUser?.uid
                        if (userId != null) {
                            var previousKycStatus: String? = null
                            var isUserListenerFirstRun = true

                            firestore.collection("users").document(userId)
                                .addSnapshotListener { userSnap, _ ->
                                    if (userSnap != null && userSnap.exists()) {
                                        val currentKycStatus = userSnap.getString("kycStatus")
                                        if (!isUserListenerFirstRun && previousKycStatus != currentKycStatus) {

                                            val isSin =
                                                sharedPreferences.getBoolean("is_sinhala", false)

                                            if (currentKycStatus == "APPROVED") {
                                                val title =
                                                    if (isSin) "ගිණුම අනුමත විය! 🎉" else "Account Approved! 🎉"
                                                val msg =
                                                    if (isSin) "ඔබගේ KYC අයදුම්පත අනුමත කර ඇත. ඔබට දැන් සේවාවන් ලබාගත හැක." else "Your KYC application has been approved. You can now accept jobs."
                                                sendNotification(title, msg)
                                            } else if (currentKycStatus == "REJECTED") {
                                                val title =
                                                    if (isSin) "ගිණුම ප්‍රතික්ෂේප විය ❌" else "Account Rejected ❌"
                                                val msg =
                                                    if (isSin) "ඔබගේ KYC අයදුම්පත ප්‍රතික්ෂේප කර ඇත. කරුණාකර ඇප් එක පරික්ෂා කරන්න." else "Your KYC application was rejected. Please check the app for details."
                                                sendNotification(title, msg)
                                            }
                                        }
                                        previousKycStatus = currentKycStatus
                                        isUserListenerFirstRun = false
                                    }
                                }

                            var connectedUserIds = mutableSetOf<String>()
                            val lastSosTime = System.currentTimeMillis()
                            firestore.collection("sos_alerts")
                                .whereGreaterThan("timestamp", lastSosTime)
                                .addSnapshotListener { sosSnap, _ ->
                                    if (sosSnap != null) {
                                        for (change in sosSnap.documentChanges) {
                                            if (change.type == DocumentChange.Type.ADDED) {
                                                val senderId = change.document.getString("userId") ?: ""
                                                if (connectedUserIds.contains(senderId)) {
                                                    val isSin = sharedPreferences.getBoolean("is_sinhala", false)
                                                    val senderName = change.document.getString("userName") ?: "Someone"
                                                    val title = if (isSin) "🚨 හදිසි අවස්ථාවක්!" else "🚨 EMERGENCY SOS!"
                                                    val msg = if (isSin) "$senderName හදිසි බොත්තම ක්‍රියාත්මක කර ඇත!" else "$senderName has triggered the SOS button!"
                                                    sendNotification(title, msg)
                                                }
                                            }
                                        }
                                    }
                                }

                            firestore.collection("users").document(userId).get()
                                .addOnSuccessListener { userDoc ->
                                    userRole = userDoc.getString("role") ?: "CLIENT"

                                    firestore.collection("bookings")
                                        .addSnapshotListener { snapshot, _ ->
                                            if (snapshot != null) {

                                                userHasActiveJob = snapshot.documents.mapNotNull {
                                                    it.toObject(Booking::class.java)
                                                }
                                                    .any { it.status == "IN_PROGRESS" && (it.caregiverId == userId || it.clientId == userId) }

                                                connectedUserIds.clear()
                                                snapshot.documents.mapNotNull { it.toObject(Booking::class.java) }
                                                    .filter { it.status == "IN_PROGRESS" }
                                                    .forEach { b ->
                                                        if (userRole == "CLIENT" && b.clientId == userId && b.caregiverId != null) {
                                                            connectedUserIds.add(b.caregiverId!!)
                                                        } else if ((userRole == "CAREGIVER" || userRole == "NURSE") && b.caregiverId == userId) {
                                                            connectedUserIds.add(b.clientId)
                                                        }
                                                    }

                                                if (!isListenerInitialized) {
                                                    isListenerInitialized = true

                                                    if (userRole == "CLIENT") {
                                                        val activeBooking =
                                                            snapshot.documents.mapNotNull {
                                                                it.toObject(Booking::class.java)
                                                            }
                                                                .find { it.status == "IN_PROGRESS" && it.clientId == userId }

                                                        if (activeBooking != null && activeBooking.caregiverId != null) {
                                                            activeCaregiverListener?.remove()
                                                            activeCaregiverListener =
                                                                firestore.collection("users")
                                                                    .document(activeBooking.caregiverId!!)
                                                                    .addSnapshotListener { cgSnap, _ ->
                                                                        val lat =
                                                                            cgSnap?.getDouble("locationLat")
                                                                                ?: 0.0
                                                                        val lng =
                                                                            cgSnap?.getDouble("locationLng")
                                                                                ?: 0.0
                                                                        if (lat != 0.0 && lng != 0.0) {
                                                                            val results =
                                                                                FloatArray(1)
                                                                            Location.distanceBetween(
                                                                                activeBooking.locationLat,
                                                                                activeBooking.locationLng,
                                                                                lat,
                                                                                lng,
                                                                                results
                                                                            )
                                                                            if (results[0] > 50f) {
                                                                                val now =
                                                                                    System.currentTimeMillis()
                                                                                if (now - lastGeofenceAlertTime > 5 * 60 * 1000) {
                                                                                    val isSin =
                                                                                        sharedPreferences.getBoolean(
                                                                                            "is_sinhala",
                                                                                            false
                                                                                        )
                                                                                    val title =
                                                                                        if (isSin) "අවධානයට! 🚨" else "Caregiver Alert 🚨"
                                                                                    val msg =
                                                                                        if (isSin) "ඔබගේ සේවකයා රෝගියා සිටින ස්ථානයෙන් මීටර් 50 කට වඩා ඈතට ගොස් ඇත!" else "The caregiver has moved more than 50 meters away from the patient's location!"
                                                                                    sendNotification(
                                                                                        title,
                                                                                        msg
                                                                                    )
                                                                                    lastGeofenceAlertTime =
                                                                                        now
                                                                                }
                                                                            }
                                                                        }
                                                                    }
                                                        }
                                                    }
                                                    return@addSnapshotListener
                                                }

                                                for (change in snapshot.documentChanges) {
                                                    val booking =
                                                        change.document.toObject(Booking::class.java)
                                                    val isSin = sharedPreferences.getBoolean(
                                                        "is_sinhala",
                                                        false
                                                    )

                                                    val currentStatus = booking.status?.uppercase() ?: ""
                                                    val isRelevantForMe = booking.caregiverId.isNullOrEmpty() || booking.caregiverId == userId

                                                    if (change.type == DocumentChange.Type.ADDED && userRole == "CAREGIVER" &&
                                                        (currentStatus == "BROADCASTED" || currentStatus == "PENDING") && isRelevantForMe) {

                                                        val title =
                                                            if (isSin) "නව රැකියා ඉල්ලීමක්! 🚨" else "New Job Request! 🚨"
                                                        val msg =
                                                            if (isSin) "ඔබට නව සේවා ඉල්ලීමක් ලැබී ඇත. කරුණාකර ඇප් එක පරික්ෂා කරන්න." else "A new service request is available. Please check the app."
                                                        sendNotification(title, msg)
                                                    }

                                                    if (change.type == DocumentChange.Type.MODIFIED) {
                                                        if (userRole == "CLIENT" && booking.clientId == userId) {
                                                            if (booking.status == "ACCEPTED" && !booking.isClientEnded) {
                                                                val title =
                                                                    if (isSin) "රැකියාව භාරගන්නා ලදී! ✅" else "Job Accepted! ✅"
                                                                val msg =
                                                                    if (isSin) "සාත්තු සේවකයෙකු ඔබගේ ඉල්ලීම භාරගෙන ඇත." else "A caregiver has accepted your request."
                                                                sendNotification(title, msg)
                                                            } else if (booking.status == "COMPLETED") {
                                                                val title =
                                                                    if (isSin) "රැකියාව අවසන්! 🎉" else "Job Completed! 🎉"
                                                                val msg =
                                                                    if (isSin) "ඔබගේ සේවාව සාර්ථකව අවසන් කර ඇත." else "Your service has been completed successfully."
                                                                sendNotification(title, msg)
                                                            } else if (booking.status == "REJECTED" || booking.status == "DECLINED") {
                                                                // 🌟 අලුතින් එකතු කළ කොටස: රිජෙක්ට් වුණාම එන නොටිෆිකේශන් එක
                                                                val title =
                                                                    if (isSin) "රැකියාව ප්‍රතික්ෂේප විය ❌" else "Job Rejected ❌"
                                                                val msg =
                                                                    if (isSin) "සාත්තු සේවකයා ඔබගේ ඉල්ලීම ප්‍රතික්ෂේප කර ඇත." else "The caregiver has rejected your request."
                                                                sendNotification(title, msg)
                                                            }
                                                        } else if (userRole == "CAREGIVER" && booking.caregiverId == userId) {
                                                            if (booking.status == "COMPLETED") {
                                                                val title =
                                                                    if (isSin) "මුදල් ලැබුණා! 💰" else "Payment Received! 💰"
                                                                val msg =
                                                                    if (isSin) "රැකියාව අවසන් විය. ඔබගේ ගිණුමට මුදල් එකතු කර ඇත." else "The job has ended. Earnings have been added to your wallet."
                                                                sendNotification(title, msg)
                                                            }
                                                        }
                                                    }
                                                }

                                                if (userRole == "CLIENT") {
                                                    val activeBooking =
                                                        snapshot.documents.mapNotNull {
                                                            it.toObject(Booking::class.java)
                                                        }
                                                            .find { it.status == "IN_PROGRESS" && it.clientId == userId }

                                                    if (activeBooking != null && activeBooking.caregiverId != null) {
                                                        activeCaregiverListener?.remove()
                                                        activeCaregiverListener =
                                                            firestore.collection("users")
                                                                .document(activeBooking.caregiverId!!)
                                                                .addSnapshotListener { cgSnap, _ ->
                                                                    val lat =
                                                                        cgSnap?.getDouble("locationLat")
                                                                            ?: 0.0
                                                                    val lng =
                                                                        cgSnap?.getDouble("locationLng")
                                                                            ?: 0.0
                                                                    if (lat != 0.0 && lng != 0.0) {
                                                                        val results = FloatArray(1)
                                                                        Location.distanceBetween(
                                                                            activeBooking.locationLat,
                                                                            activeBooking.locationLng,
                                                                            lat,
                                                                            lng,
                                                                            results
                                                                        )
                                                                        val distance = results[0]

                                                                        if (distance > 50f) {
                                                                            val now =
                                                                                System.currentTimeMillis()
                                                                            if (now - lastGeofenceAlertTime > 5 * 60 * 1000) {
                                                                                val isSin =
                                                                                    sharedPreferences.getBoolean(
                                                                                        "is_sinhala",
                                                                                        false
                                                                                    )
                                                                                val title =
                                                                                    if (isSin) "අවධානයට! 🚨" else "Caregiver Alert 🚨"
                                                                                val msg =
                                                                                    if (isSin) "ඔබගේ සේවකයා රෝගියා සිටින ස්ථානයෙන් මීටර් 50 කට වඩා ඈතට ගොස් ඇත!" else "The caregiver has moved more than 50 meters away from the patient's location!"
                                                                                sendNotification(
                                                                                    title,
                                                                                    msg
                                                                                )
                                                                                lastGeofenceAlertTime =
                                                                                    now
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                    } else {
                                                        activeCaregiverListener?.remove()
                                                    }
                                                }
                                            }
                                        }
                                }
                        } else {
                            isListenerInitialized = false
                            activeCaregiverListener?.remove()
                            userRole = "CLIENT"
                            userHasActiveJob = false
                            stopService(
                                Intent(
                                    this@MainActivity,
                                    LocationTrackingService::class.java
                                )
                            )
                        }
                    }
                }

                CompositionLocalProvider(LocalIsSinhala provides isSinhala) {
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = MaterialTheme.colorScheme.background
                    ) {
                        androidx.compose.foundation.layout.Box(modifier = Modifier.fillMaxSize()) {
                            AppNavigation(
                                onShowNotification = { title, message ->
                                    sendNotification(title, message)
                                }
                            )
                            if (!isConnected) {
                                NoInternetScreen(
                                    onRetry = {
                                        networkMonitor.checkConnectionManually()
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        networkMonitor.cleanup()
    }

    private fun sendNotification(title: String, message: String) {
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.baseline_notifications_active_24)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(System.currentTimeMillis().toInt(), builder.build())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Golden Hand Updates"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}