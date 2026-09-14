package com.kina.care.presentation.map

import androidx.lifecycle.ViewModel
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.Booking
import com.kina.care.domain.model.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import android.location.Location

data class MapUiState(
    val isLoading: Boolean = true,
    val role: String = "CLIENT",
    val activeBooking: Booking? = null,
    val clientLat: Double = 0.0,
    val clientLng: Double = 0.0,
    val caregiverLat: Double = 0.0,
    val caregiverLng: Double = 0.0,
    val distanceInMeters: Float = 0f,
    val errorMessage: String? = null
)

class MapViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _uiState = MutableStateFlow(MapUiState())
    val uiState: StateFlow<MapUiState> = _uiState.asStateFlow()

    init {
        loadMapData()
    }

    private fun loadMapData() {
        val userId = auth.currentUser?.uid ?: return

        firestore.collection("users").document(userId).get().addOnSuccessListener { doc ->
            val role = doc.getString("role") ?: "CLIENT"
            val queryField = if (role == "CAREGIVER") "caregiverId" else "clientId"

            firestore.collection("bookings")
                .whereEqualTo(queryField, userId)
                .whereIn("status", listOf("ACCEPTED", "IN_PROGRESS"))
                .addSnapshotListener { snapshot, _ ->
                    if (snapshot != null && !snapshot.isEmpty) {
                        val booking = snapshot.documents[0].toObject(Booking::class.java)

                        if (booking != null) {
                            if (role == "CLIENT") {
                                booking.caregiverId?.let { cgId ->
                                    firestore.collection("users").document(cgId).addSnapshotListener { cgSnap, _ ->
                                        val cgLat = cgSnap?.getDouble("locationLat") ?: 0.0
                                        val cgLng = cgSnap?.getDouble("locationLng") ?: 0.0
                                        val dist = calculateDistance(booking.locationLat, booking.locationLng, cgLat, cgLng)

                                        _uiState.value = _uiState.value.copy(
                                            isLoading = false, role = role, activeBooking = booking,
                                            clientLat = booking.locationLat, clientLng = booking.locationLng,
                                            caregiverLat = cgLat, caregiverLng = cgLng, distanceInMeters = dist
                                        )
                                    }
                                }
                            } else {
                                firestore.collection("users").document(userId).addSnapshotListener { mySnap, _ ->
                                    val myLat = mySnap?.getDouble("locationLat") ?: 0.0
                                    val myLng = mySnap?.getDouble("locationLng") ?: 0.0
                                    val dist = calculateDistance(booking.locationLat, booking.locationLng, myLat, myLng)

                                    _uiState.value = _uiState.value.copy(
                                        isLoading = false, role = role, activeBooking = booking,
                                        clientLat = booking.locationLat, clientLng = booking.locationLng,
                                        caregiverLat = myLat, caregiverLng = myLng, distanceInMeters = dist
                                    )
                                }
                            }
                        }
                    } else {
                        // ජොබ් එකක් නැත්නම් තමන්ගේ ලොකේෂන් එක විතරක් ගන්නවා
                        firestore.collection("users").document(userId).get().addOnSuccessListener { mySnap ->
                            val myLat = mySnap?.getDouble("locationLat") ?: 0.0
                            val myLng = mySnap?.getDouble("locationLng") ?: 0.0
                            _uiState.value = _uiState.value.copy(
                                isLoading = false, role = role, activeBooking = null,
                                caregiverLat = myLat, caregiverLng = myLng
                            )
                        }
                    }
                }
        }
    }

    private fun calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Float {
        if(lat1 == 0.0 || lat2 == 0.0) return 0f
        val results = FloatArray(1)
        Location.distanceBetween(lat1, lng1, lat2, lng2, results)
        return results[0]
    }
}