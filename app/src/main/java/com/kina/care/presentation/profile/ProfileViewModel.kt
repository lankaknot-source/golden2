package com.kina.care.presentation.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.LeaveRequest
import com.kina.care.domain.model.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class ProfileUiState(
    val isLoading: Boolean = true,
    val userData: User? = null,
    val errorMessage: String? = null,
    val isSaving: Boolean = false,
    val isSaveSuccess: Boolean = false,
    val registrationFee: Double = 1000.0
)

class ProfileViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()
    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        fetchUserProfile()
        fetchSystemSettings()
    }

    private fun fetchUserProfile() {
        val userId = auth.currentUser?.uid ?: return
        firestore.collection("users").document(userId)
            .addSnapshotListener { snapshot, _ ->
                if (snapshot != null && snapshot.exists()) {
                    val user = snapshot.toObject(User::class.java)
                    _uiState.value = _uiState.value.copy(isLoading = false, userData = user)

                    // 🌟 Fix: CAREGIVER/NURSE ලට Admin KYC approve කළ සැනිකිනිම isVerified = true set කිරීම
                    // CLIENT ලා registration fee ගෙව්වාට පස්සෙ payRegistrationFee() function එකෙ isVerified = true වෙනවා
                    val isCaregiverRole = user?.role == "CAREGIVER" || user?.role == "NURSE"
                    if (user != null && isCaregiverRole && user.kycStatus == "APPROVED" && !user.isVerified) {
                        firestore.collection("users").document(userId)
                            .update("isVerified", true)
                    }
                }
            }
    }

    private fun fetchSystemSettings() {
        firestore.collection("settings").document("general")
            .addSnapshotListener { snapshot, _ ->
                if (snapshot != null && snapshot.exists()) {
                    val fee = snapshot.getDouble("registrationFee") ?: 1000.0
                    _uiState.value = _uiState.value.copy(registrationFee = fee)
                }
            }
    }

    fun requestLeave(dateMs: Long, reason: String, onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                val userId = auth.currentUser?.uid ?: return@launch
                val userName = _uiState.value.userData?.name ?: "Caregiver"
                val dateStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date(dateMs))

                val leaveId = java.util.UUID.randomUUID().toString()
                val leaveReq = LeaveRequest(
                    id = leaveId,
                    caregiverId = userId,
                    caregiverName = userName,
                    dateMs = dateMs,
                    dateString = dateStr,
                    reason = reason,
                    status = "PENDING",
                    requestedAt = System.currentTimeMillis()
                )

                firestore.collection("leave_requests").document(leaveId).set(leaveReq).await()
                onResult(true, "නිවාඩු ඉල්ලීම යවන ලදී. Admin අනුමැතිය ලැබෙන තෙක් රැඳී සිටින්න.")
            } catch (e: Exception) {
                onResult(false, e.message ?: "දෝෂයකි")
            }
        }
    }

    fun payRegistrationFee(onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                val userId = auth.currentUser?.uid ?: return@launch
                val currentFee = _uiState.value.registrationFee

                firestore.collection("users").document(userId).update("isVerified", true).await()

                val txId = java.util.UUID.randomUUID().toString()
                val tx = hashMapOf(
                    "id" to txId,
                    "userId" to userId,
                    "amount" to currentFee,
                    "type" to "FEE",
                    "description" to "Client Registration Fee",
                    "timestamp" to System.currentTimeMillis()
                )
                firestore.collection("transactions").document(txId).set(tx).await()

                onResult(true, "ගෙවීම සාර්ථකයි! ඔබගේ ගිණුම සම්පූර්ණයෙන්ම සක්‍රීය විය.")
            } catch (e: Exception) {
                onResult(false, e.localizedMessage ?: "දෝෂයකි. නැවත උත්සාහ කරන්න.")
            }
        }
    }

    fun updateProfileFull(name: String, phone: String, hourlyRate: Double, profileImage: String) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isSaving = true, isSaveSuccess = false)
            try {
                val userId = auth.currentUser?.uid ?: return@launch
                val updates = hashMapOf<String, Any>(
                    "name" to name,
                    "phone" to phone,
                    "hourlyRate" to hourlyRate,
                    "profileImageUrl" to profileImage
                )
                firestore.collection("users").document(userId).update(updates).await()
                _uiState.value = _uiState.value.copy(isSaving = false, isSaveSuccess = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isSaving = false, errorMessage = e.localizedMessage)
            }
        }
    }

    fun resetSaveSuccess() { _uiState.value = _uiState.value.copy(isSaveSuccess = false) }
}