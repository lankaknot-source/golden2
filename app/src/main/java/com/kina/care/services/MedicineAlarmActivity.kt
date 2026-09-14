package com.kina.care.services

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

class MedicineAlarmActivity : ComponentActivity() {

    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // දුරකථනය ලොක් වී තිබුණත් Screen එක පත්තු කරගෙන (Wake Up) Popup එක පෙන්වීමට අවසර දීම
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        // භාෂාව ලබාගැනීම
        val sharedPrefs = getSharedPreferences("KinaCarePrefs", Context.MODE_PRIVATE)
        val isSinhala = sharedPrefs.getBoolean("is_sinhala", false)

        val medName = intent.getStringExtra("medName") ?: "Medicine"
        val photoBase64 = intent.getStringExtra("photoBase64") ?: ""

        // Alarm එක නාද කිරීම
        try {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            mediaPlayer = MediaPlayer.create(this, alarmUri)
            mediaPlayer?.isLooping = true
            mediaPlayer?.start()
        } catch (e: Exception) { e.printStackTrace() }

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f)),
                    color = Color.Transparent
                ) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Card(
                            modifier = Modifier.padding(24.dp).fillMaxWidth(),
                            shape = RoundedCornerShape(24.dp),
                            colors = CardDefaults.cardColors(containerColor = Color.White),
                            elevation = CardDefaults.cardElevation(12.dp)
                        ) {
                            Column(
                                modifier = Modifier.padding(24.dp),
                                horizontalAlignment = Alignment.CenterHorizontally
                            ) {
                                Text(
                                    if(isSinhala) "බෙහෙත් වේලාවයි! ⏰" else "Medicine Time! ⏰",
                                    fontSize = 26.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFFEF4444)
                                )
                                Spacer(modifier = Modifier.height(16.dp))

                                // බෙහෙතේ ෆොටෝ එක පෙන්වීම
                                if (photoBase64.isNotEmpty()) {
                                    val bitmap = convertBase64(photoBase64)
                                    if (bitmap != null) {
                                        Image(
                                            bitmap = bitmap.asImageBitmap(),
                                            contentDescription = "Medicine",
                                            modifier = Modifier.size(200.dp).clip(RoundedCornerShape(16.dp)),
                                            contentScale = ContentScale.Crop
                                        )
                                    }
                                }

                                Spacer(modifier = Modifier.height(20.dp))
                                Text(
                                    if(isSinhala) "රෝගියාට පහත ඖෂධය ලබා දෙන්න:" else "Please give the following medicine:",
                                    fontSize = 16.sp, color = Color.Gray, textAlign = TextAlign.Center
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(medName, fontSize = 32.sp, fontWeight = FontWeight.Black, color = Color(0xFF0D3B66), textAlign = TextAlign.Center)

                                Spacer(modifier = Modifier.height(32.dp))
                                Button(
                                    onClick = { finish() }, // මෙය එබූ විට Alarm එක නවතී
                                    modifier = Modifier.fillMaxWidth().height(60.dp),
                                    shape = RoundedCornerShape(16.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981))
                                ) {
                                    Text(if(isSinhala) "ලබා දුන්නා (Dismiss)" else "Given (Dismiss)", fontSize = 18.sp, fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Activity එක Close වෙද්දි Alarm සද්දෙත් නවතිනවා
        mediaPlayer?.stop()
        mediaPlayer?.release()
    }

    private fun convertBase64(base64Str: String): Bitmap? {
        return try {
            val pureBase64 = base64Str.substringAfter("base64,")
            val decodedBytes = Base64.decode(pureBase64, Base64.DEFAULT)
            BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)
        } catch (e: Exception) { null }
    }
}