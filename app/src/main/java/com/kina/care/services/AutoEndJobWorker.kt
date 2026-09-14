package com.kina.care.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.R
import kotlinx.coroutines.tasks.await

class AutoEndJobWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        val bookingId = inputData.getString("bookingId") ?: return Result.failure()
        val firestore = FirebaseFirestore.getInstance()

        try {
            // ජොබ් එක COMPLETED බවට පත් කිරීම
            firestore.collection("bookings").document(bookingId).update("status", "COMPLETED").await()

            // 🌟 භාෂාව ලබා ගැනීම
            val sharedPreferences = context.getSharedPreferences("KinaCarePrefs", Context.MODE_PRIVATE)
            val isSinhala = sharedPreferences.getBoolean("is_sinhala", false)

            val title = if(isSinhala) "රැකියාව අවසන් විය! 🎉" else "Job Completed! 🎉"
            val msg = if(isSinhala) "ඔබගේ රැකියාව සඳහා වෙන් කළ කාලය අවසන් වී ඇත. කරුණාකර ගෙවීම් කටයුතු සිදු කරන්න." else "The scheduled time for your job has ended. Please proceed to payment and reviews."

            // Notifications යැවීම
            sendNotification(title, msg)

            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }

    private fun sendNotification(title: String, message: String) {
        val channelId = "job_status_channel"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Job Status", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}