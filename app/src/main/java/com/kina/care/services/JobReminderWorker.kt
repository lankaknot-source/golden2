package com.kina.care.services

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.kina.care.R

class JobReminderWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {

        // 🌟 භාෂාව ලබා ගැනීම
        val sharedPreferences = context.getSharedPreferences("KinaCarePrefs", Context.MODE_PRIVATE)
        val isSinhala = sharedPreferences.getBoolean("is_sinhala", false)

        // Input Data වලින් එන පණිවිඩය, නැත්නම් Default පණිවිඩය (භාෂාව අනුව)
        var title = inputData.getString("title") ?: "Golden Hand Caregivers"
        var message = inputData.getString("message") ?: "You have a scheduled job soon!"

        val type = inputData.getString("type") ?: ""

        // පණිවිඩය වර්ගය අනුව භාෂාවෙන් හැදීම
        if (type == "tomorrow") {
            title = if(isSinhala) "සිහිකැඳවීමයි! ⏰" else "Upcoming Job Reminder ⏰"
            message = if(isSinhala) "හෙට දිනට වෙන්කළ රැකියාවක් ඇත. සූදානම් වන්න." else "You have a scheduled job tomorrow. Be prepared."
        } else if (type == "today") {
            title = if(isSinhala) "අද දින රැකියාවක් ඇත! 📅" else "Today is your Job! 📅"
            message = if(isSinhala) "අද දින ඔබ භාරගත් රැකියාව ආරම්භ කිරීමට නියමිතයි. ප්‍රමාද නොවන්න!" else "You have a job starting today. Don't be late!"
        }

        sendNotification(title, message)

        return Result.success()
    }

    private fun sendNotification(title: String, message: String) {
        val channelId = "scheduled_jobs_channel"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Job Reminders", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.baseline_notifications_active_24)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }
}