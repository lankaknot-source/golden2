package com.kina.care.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MedicineAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {

        // Alarm එක නාද වූ විට කෙලින්ම Popup Activity එක On කරනවා. (දුරකථනය ලොක් වී තිබුනත් මෙය ක්‍රියාත්මක වේ).
        val alarmIntent = Intent(context, MedicineAlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("medName", intent.getStringExtra("medName"))
            putExtra("photoBase64", intent.getStringExtra("photoBase64"))
        }

        context.startActivity(alarmIntent)
    }
}