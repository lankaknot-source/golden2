package com.kina.care.presentation.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

// State එකට needsRoleSelection එකතු කර ඇත
data class AuthState(
    val isLoading: Boolean = false,
    val isSuccess: Boolean = false,
    val needsRoleSelection: Boolean = false,
    val errorMessage: String? = null
)

class AuthViewModel : ViewModel() {

    private val auth: FirebaseAuth = FirebaseAuth.getInstance()
    private val firestore: FirebaseFirestore = FirebaseFirestore.getInstance()

    private val _authState = MutableStateFlow(AuthState())
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    fun login(email: String, password: String) {
        viewModelScope.launch {
            _authState.value = AuthState(isLoading = true)
            try {
                val result = auth.signInWithEmailAndPassword(email, password).await()
                if (result.user != null) {
                    _authState.value = AuthState(isSuccess = true, isLoading = false)
                }
            } catch (e: Exception) {
                _authState.value = AuthState(isLoading = false, errorMessage = e.localizedMessage ?: "Login failed.")
            }
        }
    }

    // Google Login එක යාවත්කාලීන කර ඇත
    fun loginWithGoogle(idToken: String) {
        viewModelScope.launch {
            _authState.value = AuthState(isLoading = true)
            try {
                val credential = GoogleAuthProvider.getCredential(idToken, null)
                val result = auth.signInWithCredential(credential).await()
                val user = result.user

                if (user != null) {
                    // Firestore එකේ මේ User ගේ දත්ත තියෙනවද බලනවා (පරණ කෙනෙක්ද අලුත් කෙනෙක්ද)
                    val doc = firestore.collection("users").document(user.uid).get().await()
                    if (doc.exists()) {
                        // පරණ කෙනෙක් නම් කෙලින්ම Home එකට යන්න Success කරනවා
                        _authState.value = AuthState(isSuccess = true, isLoading = false)
                    } else {
                        // අලුත් කෙනෙක් නම් Role එක අහන්න වෙනම තිරයකට යවනවා
                        _authState.value = AuthState(needsRoleSelection = true, isLoading = false)
                    }
                }
            } catch (e: Exception) {
                _authState.value = AuthState(isLoading = false, errorMessage = e.localizedMessage ?: "Google sign in failed.")
            }
        }
    }

    // අලුත් Google යූසර් කෙනෙක්ගේ Role එක සේව් කිරීම
    fun saveGoogleUserRole(role: String) {
        viewModelScope.launch {
            _authState.value = AuthState(isLoading = true)
            try {
                val user = auth.currentUser
                if (user != null) {
                    val userMap = hashMapOf(
                        "id" to user.uid,
                        "name" to (user.displayName ?: "No Name"),
                        "email" to (user.email ?: ""),
                        "role" to role,
                        "isVerified" to false,
                        "walletBalance" to 0.0
                    )
                    firestore.collection("users").document(user.uid).set(userMap).await()

                    // සේව් කරාට පස්සේ Home එකට යන්න Success කරනවා
                    _authState.value = AuthState(isSuccess = true, isLoading = false)
                }
            } catch (e: Exception) {
                _authState.value = AuthState(isLoading = false, errorMessage = e.localizedMessage)
            }
        }
    }

    fun signUp(email: String, password: String, name: String, role: String) {
        viewModelScope.launch {
            _authState.value = AuthState(isLoading = true)
            try {
                val result = auth.createUserWithEmailAndPassword(email, password).await()
                val user = result.user

                if (user != null) {
                    val userMap = hashMapOf(
                        "id" to user.uid,
                        "name" to name,
                        "email" to email,
                        "role" to role,
                        "isVerified" to false,
                        "walletBalance" to 0.0
                    )
                    firestore.collection("users").document(user.uid).set(userMap).await()
                    _authState.value = AuthState(isSuccess = true, isLoading = false)
                }
            } catch (e: Exception) {
                _authState.value = AuthState(isLoading = false, errorMessage = e.localizedMessage ?: "Sign up failed.")
            }
        }
    }

    fun logout() {
        auth.signOut()
        _authState.value = AuthState()
    }

    fun sendPasswordResetEmail(email: String, onResult: (Boolean, String) -> Unit) {
        if (email.isEmpty()) {
            onResult(false, "කරුණාකර ඔබගේ ඊමේල් ලිපිනය ඇතුලත් කරන්න.")
            return
        }
        auth.sendPasswordResetEmail(email)
            .addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    onResult(true, "Password Reset ලින්ක් එක ඔබගේ ඊමේල් ගිණුමට යවන ලදී. කරුණාකර Inbox එක පරීක්ෂා කරන්න.")
                } else {
                    onResult(false, task.exception?.localizedMessage ?: "දෝෂයකි. කරුණාකර නැවත උත්සාහ කරන්න.")
                }
            }
    }
}