package com.kina.care.presentation.client

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.Booking
import com.kina.care.domain.model.ElderProfile
import com.kina.care.domain.model.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.UUID

data class CreateJobUiState(
    val isLoading: Boolean = false,
    val isSuccess: Boolean = false,
    val errorMessage: String? = null,
    val elders: List<ElderProfile> = emptyList(),
    val selectedCaregiverRate: Double = 0.0 // 🌟 අලුත්: Caregiver ගේ ගාස්තුව පෙන්වීමට
)

class CreateJobViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _uiState = MutableStateFlow(CreateJobUiState())
    val uiState: StateFlow<CreateJobUiState> = _uiState.asStateFlow()

    init { fetchElders() }

    private fun fetchElders() {
        val userId = auth.currentUser?.uid ?: return
        firestore.collection("elders")
            .whereEqualTo("clientId", userId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) return@addSnapshotListener
                if (snapshot != null) {
                    val eldersList = snapshot.documents.mapNotNull { it.toObject(ElderProfile::class.java) }
                    _uiState.value = _uiState.value.copy(elders = eldersList)
                }
            }
    }

    // 🌟 අලුත්: තෝරාගත් Caregiver ගේ පැයක ගාස්තුව ලබා ගැනීම
    fun fetchCaregiverRate(caregiverId: String?) {
        if (caregiverId == null) return
        viewModelScope.launch {
            try {
                val doc = firestore.collection("users").document(caregiverId).get().await()
                if (doc.exists()) {
                    val user = doc.toObject(User::class.java)
                    val rate = user?.hourlyRate ?: 0.0
                    _uiState.value = _uiState.value.copy(selectedCaregiverRate = rate)
                }
            } catch (e: Exception) {
                // Ignore error, fallback to 0.0
            }
        }
    }

    fun createJobRequest(
        lat: Double, lng: Double, description: String, isEmergency: Boolean,
        elderId: String, selectedCaregiverId: String? = null, scheduledTimeMs: Long = 0L,
        careCategory: String, serviceType: String, durationType: String,
        requestedTasks: List<String>, estimatedHours: Int // 🌟 අලුත්: පැය ගණන ලබා ගැනීම
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val clientId = auth.currentUser?.uid ?: return@launch
                val jobId = UUID.randomUUID().toString()

                // මුදල ගණනය කිරීම (පැය ගණන * පැයක ගාස්තුව)
                val totalAmount = estimatedHours * _uiState.value.selectedCaregiverRate

                val newBooking = Booking(
                    id = jobId,
                    clientId = clientId,
                    caregiverId = selectedCaregiverId,
                    elderId = elderId,
                    status = if (selectedCaregiverId != null) "PENDING" else "BROADCASTED",
                    locationLat = lat,
                    locationLng = lng,
                    jobDescription = description,
                    isEmergency = isEmergency,
                    requestedTime = System.currentTimeMillis(),
                    scheduledTime = scheduledTimeMs,
                    careCategory = careCategory,
                    serviceType = serviceType,
                    durationType = durationType,
                    requestedTasks = requestedTasks,
                    estimatedHours = estimatedHours, // 🌟 Save the hours
                    hourlyRate = _uiState.value.selectedCaregiverRate,
                    totalAmount = totalAmount // 🌟 Save the calculated total amount
                )

                firestore.collection("bookings").document(jobId).set(newBooking).await()
                _uiState.value = _uiState.value.copy(isLoading = false, isSuccess = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = e.localizedMessage)
            }
        }
    }
}