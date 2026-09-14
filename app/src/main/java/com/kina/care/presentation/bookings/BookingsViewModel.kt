package com.kina.care.presentation.bookings

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.location.Location
import android.net.Uri
import android.util.Base64
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.kina.care.domain.model.Booking
import com.kina.care.domain.model.TaskProof
import com.kina.care.domain.model.WalletTransaction
import com.kina.care.services.AutoEndJobWorker
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.math.min
import kotlin.math.roundToInt

data class BookingsUiState(
    val isLoading: Boolean = true,
    val bookings: List<Booking> = emptyList(),
    val errorMessage: String? = null,
    val isCaregiverAway: Boolean = false,
    val isPhotoUploading: Boolean = false
)

class BookingsViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _uiState = MutableStateFlow(BookingsUiState())
    val uiState: StateFlow<BookingsUiState> = _uiState.asStateFlow()

    private var caregiverLocationListener: ListenerRegistration? = null
    private var lastAlertSentTime = 0L

    init { fetchMyBookings() }

    private fun fetchMyBookings() {
        val userId = auth.currentUser?.uid ?: return
        firestore.collection("users").document(userId).get()
            .addOnSuccessListener { userDoc ->
                val role = userDoc.getString("role") ?: "CLIENT"

                val queryField = if (role == "CAREGIVER" || role == "NURSE") "caregiverId" else "clientId"

                firestore.collection("bookings")
                    .whereEqualTo(queryField, userId)
                    .addSnapshotListener { snapshot, error ->
                        if (error != null) return@addSnapshotListener
                        if (snapshot != null) {
                            val bookingList = snapshot.documents.mapNotNull { it.toObject(Booking::class.java) }
                                .sortedByDescending { it.requestedTime }

                            if (role == "CLIENT") {
                                val active = bookingList.find { it.status == "IN_PROGRESS" }
                                if (active != null && active.caregiverId != null) {
                                    trackCaregiverLocation(active.caregiverId!!, active.locationLat, active.locationLng, active.id)
                                } else {
                                    caregiverLocationListener?.remove()
                                    _uiState.value = _uiState.value.copy(isCaregiverAway = false)
                                }
                            }
                            _uiState.value = _uiState.value.copy(isLoading = false, bookings = bookingList)
                        }
                    }
            }
    }

    private fun trackCaregiverLocation(caregiverId: String, destLat: Double, destLng: Double, bookingId: String) {
        caregiverLocationListener?.remove()
        caregiverLocationListener = firestore.collection("users").document(caregiverId)
            .addSnapshotListener { snap, _ ->
                val lat = snap?.getDouble("locationLat") ?: 0.0
                val lng = snap?.getDouble("locationLng") ?: 0.0
                if (lat != 0.0 && lng != 0.0 && destLat != 0.0 && destLng != 0.0) {
                    val results = FloatArray(1)
                    Location.distanceBetween(destLat, destLng, lat, lng, results)
                    val distance = results[0]
                    val isAway = distance > 50f

                    _uiState.value = _uiState.value.copy(isCaregiverAway = isAway)

                    if (isAway) {
                        val now = System.currentTimeMillis()
                        if (now - lastAlertSentTime > 5 * 60 * 1000) {
                            createAdminAlert(bookingId, distance)
                            lastAlertSentTime = now
                        }
                    }
                } else {
                    _uiState.value = _uiState.value.copy(isCaregiverAway = false)
                }
            }
    }

    private fun createAdminAlert(bookingId: String, distance: Float) {
        viewModelScope.launch {
            try {
                val alertId = java.util.UUID.randomUUID().toString()
                val alert = hashMapOf<String, Any>(
                    "id" to alertId,
                    "bookingId" to bookingId,
                    "message" to "Caregiver/Nurse සේවා ස්ථානයෙන් මීටර් 50 කට වඩා ඈතට ගොස් ඇත! (දුර: ${distance.toInt()}m)",
                    "timestamp" to System.currentTimeMillis()
                )
                firestore.collection("alerts").document(alertId).set(alert).await()
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    fun requestCaregiverReplacement(bookingId: String, reason: String, onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                firestore.collection("bookings").document(bookingId).update(
                    mapOf(
                        "replacementRequested" to true,
                        "replacementReason" to reason,
                        "status" to "PENDING"
                    )
                ).await()

                val alertId = java.util.UUID.randomUUID().toString()
                val alert = hashMapOf<String, Any>(
                    "id" to alertId,
                    "bookingId" to bookingId,
                    "message" to "🔴 සේවාදායකයා Caregiver/Nurse ව මාරු කරන ලෙස ඉල්ලා සිටී! හේතුව: $reason",
                    "timestamp" to System.currentTimeMillis()
                )
                firestore.collection("alerts").document(alertId).set(alert).await()

                onResult(true, "අපගේ නියෝජිතයෙකු නව සේවකයෙකු ලබා දීම සඳහා ඔබව ඉක්මනින් අමතනු ඇත.")
            } catch (e: Exception) {
                onResult(false, "දෝෂයකි: ${e.message}")
            }
        }
    }

    fun submitComplaintResponse(bookingId: String, response: String, onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                firestore.collection("bookings").document(bookingId).update("caregiverResponse", response).await()
                onResult(true, "පිළිතුර සාර්ථකව යවන ලදී.")
            } catch (e: Exception) {
                onResult(false, "දෝෂයකි: ${e.message}")
            }
        }
    }

    fun startJob(context: Context, booking: Booking, enteredCode: String, onResult: (Boolean, String) -> Unit) {
        if (enteredCode.trim().uppercase() != booking.startCode.uppercase()) {
            onResult(false, "Invalid code!")
            return
        }
        viewModelScope.launch {
            try {
                firestore.collection("bookings").document(booking.id).update(
                    mapOf("status" to "IN_PROGRESS", "startTime" to System.currentTimeMillis())
                ).await()

                val workRequest = OneTimeWorkRequestBuilder<AutoEndJobWorker>()
                    .setInitialDelay(booking.estimatedHours.toLong(), TimeUnit.HOURS)
                    .setInputData(workDataOf("bookingId" to booking.id))
                    .build()
                WorkManager.getInstance(context).enqueue(workRequest)

                onResult(true, "Job Started.")
            } catch (e: Exception) { onResult(false, e.localizedMessage ?: "Error") }
        }
    }

    fun endJobByClientWithVerification(
        bookingId: String,
        approvedTasks: List<String>,
        hasComplaint: Boolean,
        complaintNotes: String,
        totalAmount: Double,
        onResult: (Boolean, String) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val updates = mutableMapOf<String, Any>(
                    "status" to "COMPLETED",
                    "isClientEnded" to true,
                    "endTime" to System.currentTimeMillis(),
                    "clientApprovedTasks" to approvedTasks,
                    "hasComplaint" to hasComplaint,
                    "complaintNotes" to complaintNotes,
                    "totalAmount" to totalAmount
                )
                firestore.collection("bookings").document(bookingId).update(updates).await()
                onResult(true, "Job completed successfully!")
            } catch (e: Exception) { onResult(false, "Error: ${e.message}") }
        }
    }

    fun submitManualPaymentAndUpdateWallet(
        bookingId: String,
        caregiverId: String?,
        amount: Double,
        base64Receipt: String,
        onResult: (Boolean, String) -> Unit
    ) {
        viewModelScope.launch {
            try {
                var commissionRate = 15.0
                val settingsDoc = firestore.collection("settings").document("general").get().await()
                if (settingsDoc.exists() && settingsDoc.contains("commissionRate")) {
                    commissionRate = settingsDoc.getDouble("commissionRate") ?: 15.0
                }

                val caregiverNetEarning = amount * (1.0 - (commissionRate / 100.0))

                firestore.runTransaction { transaction ->
                    val bookingRef = firestore.collection("bookings").document(bookingId)

                    var currentBal = 0.0
                    var userRef: DocumentReference? = null

                    if (caregiverId != null) {
                        userRef = firestore.collection("users").document(caregiverId)
                        val userSnap = transaction.get(userRef)
                        currentBal = userSnap.getDouble("walletBalance") ?: 0.0
                    }

                    transaction.update(bookingRef, "status", "COMPLETED")
                    transaction.update(bookingRef, "isPaid", true)
                    transaction.update(bookingRef, "receiptImageBase64", base64Receipt)
                    transaction.update(bookingRef, "endTime", System.currentTimeMillis())

                    if (userRef != null && caregiverId != null) {
                        transaction.update(userRef, "isBusy", false)
                        transaction.update(userRef, "walletBalance", currentBal + caregiverNetEarning)

                        val transactionId = UUID.randomUUID().toString()
                        val transactionRef = firestore.collection("transactions").document(transactionId)
                        val walletTx = mapOf(
                            "id" to transactionId,
                            "userId" to caregiverId,
                            "amount" to caregiverNetEarning,
                            "type" to "CREDIT",
                            "description" to "Payment for booking: $bookingId (Manual Transfer)",
                            "timestamp" to System.currentTimeMillis()
                        )
                        transaction.set(transactionRef, walletTx)
                    }
                }.await()

                onResult(true, "Payment successful and wallet updated!")
            } catch (e: Exception) {
                e.printStackTrace()
                onResult(false, "Error: ${e.message}")
            }
        }
    }

    fun confirmJobEndByCaregiver(bookingId: String, totalEarning: Double, onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                val userId = auth.currentUser?.uid ?: return@launch
                firestore.collection("bookings").document(bookingId).update("isCaregiverAcceptedEnd", true).await()
                firestore.collection("users").document(userId).update("isBusy", false).await()
                onResult(true, "Job Fully Completed.")
            } catch (e: Exception) { onResult(false, "Error: ${e.message}") }
        }
    }

    fun updateTaskWithProof(context: Context, bookingId: String, taskName: String, isChecking: Boolean, imageUri: Uri?, currentBooking: Booking) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isPhotoUploading = true)
            try {
                if (isChecking) {
                    val base64Image = compressImage(context, imageUri) ?: ""
                    val newProof = TaskProof(taskName = taskName, photoUrl = base64Image)
                    val updatedTasks = currentBooking.completedTasks + taskName
                    val updatedProofs = currentBooking.taskProofs + newProof
                    firestore.collection("bookings").document(bookingId).update(mapOf("completedTasks" to updatedTasks, "taskProofs" to updatedProofs)).await()
                } else {
                    val updatedTasks = currentBooking.completedTasks - taskName
                    val updatedProofs = currentBooking.taskProofs.filter { it.taskName != taskName }
                    firestore.collection("bookings").document(bookingId).update(mapOf("completedTasks" to updatedTasks, "taskProofs" to updatedProofs)).await()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                _uiState.value = _uiState.value.copy(isPhotoUploading = false)
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
                val scaledBitmap = if (scale < 1f) Bitmap.createScaledBitmap(originalBitmap, (originalBitmap.width * scale).roundToInt(), (originalBitmap.height * scale).roundToInt(), true) else originalBitmap
                val outputStream = ByteArrayOutputStream()
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 40, outputStream)
                "data:image/jpeg;base64,${Base64.encodeToString(outputStream.toByteArray(), Base64.DEFAULT)}"
            } catch (e: Exception) { null }
        }
    }

    fun rateCaregiver(bookingId: String, caregiverId: String, rating: Double, comment: String, onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                val clientId = auth.currentUser?.uid ?: ""
                val reviewId = java.util.UUID.randomUUID().toString()

                firestore.runTransaction { transaction ->
                    val userRef = firestore.collection("users").document(caregiverId)
                    val bookingRef = firestore.collection("bookings").document(bookingId)
                    val reviewRef = firestore.collection("reviews").document(reviewId)

                    val userSnap = transaction.get(userRef)
                    val currentRating = userSnap.getDouble("rating") ?: 0.0
                    val count = userSnap.getLong("reviewCount") ?: 0L
                    val newCount = count + 1
                    val newRating = ((currentRating * count) + rating) / newCount

                    transaction.update(bookingRef, "isRated", true)
                    transaction.update(bookingRef, "status", "COMPLETED")
                    transaction.update(bookingRef, "isCaregiverAcceptedEnd", true)

                    transaction.update(userRef, "rating", newRating)
                    transaction.update(userRef, "reviewCount", newCount)
                    transaction.update(userRef, "isBusy", false)

                    val reviewData = mapOf(
                        "id" to reviewId,
                        "bookingId" to bookingId,
                        "caregiverId" to caregiverId,
                        "clientId" to clientId,
                        "rating" to rating,
                        "comment" to comment,
                        "timestamp" to System.currentTimeMillis()
                    )
                    transaction.set(reviewRef, reviewData)
                }.await()
                onResult(true, "Review submitted successfully! Job is closed.")
            } catch (e: Exception) { onResult(false, "Error: ${e.message}") }
        }
    }
}