package com.kina.care.presentation.client

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.ElderProfile
import com.kina.care.domain.model.MedicineReminder
import com.kina.care.services.MedicineAlarmReceiver
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Calendar
import java.util.TimeZone
import java.util.UUID
import kotlin.math.min
import kotlin.math.roundToInt

data class ElderProfileUiState(
    val isLoading: Boolean = true,
    val elders: List<ElderProfile> = emptyList(),
    val errorMessage: String? = null,
    val isSaving: Boolean = false
)

class ElderProfileViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _uiState = MutableStateFlow(ElderProfileUiState())
    val uiState: StateFlow<ElderProfileUiState> = _uiState.asStateFlow()

    init { fetchElders() }

    private fun fetchElders() {
        val userId = auth.currentUser?.uid ?: return
        firestore.collection("elders")
            .whereEqualTo("clientId", userId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = error.localizedMessage)
                    return@addSnapshotListener
                }
                if (snapshot != null) {
                    val eldersList = snapshot.documents.mapNotNull { it.toObject(ElderProfile::class.java) }
                    _uiState.value = _uiState.value.copy(isLoading = false, elders = eldersList)
                }
            }
    }

    fun addElder(name: String, age: String, gender: String, conditions: String, contact: String, language: String, onComplete: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSaving = true)
            try {
                val clientId = auth.currentUser?.uid ?: return@launch
                val id = UUID.randomUUID().toString()

                val conditionList = conditions.split(",").map { it.trim() }.filter { it.isNotEmpty() }
                val ageInt = age.toIntOrNull() ?: 0

                val elder = ElderProfile(
                    id = id, clientId = clientId, name = name, age = ageInt, gender = gender,
                    medicalConditions = conditionList, emergencyContact = contact, requiredLanguage = language,
                    medicineList = emptyList()
                )

                firestore.collection("elders").document(id).set(elder).await()
                _uiState.value = _uiState.value.copy(isSaving = false)
                onComplete(true, "සාර්ථකව එකතු කරන ලදී!")
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isSaving = false, errorMessage = e.localizedMessage)
                onComplete(false, e.localizedMessage ?: "දෝෂයකි")
            }
        }
    }

    fun deleteElder(id: String) {
        viewModelScope.launch { try { firestore.collection("elders").document(id).delete().await() } catch(e: Exception) {} }
    }

    private suspend fun getInternetTimeMs(): Long {
        return withContext(Dispatchers.IO) {
            try {
                val url = URL("https://worldtimeapi.org/api/timezone/Asia/Colombo")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 3000
                connection.readTimeout = 3000
                val reader = connection.inputStream.bufferedReader()
                val response = reader.readText()
                val regex = """"unixtime":\s*(\d+)""".toRegex()
                val match = regex.find(response)
                if (match != null) {
                    match.groupValues[1].toLong() * 1000L
                } else {
                    System.currentTimeMillis()
                }
            } catch (e: Exception) {
                System.currentTimeMillis()
            }
        }
    }

    fun addMedicineReminderWithPhoto(context: Context, elderId: String, currentList: List<MedicineReminder>, timeStr: String, medName: String, photoUri: Uri?, onResult: (Boolean) -> Unit) {
        if (timeStr.isBlank() || medName.isBlank()) return

        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSaving = true)
            try {
                var base64Photo = ""
                if (photoUri != null) {
                    base64Photo = compressImage(context, photoUri) ?: ""
                }

                val medId = UUID.randomUUID().toString()
                val newMed = MedicineReminder(id = medId, time = timeStr, name = medName, photoBase64 = base64Photo)
                val updatedList = currentList + newMed

                firestore.collection("elders").document(elderId).update("medicineList", updatedList).await()

                val internetTimeMs = getInternetTimeMs()
                val calendar = Calendar.getInstance(TimeZone.getTimeZone("Asia/Colombo"))
                calendar.timeInMillis = internetTimeMs

                val parts = timeStr.split(":")
                val targetHour = parts[0].toIntOrNull() ?: 8
                val targetMin = parts[1].toIntOrNull() ?: 0

                calendar.set(Calendar.HOUR_OF_DAY, targetHour)
                calendar.set(Calendar.MINUTE, targetMin)
                calendar.set(Calendar.SECOND, 0)

                if (calendar.timeInMillis <= internetTimeMs) {
                    calendar.add(Calendar.DAY_OF_YEAR, 1)
                }

                val timeRemainingMs = calendar.timeInMillis - internetTimeMs
                val exactTriggerTimeMs = System.currentTimeMillis() + timeRemainingMs

                scheduleAlarm(context, exactTriggerTimeMs, medId, medName, base64Photo)

                _uiState.value = _uiState.value.copy(isSaving = false)
                onResult(true)
            } catch(e: Exception) {
                _uiState.value = _uiState.value.copy(isSaving = false)
                onResult(false)
            }
        }
    }

    private fun scheduleAlarm(context: Context, triggerAtMs: Long, medId: String, medName: String, photoBase64: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, MedicineAlarmReceiver::class.java).apply {
            putExtra("medId", medId)
            putExtra("medName", medName)
            putExtra("photoBase64", photoBase64)
        }
        val pendingIntent = PendingIntent.getBroadcast(context, medId.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        try {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
        } catch (e: SecurityException) {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pendingIntent)
        }
    }

    fun removeMedicineReminder(context: Context, elderId: String, currentList: List<MedicineReminder>, reminderToRemove: MedicineReminder) {
        val updatedList = currentList - reminderToRemove
        viewModelScope.launch {
            try {
                firestore.collection("elders").document(elderId).update("medicineList", updatedList).await()

                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val intent = Intent(context, MedicineAlarmReceiver::class.java)
                val pendingIntent = PendingIntent.getBroadcast(context, reminderToRemove.id.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                alarmManager.cancel(pendingIntent)

            } catch(e: Exception) {}
        }
    }

    private suspend fun compressImage(context: Context, uri: Uri?): String? {
        if (uri == null) return null
        return withContext(Dispatchers.IO) {
            try {
                val inputStream = context.contentResolver.openInputStream(uri)
                val originalBitmap = BitmapFactory.decodeStream(inputStream) ?: return@withContext null
                val scale = min(400f / originalBitmap.width, 400f / originalBitmap.height)
                val scaledBitmap = if (scale < 1f) Bitmap.createScaledBitmap(originalBitmap, (originalBitmap.width * scale).roundToInt(), (originalBitmap.height * scale).roundToInt(), true) else originalBitmap
                val outputStream = ByteArrayOutputStream()
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 60, outputStream)
                "data:image/jpeg;base64,${Base64.encodeToString(outputStream.toByteArray(), Base64.DEFAULT)}"
            } catch (e: Exception) { null }
        }
    }
}