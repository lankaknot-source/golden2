package com.kina.care.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.R
import com.kina.care.domain.model.Booking
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.UUID

class LocationTrackingService : Service() {

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()
    private val coroutineScope = CoroutineScope(Dispatchers.IO)

    // Notification එකක් පෙන්වීමට අවශ්‍ය නාලිකාව (Channel)
    private val NOTIFICATION_CHANNEL_ID = "location_tracking_channel"
    private val NOTIFICATION_ID = 1

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                locationResult.lastLocation?.let { location ->
                    updateLocationInFirebase(location.latitude, location.longitude)
                    // මීටර් 50ක දුර පරීක්ෂා කිරීම (Geofence Check)
                    checkGeofenceAlert(location.latitude, location.longitude)
                }
            }
        }
    }

    private fun checkGeofenceAlert(currentLat: Double, currentLng: Double) {
        val userId = auth.currentUser?.uid ?: return
        coroutineScope.launch {
            try {
                // Caregiver කෙනෙක් නම්, ඔහු කරන IN_PROGRESS ජොබ් එකක් තියෙනවාදැයි බැලීම
                val snapshot = firestore.collection("bookings")
                    .whereEqualTo("caregiverId", userId)
                    .whereEqualTo("status", "IN_PROGRESS")
                    .get().await()

                if (!snapshot.isEmpty) {
                    val booking = snapshot.documents[0].toObject(Booking::class.java)
                    if (booking != null && booking.locationLat != 0.0) {
                        // දුර ගණනය කිරීම
                        val results = FloatArray(1)
                        Location.distanceBetween(
                            currentLat, currentLng,
                            booking.locationLat, booking.locationLng,
                            results
                        )
                        val distanceInMeters = results[0]

                        // මීටර් 50 ට වඩා වැඩි නම් Alert එකක් Firebase එකට දැමීම
                        if (distanceInMeters > 50) {
                            val alertId = UUID.randomUUID().toString()

                            // Compiler Error එක මග හැරීමට <String, Any> ලබා දී ඇත
                            val alert = hashMapOf<String, Any>(
                                "id" to alertId,
                                "bookingId" to booking.id,
                                "message" to "Caregiver සේවා ස්ථානයෙන් මීටර් 50 කට වඩා ඈතට ගොස් ඇත! (දුර: ${distanceInMeters.toInt()}m)",
                                "timestamp" to System.currentTimeMillis()
                            )
                            firestore.collection("alerts").document(alertId).set(alert).await()
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Service එක පටන් ගත්තම Notification එකක් එක්ක Foreground යවනවා (ඇප් එක වැහුවත් වැඩ කරන්න)
        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Tracking")
            .setContentText("We are tracking you...")
            .setSmallIcon(R.drawable.baseline_notifications_active_24)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        startLocationUpdates()

        return START_STICKY
    }

    private fun startLocationUpdates() {
        // හැම තත්පර 10 කට වරක්ම Location එක ඉල්ලනවා
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 10000)
            .setMinUpdateIntervalMillis(5000)
            .build()

        try {
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun updateLocationInFirebase(lat: Double, lng: Double) {
        val userId = auth.currentUser?.uid ?: return

        coroutineScope.launch {
            try {
                val updates = hashMapOf<String, Any>(
                    "locationLat" to lat,
                    "locationLng" to lng
                )
                firestore.collection("users").document(userId).update(updates).await()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        fusedLocationClient.removeLocationUpdates(locationCallback)
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null // අපි බයින්ඩ් කරන්නේ නෑ
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Location Tracking Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}