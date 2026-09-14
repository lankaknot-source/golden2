package com.kina.care

import android.app.Application
import android.util.Log
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.messaging.FirebaseMessaging
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

class CareApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // 🌟 Enable Firestore Offline Persistence
        val settings = com.google.firebase.firestore.firestoreSettings {
            isPersistenceEnabled = true
        }
        FirebaseFirestore.getInstance().firestoreSettings = settings

        // App එක ආරම්භ වන විට FCM Token එක ලබාගෙන Database එකේ සේව් කිරීම
        getAndSaveFCMToken()
    }

    private fun getAndSaveFCMToken() {
        // Coroutine එකක් ඇතුළට ගැනීමෙන් await() භාවිතා කළ හැක
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // 🌟 Fix: addOnCompleteListener වෙනුවට await() භාවිතා කිරීම
                val token = FirebaseMessaging.getInstance().token.await()
                Log.d("CareApplication", "FCM Token: $token")

                // යූසර් ලොග් වෙලා ඉන්නවා නම් Firestore එකේ සේව් කරන්න
                val userId = FirebaseAuth.getInstance().currentUser?.uid
                if (userId != null) {
                    FirebaseFirestore.getInstance().collection("users").document(userId)
                        .update("fcmToken", token).await()
                }
            } catch (e: Exception) {
                Log.w("CareApplication", "Fetching FCM registration token failed", e)
            }
        }
    }
}