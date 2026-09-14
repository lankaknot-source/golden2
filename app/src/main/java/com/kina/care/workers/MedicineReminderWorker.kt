package com.kina.care.workers

import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.R
import com.kina.care.domain.model.Booking
import com.kina.care.domain.model.ElderProfile
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MedicineReminderWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        val auth = FirebaseAuth.getInstance()
        val firestore = FirebaseFirestore.getInstance()
        val userId = auth.currentUser?.uid ?: return Result.success()

        try {
            val userDoc = firestore.collection("users").document(userId).get().await()
            val role = userDoc.getString("role") ?: "CLIENT"

            val eldersToCheck = mutableListOf<ElderProfile>()

            if (role == "CLIENT") {
                val elders = firestore.collection("elder_profiles")
                    .whereEqualTo("clientId", userId).get().await()
                    .documents.mapNotNull { it.toObject(ElderProfile::class.java) }
                eldersToCheck.addAll(elders)
            } else {
                val activeBookings = firestore.collection("bookings")
                    .whereEqualTo("caregiverId", userId)
                    .whereEqualTo("status", "IN_PROGRESS")
                    .get().await()
                    .documents.mapNotNull { it.toObject(Booking::class.java) }

                for (booking in activeBookings) {
                    val elderDoc = firestore.collection("elder_profiles").document(booking.elderId).get().await()
                    val elder = elderDoc.toObject(ElderProfile::class.java)
                    if (elder != null) {
                        eldersToCheck.add(elder)
                    }
                }
            }

            val currentTimeStr = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
            
            for (elder in eldersToCheck) {
                for (reminder in elder.medicineList) {
                    // Check if time matches (e.g. "08:00" matches "08:00")
                    // A proper implementation might check within a 15-min window
                    if (reminder.time == currentTimeStr || isWithin15Minutes(reminder.time, currentTimeStr)) {
                        sendNotification("Medicine Reminder", "It's time to give ${reminder.name} to ${elder.name}!")
                    }
                }
            }

            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }

    private fun isWithin15Minutes(targetTime: String, currentTime: String): Boolean {
        try {
            val format = SimpleDateFormat("HH:mm", Locale.getDefault())
            val target = format.parse(targetTime)?.time ?: 0L
            val current = format.parse(currentTime)?.time ?: 0L
            val diff = Math.abs(target - current)
            return diff <= 15 * 60 * 1000
        } catch (e: Exception) {
            return false
        }
    }

    private fun sendNotification(title: String, message: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = NotificationCompat.Builder(context, "golden_hand_notifications")
            .setSmallIcon(R.drawable.baseline_notifications_active_24)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        manager.notify(System.currentTimeMillis().toInt(), builder.build())
    }
}
