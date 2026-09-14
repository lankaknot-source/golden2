package com.kina.care.domain.model

import com.google.firebase.firestore.PropertyName

data class User(
    val id: String = "",
    val name: String = "",
    val email: String = "",
    val phone: String = "",
    val mobile: String = "",
    val role: String = "CLIENT",
    val profileImageUrl: String = "",
    val kycStatus: String = "PENDING",

    @get:PropertyName("isVerified")
    @set:PropertyName("isVerified")
    var isVerified: Boolean = false,

    @get:PropertyName("isBusy")
    @set:PropertyName("isBusy")
    var isBusy: Boolean = false,

    @get:PropertyName("rejectionReason")
    @set:PropertyName("rejectionReason")
    var rejectionReason: String = "",

    val walletBalance: Double = 0.0,
    val rating: Double = 0.0,
    val reviewCount: Long = 0L,
    val locationLat: Double = 0.0,
    val locationLng: Double = 0.0,
    val hourlyRate: Double = 0.0,
    val onLeaveDates: List<String> = emptyList(),

    val nicNumber: String = "",
    val dob: String = "",
    val gender: String = "",
    val address: String = "",
    val nicFrontUrl: String = "",
    val nicBackUrl: String = "",
    val selfieUrl: String = "",
    val digitalSignatureUrl: String = "",
    val idFrontUrl: String = "",
    val idBackUrl: String = "",

    val policeClearanceUrl: String = "",
    val categories: List<String> = emptyList(),
    val experienceYears: String = "",
    val references: String = "",
    val specialSkills: String = "",
    val qualifications: String = "",
    val certificatesUrls: List<String> = emptyList(),
    val certificateUrl: String = "",
    val chronicIllnesses: String = "",
    val vaccinationStatus: String = "",
    val medicalFitnessUrl: String = "",
    val bankName: String = "",
    val bankAccountNumber: String = "",
    val bankBranch: String = "",
    val bankBookUrl: String = "",
    val preferredDistricts: List<String> = emptyList(),
    val preferredServiceTypes: List<String> = emptyList(),
    val expectedSalary: Double = 0.0,

    val serviceAddress: String = "",
    val billingName: String = "",
    val billingAddress: String = "",
    val autoPaymentConsent: Boolean = false,

    // KYC Video Meeting Data
    val kycMeetingDateMs: Long? = null,
    val kycMeetingUrl: String = "",
    val kycMeetingStatus: String = "",
    
    // Favorites Feature
    val favoriteCaregivers: List<String> = emptyList()
)

data class MedicineReminder(
    val id: String = "",
    val time: String = "",
    val name: String = "",
    val photoBase64: String = ""
)

data class ElderProfile(
    val id: String = "",
    val clientId: String = "",
    val name: String = "",
    val age: Int = 0,
    val gender: String = "",
    val medicalConditions: List<String> = emptyList(),
    val specialCareRequirements: String = "",
    val emergencyContactPerson: String = "",
    val emergencyContact: String = "",
    val requiredLanguage: String = "Sinhala",
    val medicineReminders: List<String> = emptyList(),
    val medicineList: List<MedicineReminder> = emptyList()
)

data class TaskProof(
    val taskName: String = "",
    val photoUrl: String = "",
    val timestamp: Long = System.currentTimeMillis()
)

data class SubscriptionPlan(
    val id: String = "",
    val title: String = "",
    val description: String = "",
    val price: Double = 0.0,
    val assignedCaregivers: List<String> = emptyList(),
    val timestamp: Long = System.currentTimeMillis()
)

data class Booking(
    val id: String = "",
    val clientId: String = "",
    val caregiverId: String? = null,
    val elderId: String = "",
    val appliedCaregivers: List<String> = emptyList(),
    val rejectedBy: List<String> = emptyList(),

    val allowedCaregivers: List<String> = emptyList(),
    @get:PropertyName("isSubscriptionBooking")
    @set:PropertyName("isSubscriptionBooking")
    var isSubscriptionBooking: Boolean = false,
    val planName: String = "",

    val status: String = "PENDING",
    val requestedTime: Long = System.currentTimeMillis(),
    val scheduledTime: Long = 0L,
    val locationLat: Double = 0.0,
    val locationLng: Double = 0.0,
    val address: String = "",
    val jobDescription: String = "",

    @get:PropertyName("isEmergency")
    @set:PropertyName("isEmergency")
    var isEmergency: Boolean = false,

    val totalAmount: Double = 0.0,
    val hourlyRate: Double = 0.0,
    val estimatedHours: Int = 1,

    @get:PropertyName("isClientEnded")
    @set:PropertyName("isClientEnded")
    var isClientEnded: Boolean = false,

    @get:PropertyName("isCaregiverAcceptedEnd")
    @set:PropertyName("isCaregiverAcceptedEnd")
    var isCaregiverAcceptedEnd: Boolean = false,

    @get:PropertyName("isRated")
    @set:PropertyName("isRated")
    var isRated: Boolean = false,

    @get:PropertyName("isPaid")
    @set:PropertyName("isPaid")
    var isPaid: Boolean = false,

    @get:PropertyName("replacementRequested")
    @set:PropertyName("replacementRequested")
    var replacementRequested: Boolean = false,
    val replacementReason: String = "",

    val startCode: String = "",
    val startTime: Long? = null,
    val endTime: Long? = null,

    val careCategory: String = "Elderly Care",
    val serviceType: String = "Live-out",
    val durationType: String = "Short-term",
    val requestedTasks: List<String> = emptyList(),
    val completedTasks: List<String> = emptyList(),
    val taskProofs: List<TaskProof> = emptyList(),
    val clientApprovedTasks: List<String> = emptyList(),

    @get:PropertyName("hasComplaint")
    @set:PropertyName("hasComplaint")
    var hasComplaint: Boolean = false,
    val complaintNotes: String = "",

    val caregiverResponse: String = ""
)

data class ChatMessage(
    val id: String = "",
    val bookingId: String = "",
    val senderId: String = "",
    val senderName: String = "",
    val text: String = "",
    val imageUrl: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)

data class Review(
    val id: String = "",
    val bookingId: String = "",
    val caregiverId: String = "",
    val clientId: String = "",
    val rating: Double = 0.0,
    val comment: String = "",
    val timestamp: Long = System.currentTimeMillis()
)

data class WalletTransaction(
    val id: String = "",
    val userId: String = "",
    val amount: Double = 0.0,
    val type: String = "CREDIT",
    val description: String = "",
    val timestamp: Long = System.currentTimeMillis(),
    val receiptImageUrl: String? = null
)

data class LeaveRequest(
    val id: String = "",
    val caregiverId: String = "",
    val caregiverName: String = "",
    val dateMs: Long = 0L,
    val dateString: String = "",
    val reason: String = "",
    val status: String = "PENDING",
    val requestedAt: Long = System.currentTimeMillis()
)

data class DailyCareLog(
    val id: String = "",
    val bookingId: String = "",
    val caregiverId: String = "",
    val elderId: String = "",
    val sugarLevel: String = "",
    val bloodPressure: String = "",
    val temperature: String = "",
    val mealStatus: String = "",
    val medicationGiven: Boolean = false,
    val notes: String = "",
    val timestamp: Long = System.currentTimeMillis()
)