package com.kina.care.presentation.wallet

import androidx.lifecycle.ViewModel
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.WalletTransaction
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

data class WalletUiState(
    val isLoading: Boolean = true,
    val balance: Double = 0.0,
    val transactions: List<WalletTransaction> = emptyList(),
    val errorMessage: String? = null
)

class WalletViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _uiState = MutableStateFlow(WalletUiState())
    val uiState: StateFlow<WalletUiState> = _uiState.asStateFlow()

    init {
        fetchWalletData()
    }

    private fun fetchWalletData() {
        val userId = auth.currentUser?.uid ?: return

        // 1. දැනට ඇති මුදල (Balance) ලබාගැනීම
        firestore.collection("users").document(userId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) return@addSnapshotListener
                val balance = snapshot?.getDouble("walletBalance") ?: 0.0
                _uiState.value = _uiState.value.copy(balance = balance)
            }

        // 2. ගනුදෙනු ඉතිහාසය (Transactions) ලබාගැනීම
        firestore.collection("transactions")
            .whereEqualTo("userId", userId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    _uiState.value = _uiState.value.copy(isLoading = false, errorMessage = error.localizedMessage)
                    return@addSnapshotListener
                }
                if (snapshot != null) {
                    // අලුත්ම ගනුදෙනු ඉහළින් පෙන්වීමට කාලය අනුව පෙළගස්වයි
                    val list = snapshot.documents.mapNotNull { it.toObject(WalletTransaction::class.java) }
                        .sortedByDescending { it.timestamp }
                    _uiState.value = _uiState.value.copy(isLoading = false, transactions = list)
                } else {
                    _uiState.value = _uiState.value.copy(isLoading = false)
                }
            }
    }
}