package com.kina.care.presentation.client

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.Review
import com.kina.care.domain.model.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class FindCaregiverUiState(
    val isLoading: Boolean = true,
    val caregivers: List<User> = emptyList(),
    val errorMessage: String? = null
)

class FindCaregiverViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()
    private val currentUserId = auth.currentUser?.uid

    private val _uiState = MutableStateFlow(FindCaregiverUiState())
    val uiState: StateFlow<FindCaregiverUiState> = _uiState.asStateFlow()

    private var allCaregivers: List<User> = emptyList()

    val searchQuery = MutableStateFlow("")
    val selectedCategory = MutableStateFlow("All")

    private val _reviewsState = MutableStateFlow<List<Review>>(emptyList())
    val reviewsState: StateFlow<List<Review>> = _reviewsState.asStateFlow()

    var isReviewsLoading = MutableStateFlow(false)

    private val _favoriteCaregiverIds = MutableStateFlow<List<String>>(emptyList())
    val favoriteCaregiverIds: StateFlow<List<String>> = _favoriteCaregiverIds.asStateFlow()

    init {
        fetchCaregiversFromFirebase()
        fetchFavoriteCaregivers()
    }

    private fun fetchFavoriteCaregivers() {
        if (currentUserId == null) return
        firestore.collection("users").document(currentUserId)
            .addSnapshotListener { snapshot, _ ->
                if (snapshot != null && snapshot.exists()) {
                    val user = snapshot.toObject(User::class.java)
                    _favoriteCaregiverIds.value = user?.favoriteCaregivers ?: emptyList()
                }
            }
    }

    fun toggleFavorite(caregiverId: String) {
        if (currentUserId == null) return
        val currentFavs = _favoriteCaregiverIds.value.toMutableList()
        if (currentFavs.contains(caregiverId)) {
            currentFavs.remove(caregiverId)
        } else {
            currentFavs.add(caregiverId)
        }
        firestore.collection("users").document(currentUserId)
            .update("favoriteCaregivers", currentFavs)
    }

    private fun fetchCaregiversFromFirebase() {
        viewModelScope.launch {
            try {
                val snapshot = firestore.collection("users")
                    .whereIn("role", listOf("CAREGIVER", "NURSE"))
                    .get()
                    .await()

                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

                val list = snapshot.documents.mapNotNull { it.toObject(User::class.java) }
                    // 🌟 Fix: kycStatus == "APPROVED" වූ විටත් ගිණුම් පෙන්වයි
                    .filter { (it.isVerified || it.kycStatus == "APPROVED") && !it.isBusy && !it.onLeaveDates.contains(todayStr) }
                    .sortedByDescending { it.rating }

                allCaregivers = list
                applyFilters()

            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = e.localizedMessage)
            }
        }
    }

    fun updateSearchQuery(query: String) {
        searchQuery.value = query
        applyFilters()
    }

    fun updateCategory(category: String) {
        selectedCategory.value = category
        applyFilters()
    }

    private fun applyFilters() {
        var filteredList = allCaregivers

        val query = searchQuery.value.trim()
        if (query.isNotEmpty()) {
            filteredList = filteredList.filter {
                it.name.contains(query, ignoreCase = true) ||
                        it.address.contains(query, ignoreCase = true)
            }
        }

        // 🌟 Fix: Caregiver සහ Nurse ලෙස Role එක අනුව Filter කිරීම
        val category = selectedCategory.value
        if (category == "Caregiver") {
            filteredList = filteredList.filter { it.role == "CAREGIVER" }
        } else if (category == "Nurse") {
            filteredList = filteredList.filter { it.role == "NURSE" }
        }

        _uiState.value = _uiState.value.copy(isLoading = false, caregivers = filteredList)
    }

    fun fetchReviewsForCaregiver(caregiverId: String) {
        viewModelScope.launch {
            isReviewsLoading.value = true
            try {
                val snapshot = firestore.collection("reviews")
                    .whereEqualTo("caregiverId", caregiverId)
                    .get()
                    .await()

                val reviews = snapshot.documents.mapNotNull { it.toObject(Review::class.java) }
                    .sortedByDescending { it.timestamp }

                _reviewsState.value = reviews
            } catch (e: Exception) {
                e.printStackTrace()
                _reviewsState.value = emptyList()
            } finally {
                isReviewsLoading.value = false
            }
        }
    }

    fun clearReviews() {
        _reviewsState.value = emptyList()
    }
}