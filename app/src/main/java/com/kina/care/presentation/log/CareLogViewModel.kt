package com.kina.care.presentation.log

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Query
import com.kina.care.domain.model.DailyCareLog
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

class CareLogViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _logs = MutableStateFlow<List<DailyCareLog>>(emptyList())
    val logs: StateFlow<List<DailyCareLog>> = _logs.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    // Load logs for a specific booking
    fun loadLogsForBooking(bookingId: String) {
        _isLoading.value = true
        firestore.collection("care_logs")
            .whereEqualTo("bookingId", bookingId)
            .orderBy("timestamp", Query.Direction.DESCENDING)
            .addSnapshotListener { snapshot, e ->
                _isLoading.value = false
                if (e != null || snapshot == null) return@addSnapshotListener
                val fetchedLogs = snapshot.documents.mapNotNull { it.toObject(DailyCareLog::class.java)?.copy(id = it.id) }
                _logs.value = fetchedLogs
            }
    }

    fun addLog(
        bookingId: String,
        elderId: String,
        bloodPressure: String,
        sugarLevel: String,
        temperature: String,
        mealStatus: String,
        medicationGiven: Boolean,
        notes: String,
        onResult: (Boolean, String) -> Unit
    ) {
        val caregiverId = auth.currentUser?.uid ?: return
        val logId = firestore.collection("care_logs").document().id
        
        val log = DailyCareLog(
            id = logId,
            bookingId = bookingId,
            caregiverId = caregiverId,
            elderId = elderId,
            timestamp = System.currentTimeMillis(),
            bloodPressure = bloodPressure,
            sugarLevel = sugarLevel,
            temperature = temperature,
            mealStatus = mealStatus,
            medicationGiven = medicationGiven,
            notes = notes
        )

        firestore.collection("care_logs").document(logId).set(log)
            .addOnSuccessListener { onResult(true, "Log added successfully") }
            .addOnFailureListener { e -> onResult(false, e.message ?: "Failed to add log") }
    }
}
