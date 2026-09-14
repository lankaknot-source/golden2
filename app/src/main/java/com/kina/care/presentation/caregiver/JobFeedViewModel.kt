package com.kina.care.presentation.caregiver

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.Booking
import com.kina.care.services.JobReminderWorker
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.Calendar
import java.util.concurrent.TimeUnit

data class JobFeedUiState(
    val isLoading: Boolean = true,
    val jobs: List<Booking> = emptyList(),
    val errorMessage: String? = null
)

class JobFeedViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _uiState = MutableStateFlow(JobFeedUiState())
    val uiState: StateFlow<JobFeedUiState> = _uiState.asStateFlow()

    init { fetchAvailableJobs() }

    private fun fetchAvailableJobs() {
        val userId = auth.currentUser?.uid ?: return

        firestore.collection("bookings")
            .whereIn("status", listOf("BROADCASTED", "PENDING"))
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    _uiState.value = JobFeedUiState(isLoading = false, errorMessage = error.localizedMessage)
                    return@addSnapshotListener
                }

                if (snapshot != null) {
                    val jobList = snapshot.documents.mapNotNull { it.toObject(Booking::class.java)?.copy(id = it.id) }
                        .filter { !it.rejectedBy.contains(userId) }
                        .filter { it.status == "BROADCASTED" || (it.status == "PENDING" && it.caregiverId == userId) }

                        // Premium Package එකක් නම්, Admin Select කරපු අයට විතරයි පෙන්වන්නේ
                        .filter { booking ->
                            if (booking.isSubscriptionBooking && booking.allowedCaregivers.isNotEmpty()) {
                                booking.allowedCaregivers.contains(userId)
                            } else {
                                true // සාමාන්‍ය Public Job එකක්
                            }
                        }

                    val sortedList = jobList.sortedWith(compareByDescending<Booking> { it.isEmergency }.thenByDescending { it.requestedTime })
                    _uiState.value = JobFeedUiState(isLoading = false, jobs = sortedList)
                }
            }
    }

    fun rejectJob(jobId: String, onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                val userId = auth.currentUser?.uid ?: return@launch
                val bookingRef = firestore.collection("bookings").document(jobId)

                val doc = bookingRef.get().await()
                val status = doc.getString("status")
                val caregiverId = doc.getString("caregiverId")

                // 🌟 අලුත් වෙනස: Direct Request එකක් නම් කෙලින්ම Status එක REJECTED කරනවා
                if (status == "PENDING" && caregiverId == userId) {
                    bookingRef.update("status", "REJECTED").await()
                } else {
                    // Broadcast එකක් නම් මේ Caregiver ට විතරක් නොපෙනී යන්න rejectedBy එකට දානවා
                    bookingRef.update("rejectedBy", FieldValue.arrayUnion(userId)).await()
                }

                onResult(true, "රැකියාව ප්‍රතික්ෂේප කරන ලදී.")
            } catch (e: Exception) {
                onResult(false, e.localizedMessage ?: "Error rejecting job")
            }
        }
    }

    fun acceptJob(context: Context, jobId: String, onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                val caregiverId = auth.currentUser?.uid ?: return@launch
                val bookingRef = firestore.collection("bookings").document(jobId)

                val caregiverDoc = firestore.collection("users").document(caregiverId).get().await()
                val hourlyRate = caregiverDoc.getDouble("hourlyRate") ?: 0.0

                val chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                val digits = "0123456789"
                val code = "${chars.random()}${(1..4).map { digits.random() }.joinToString("")}"

                val updates = mutableMapOf<String, Any>(
                    "status" to "ACCEPTED",
                    "caregiverId" to caregiverId,
                    "startCode" to code
                )

                val currentBooking = bookingRef.get().await().toObject(Booking::class.java)
                if (currentBooking?.isSubscriptionBooking != true) {
                    updates["hourlyRate"] = hourlyRate
                }

                bookingRef.update(updates).await()

                firestore.collection("users").document(caregiverId).update("isBusy", true).await()

                if (currentBooking != null && currentBooking.scheduledTime > 0L) {
                    scheduleJobReminders(context, currentBooking.scheduledTime)
                }

                onResult(true, "රැකියාව සාර්ථකව භාර ගන්නා ලදී!")
            } catch (e: Exception) {
                onResult(false, e.localizedMessage ?: "දෝෂයකි! නැවත උත්සාහ කරන්න.")
            }
        }
    }

    private fun scheduleJobReminders(context: Context, scheduledTimeMs: Long) {
        val workManager = WorkManager.getInstance(context)
        val currentTime = System.currentTimeMillis()

        val oneDayBeforeMs = scheduledTimeMs - (24 * 60 * 60 * 1000L)
        if (oneDayBeforeMs > currentTime) {
            val delay = oneDayBeforeMs - currentTime
            val req1 = OneTimeWorkRequestBuilder<JobReminderWorker>()
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                .setInputData(workDataOf("title" to "Upcoming Job Reminder \u23F0", "message" to "හෙට දිනට වෙන්කළ රැකියාවක් ඇත. සූදානම් වන්න.", "type" to "tomorrow"))
                .build()
            workManager.enqueue(req1)
        }

        val cal = Calendar.getInstance().apply { timeInMillis = scheduledTimeMs }
        cal.set(Calendar.HOUR_OF_DAY, 6)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        val morningOfMs = cal.timeInMillis

        if (morningOfMs > currentTime && morningOfMs < scheduledTimeMs) {
            val delay = morningOfMs - currentTime
            val req2 = OneTimeWorkRequestBuilder<JobReminderWorker>()
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                .setInputData(workDataOf("title" to "Today is your Job! \uD83D\uDCC5", "message" to "අද දින ඔබ භාරගත් රැකියාව ආරම්භ කිරීමට නියමිතයි. ප්‍රමාද නොවන්න!", "type" to "today"))
                .build()
            workManager.enqueue(req2)
        }
    }
}