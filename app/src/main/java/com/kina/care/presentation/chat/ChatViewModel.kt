package com.kina.care.presentation.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.ChatMessage
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.UUID

class ChatViewModel : ViewModel() {
    private val firestore = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()

    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages.asStateFlow()

    val currentUserId = auth.currentUser?.uid ?: ""
    var currentUserName = "User"

    init {
        // ලොග් වී ඇති කෙනාගේ නම ලබාගැනීම
        viewModelScope.launch {
            if (currentUserId.isNotEmpty()) {
                try {
                    val doc = firestore.collection("users").document(currentUserId).get().await()
                    currentUserName = doc.getString("name") ?: "User"
                } catch(e: Exception){}
            }
        }
    }

    fun loadMessages(bookingId: String) {
        firestore.collection("chats")
            .whereEqualTo("bookingId", bookingId)
            .addSnapshotListener { snapshot, error ->
                if (error != null) return@addSnapshotListener
                if (snapshot != null) {
                    val list = snapshot.documents.mapNotNull { it.toObject(ChatMessage::class.java) }
                        .sortedBy { it.timestamp } // පරණ මැසේජ් උඩින්, අලුත් ඒවා යටින්
                    _messages.value = list
                }
            }
    }

    fun sendMessage(bookingId: String, text: String, imageUrl: String? = null) {
        if (text.isBlank() && imageUrl.isNullOrBlank()) return
        viewModelScope.launch {
            val msgId = UUID.randomUUID().toString()
            val chatMsg = ChatMessage(
                id = msgId,
                bookingId = bookingId,
                senderId = currentUserId,
                senderName = currentUserName,
                text = text.trim(),
                imageUrl = imageUrl,
                timestamp = System.currentTimeMillis()
            )
            try {
                firestore.collection("chats").document(msgId).set(chatMsg).await()
            } catch(e: Exception) { e.printStackTrace() }
        }
    }
}