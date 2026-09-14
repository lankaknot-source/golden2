package com.kina.care.presentation.profile

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import kotlin.math.min
import kotlin.math.roundToInt

data class KycState(
    val currentStep: Int = 1,
    val isUploading: Boolean = false,
    val uploadSuccess: Boolean = false,
    val errorMessage: String? = null
)

class CaregiverKycViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _uiState = MutableStateFlow(KycState())
    val uiState: StateFlow<KycState> = _uiState.asStateFlow()

    fun setStep(step: Int) {
        _uiState.value = _uiState.value.copy(currentStep = step)
    }

    fun submitKycData(
        context: Context,
        nicNumber: String, dob: String, gender: String, address: String,
        experience: String, skills: String, vaccination: String, illnesses: String,
        bankName: String, accNo: String, branch: String, salary: Double, serviceTypes: List<String>,
        nicFrontUri: Uri?, nicBackUri: Uri?, selfieUri: Uri?,
        policeUri: Uri?, certUri: Uri?, bankBookUri: Uri?
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isUploading = true, errorMessage = null)
            try {
                val userId = auth.currentUser?.uid ?: throw Exception("User not logged in")

                val nicFrontBase64 = compressImage(context, nicFrontUri)
                val nicBackBase64 = compressImage(context, nicBackUri)
                val selfieBase64 = compressImage(context, selfieUri)
                val policeBase64 = compressImage(context, policeUri)
                val certBase64 = compressImage(context, certUri)
                val bankBookBase64 = compressImage(context, bankBookUri)

                val updates = mapOf(
                    "kycStatus" to "PENDING",
                    "nicNumber" to nicNumber,
                    "dob" to dob,
                    "gender" to gender,
                    "address" to address,
                    "experienceYears" to experience,
                    "specialSkills" to skills,
                    "vaccinationStatus" to vaccination,
                    "chronicIllnesses" to illnesses,
                    "bankName" to bankName,
                    "bankAccountNumber" to accNo,
                    "bankBranch" to branch,

                    // 🌟 අලුත්: Expected Salary එක Hourly Rate එකටත් සේව් කිරීම
                    "expectedSalary" to salary,
                    "hourlyRate" to salary,

                    "preferredServiceTypes" to serviceTypes,
                    "nicFrontUrl" to (nicFrontBase64 ?: ""),
                    "nicBackUrl" to (nicBackBase64 ?: ""),

                    // 🌟 අලුත්: Selfie පින්තූරය Profile Pic එක ලෙස සේව් වීම
                    "selfieUrl" to (selfieBase64 ?: ""),
                    "profileImageUrl" to (selfieBase64 ?: ""),

                    "policeClearanceUrl" to (policeBase64 ?: ""),
                    "certificateUrl" to (certBase64 ?: ""),
                    "bankBookUrl" to (bankBookBase64 ?: "")
                )

                firestore.collection("users").document(userId).update(updates).await()
                _uiState.value = _uiState.value.copy(isUploading = false, uploadSuccess = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isUploading = false, errorMessage = e.localizedMessage)
            }
        }
    }

    private suspend fun compressImage(context: Context, uri: Uri?): String? {
        if (uri == null) return null
        return withContext(Dispatchers.IO) {
            try {
                val inputStream = context.contentResolver.openInputStream(uri)
                val originalBitmap = BitmapFactory.decodeStream(inputStream) ?: return@withContext null

                val scale = min(400f / originalBitmap.width, 400f / originalBitmap.height)
                val scaledBitmap = if (scale < 1f) {
                    Bitmap.createScaledBitmap(originalBitmap, (originalBitmap.width * scale).roundToInt(), (originalBitmap.height * scale).roundToInt(), true)
                } else {
                    originalBitmap
                }

                val outputStream = ByteArrayOutputStream()
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 50, outputStream)
                "data:image/jpeg;base64,${Base64.encodeToString(outputStream.toByteArray(), Base64.DEFAULT)}"
            } catch (e: Exception) {
                null
            }
        }
    }
}