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

data class ClientKycState(
    val isUploading: Boolean = false,
    val uploadSuccess: Boolean = false,
    val errorMessage: String? = null
)

class ClientKycViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _uiState = MutableStateFlow(ClientKycState())
    val uiState: StateFlow<ClientKycState> = _uiState.asStateFlow()

    fun submitClientKyc(
        context: Context,
        nicNumber: String,
        dob: String, // 🌟 අලුත්: උපන්දිනය ලබා ගැනීම
        homeAddress: String,
        serviceAddress: String,
        billingName: String,
        billingAddress: String,
        nicFrontUri: Uri?,
        nicBackUri: Uri?,
        selfieUri: Uri?
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isUploading = true, errorMessage = null)
            try {
                val userId = auth.currentUser?.uid ?: throw Exception("User not logged in")

                // පින්තූර Compress කර Base64 බවට පත් කිරීම
                val nicFrontBase64 = compressImage(context, nicFrontUri)
                val nicBackBase64 = compressImage(context, nicBackUri)
                val selfieBase64 = compressImage(context, selfieUri)

                val updates = mapOf(
                    "kycStatus" to "PENDING",
                    "nicNumber" to nicNumber,
                    "dob" to dob, // 🌟 අලුත්: උපන්දිනය Firestore එකට යැවීම
                    "address" to homeAddress,
                    "serviceAddress" to serviceAddress.ifEmpty { homeAddress },
                    "billingName" to billingName,
                    "billingAddress" to billingAddress,
                    "nicFrontUrl" to (nicFrontBase64 ?: ""),
                    "nicBackUrl" to (nicBackBase64 ?: ""),
                    "selfieUrl" to (selfieBase64 ?: "")
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
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 60, outputStream)
                "data:image/jpeg;base64,${Base64.encodeToString(outputStream.toByteArray(), Base64.DEFAULT)}"
            } catch (e: Exception) {
                null
            }
        }
    }
}