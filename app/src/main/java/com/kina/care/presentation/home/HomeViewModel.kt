package com.kina.care.presentation.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.Booking
import com.kina.care.domain.model.ElderProfile
import com.kina.care.domain.model.Review
import com.kina.care.domain.model.SubscriptionPlan
import com.kina.care.domain.model.User
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.UUID

data class HomeUiState(
    val isLoading: Boolean = true,
    val userData: User? = null,
    val topCaregivers: List<User> = emptyList(),
    val activeBooking: Booking? = null,
    val activeElder: ElderProfile? = null,
    val errorMessage: String? = null,
    val isBirthday: Boolean = false,
    val clientElders: List<ElderProfile> = emptyList()
)

class HomeViewModel : ViewModel() {
    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
    private val firestore: FirebaseFirestore = FirebaseFirestore.getInstance()

    private val _uiState = MutableStateFlow(HomeUiState())
    val uiState: StateFlow<HomeUiState> = _uiState.asStateFlow()

    private val _reviewsState = MutableStateFlow<List<Review>>(emptyList())
    val reviewsState: StateFlow<List<Review>> = _reviewsState.asStateFlow()
    var isReviewsLoading = MutableStateFlow(false)

    private val _subscriptionPlans = MutableStateFlow<List<SubscriptionPlan>>(emptyList())
    val subscriptionPlans: StateFlow<List<SubscriptionPlan>> = _subscriptionPlans.asStateFlow()

    init {
        fetchUserData()
        fetchSubscriptionPlans()
    }

    private fun fetchSubscriptionPlans() {
        firestore.collection("subscription_plans")
            .addSnapshotListener { snapshot, error ->
                if (error != null) return@addSnapshotListener
                if (snapshot != null) {
                    _subscriptionPlans.value = snapshot.documents.mapNotNull { it.toObject(SubscriptionPlan::class.java) }
                }
            }
    }

    fun fetchUserData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true)
            try {
                val userId = auth.currentUser?.uid
                if (userId != null) {
                    // 🌟 Fix: get() වෙනුවට addSnapshotListener() — real-time update ලැබෙනවා
                    firestore.collection("users").document(userId)
                        .addSnapshotListener { document, _ ->
                            if (document != null && document.exists()) {
                                val user = document.toObject(User::class.java)

                                // 🌟 Fix: CAREGIVER/NURSE ලට මක් isVerified = true auto-fix
                                // CLIENT ලා registration fee ගෙව්වාට පස්සෙ verified වෙනවා
                                val isCaregiverRole = user?.role == "CAREGIVER" || user?.role == "NURSE"
                                if (user != null && isCaregiverRole && user.kycStatus == "APPROVED" && !user.isVerified) {
                                    firestore.collection("users").document(userId)
                                        .update("isVerified", true)
                                }

                                var isUserBirthday = false
                                if (user != null && user.dob.isNotEmpty()) {
                                    try {
                                        val cleanDob = user.dob.replace("/", "-")
                                        val parts = cleanDob.split("-")
                                        if (parts.size >= 3) {
                                            val month: Int?
                                            val day: Int?
                                            if (parts[0].length == 4) {
                                                month = parts[1].toIntOrNull()
                                                day = parts[2].toIntOrNull()
                                            } else {
                                                day = parts[0].toIntOrNull()
                                                month = parts[1].toIntOrNull()
                                            }

                                            val cal = Calendar.getInstance()
                                            if (month == cal.get(Calendar.MONTH) + 1 && day == cal.get(Calendar.DAY_OF_MONTH)) {
                                                isUserBirthday = true
                                            }
                                        }
                                    } catch (e: Exception) { e.printStackTrace() }
                                }

                                if (user?.role == "CLIENT") {
                                    firestore.collection("elders").whereEqualTo("clientId", userId).addSnapshotListener { snap, _ ->
                                        if (snap != null) {
                                            _uiState.value = _uiState.value.copy(clientElders = snap.documents.mapNotNull { it.toObject(ElderProfile::class.java) })
                                        }
                                    }

                                    viewModelScope.launch {
                                        try {
                                            val caregiversSnapshot = firestore.collection("users")
                                                .whereIn("role", listOf("CAREGIVER", "NURSE"))
                                                .get().await()

                                            val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                                            val caregiversList = caregiversSnapshot.documents.mapNotNull { it.toObject(User::class.java) }
                                                .filter { (it.isVerified || it.kycStatus == "APPROVED") && !it.isBusy && !it.onLeaveDates.contains(todayStr) }
                                                .sortedByDescending { it.rating }
                                                .take(5)

                                            _uiState.value = _uiState.value.copy(isLoading = false, userData = user, topCaregivers = caregiversList, isBirthday = isUserBirthday)
                                        } catch (e: Exception) {
                                            _uiState.value = _uiState.value.copy(isLoading = false, userData = user, isBirthday = isUserBirthday)
                                        }
                                    }
                                } else if (user?.role == "CAREGIVER" || user?.role == "NURSE") {
                                    firestore.collection("bookings")
                                        .whereEqualTo("caregiverId", userId)
                                        .whereIn("status", listOf("ACCEPTED", "IN_PROGRESS"))
                                        .addSnapshotListener { snap, error ->
                                            if (error != null) return@addSnapshotListener
                                            if (snap != null && !snap.isEmpty) {
                                                val booking = snap.documents[0].toObject(Booking::class.java)
                                                _uiState.value = _uiState.value.copy(activeBooking = booking)
                                                if (booking != null && booking.elderId.isNotEmpty()) {
                                                    firestore.collection("elders").document(booking.elderId).get()
                                                        .addOnSuccessListener { elderDoc ->
                                                            if (elderDoc.exists()) {
                                                                _uiState.value = _uiState.value.copy(activeElder = elderDoc.toObject(ElderProfile::class.java))
                                                            }
                                                        }
                                                }
                                            } else {
                                                _uiState.value = _uiState.value.copy(activeBooking = null, activeElder = null)
                                            }
                                        }
                                    _uiState.value = _uiState.value.copy(isLoading = false, userData = user, isBirthday = isUserBirthday)
                                }
                            } else {
                                _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = "User data not found")
                            }
                        }
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = e.localizedMessage)
            }
        }
    }

    fun dismissBirthdayPopup() { _uiState.value = _uiState.value.copy(isBirthday = false) }

    fun purchaseSubscriptionPlan(plan: SubscriptionPlan, elderId: String, onResult: (Boolean, String) -> Unit) {
        viewModelScope.launch {
            try {
                val clientId = auth.currentUser?.uid ?: return@launch
                val jobId = UUID.randomUUID().toString()

                val newBooking = Booking(
                    id = jobId,
                    clientId = clientId,
                    caregiverId = null,
                    elderId = elderId,
                    status = "BROADCASTED",
                    isEmergency = true,
                    requestedTime = System.currentTimeMillis(),
                    jobDescription = "Premium Package: ${plan.title}\n\n${plan.description}",

                    isSubscriptionBooking = true,
                    planName = plan.title,
                    allowedCaregivers = plan.assignedCaregivers,

                    totalAmount = plan.price,
                    isPaid = true
                )

                firestore.collection("bookings").document(jobId).set(newBooking).await()

                val txId = UUID.randomUUID().toString()
                val txData = hashMapOf(
                    "id" to txId, "userId" to clientId, "amount" to plan.price,
                    "type" to "PACKAGE_FEE", "description" to "Purchased Package: ${plan.title}",
                    "timestamp" to System.currentTimeMillis()
                )
                firestore.collection("transactions").document(txId).set(txData).await()

                onResult(true, "සාර්ථකව මිලදී ගන්නා ලදී! Admin අනුයුක්ත කළ සේවකයින්ට පණිවිඩය යවන ලදී.")
            } catch (e: Exception) {
                onResult(false, "දෝෂයකි: ${e.message}")
            }
        }
    }

    fun fetchReviewsForCaregiver(caregiverId: String) {
        viewModelScope.launch {
            isReviewsLoading.value = true
            try {
                val snapshot = firestore.collection("reviews").whereEqualTo("caregiverId", caregiverId).get().await()
                _reviewsState.value = snapshot.documents.mapNotNull { it.toObject(Review::class.java) }.sortedByDescending { it.timestamp }
            } catch (e: Exception) {
                _reviewsState.value = emptyList()
            } finally {
                isReviewsLoading.value = false
            }
        }
    }

    fun clearReviews() { _reviewsState.value = emptyList() }

    fun logout() {
        auth.signOut()
    }
}