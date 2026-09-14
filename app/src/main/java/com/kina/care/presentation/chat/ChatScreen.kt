package com.kina.care.presentation.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import android.content.Intent
import android.net.Uri
import androidx.compose.ui.platform.LocalContext
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.outlined.Face
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.draw.clip
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.launch
import kotlin.math.min
import kotlin.math.roundToInt
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    bookingId: String,
    onBackClick: () -> Unit,
    viewModel: ChatViewModel = viewModel()
) {
    val messages by viewModel.messages.collectAsState()
    var inputText by remember { mutableStateOf("") }

    LaunchedEffect(bookingId) {
        viewModel.loadMessages(bookingId)
    }

    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var isUploadingImage by remember { mutableStateOf(false) }

    val imagePickerLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) {
            coroutineScope.launch {
                isUploadingImage = true
                val base64 = compressImageUriToBase64Chat(context, uri)
                if (base64 != null) {
                    viewModel.sendMessage(bookingId, "", base64)
                }
                isUploadingImage = false
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("පණිවිඩ (Messages)", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = onBackClick) { Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White) } },
                actions = {
                    IconButton(onClick = {
                        val uri = Uri.parse("https://meet.jit.si/GoldenHand_${bookingId}")
                        val intent = Intent(Intent.ACTION_VIEW, uri)
                        context.startActivity(intent)
                    }) {
                        Icon(Icons.Default.Call, contentDescription = "Video Call", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF0EA5E9))
            )
        },
        bottomBar = {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Color.White)
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { imagePickerLauncher.launch("image/*") }) {
                    Icon(androidx.compose.material.icons.Icons.Outlined.Face, contentDescription = "Add Image", tint = Color.Gray)
                }
                OutlinedTextField(
                    value = inputText,
                    onValueChange = { inputText = it },
                    placeholder = { Text(if(isUploadingImage) "Uploading..." else "Type a message...") },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(24.dp),
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Color(0xFF0EA5E9)),
                    enabled = !isUploadingImage
                )
                Spacer(modifier = Modifier.width(8.dp))
                FloatingActionButton(
                    onClick = {
                        viewModel.sendMessage(bookingId, inputText)
                        inputText = ""
                    },
                    containerColor = Color(0xFF0EA5E9),
                    contentColor = Color.White,
                    shape = CircleShape,
                    modifier = Modifier.size(50.dp)
                ) {
                    Icon(Icons.Default.Send, contentDescription = "Send")
                }
            }
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF1F5F9)).padding(paddingValues)) {
            if (messages.isEmpty()) {
                Text(
                    "රැකියාවට අදාළව පණිවිඩයක් යවන්න.\n(මෙම පණිවිඩ රැකියාව අවසන් වූ පසු මැකී යනු ඇත.)",
                    color = Color.Gray,
                    modifier = Modifier.align(Alignment.Center),
                    textAlign = TextAlign.Center
                )
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 8.dp),
                    reverseLayout = false
                ) {
                    items(messages) { msg ->
                        val isMe = msg.senderId == viewModel.currentUserId
                        val bgColor = if (isMe) Color(0xFFE0F2FE) else Color.White
                        val align = if (isMe) Alignment.End else Alignment.Start

                        Column(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalAlignment = align) {
                            if (!isMe) {
                                Text(msg.senderName, fontSize = 11.sp, color = Color.Gray, modifier = Modifier.padding(bottom = 2.dp, start = 4.dp))
                            }
                            Card(
                                shape = RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp, bottomStart = if(isMe) 16.dp else 4.dp, bottomEnd = if(isMe) 4.dp else 16.dp),
                                colors = CardDefaults.cardColors(containerColor = bgColor),
                                elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
                            ) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    if (!msg.imageUrl.isNullOrEmpty()) {
                                        val bmp = convertBase64ToBitmapChat(msg.imageUrl)
                                        if (bmp != null) {
                                            Image(
                                                bitmap = bmp.asImageBitmap(),
                                                contentDescription = null,
                                                contentScale = ContentScale.Crop,
                                                modifier = Modifier.fillMaxWidth(0.6f).height(150.dp).clip(RoundedCornerShape(8.dp))
                                            )
                                            Spacer(modifier = Modifier.height(4.dp))
                                        }
                                    }
                                    if (msg.text.isNotEmpty()) {
                                        Text(msg.text, fontSize = 15.sp, color = Color(0xFF1E293B))
                                    }
                                    Text(
                                        SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date(msg.timestamp)),
                                        fontSize = 10.sp, color = Color.Gray,
                                        modifier = Modifier.align(Alignment.End).padding(top=4.dp)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

fun convertBase64ToBitmapChat(base64Str: String): Bitmap? {
    return try {
        val pureBase64 = base64Str.substringAfter("base64,")
        val decodedBytes = Base64.decode(pureBase64, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)
    } catch (e: Exception) { null }
}

suspend fun compressImageUriToBase64Chat(context: android.content.Context, uri: Uri): String? {
    return withContext(Dispatchers.IO) {
        try {
            val ins = context.contentResolver.openInputStream(uri)
            val bmp = BitmapFactory.decodeStream(ins) ?: return@withContext null
            val scale = min(600f / bmp.width, 600f / bmp.height)
            val scaled = Bitmap.createScaledBitmap(bmp, (bmp.width * scale).roundToInt(), (bmp.height * scale).roundToInt(), true)
            val os = java.io.ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 70, os)
            val bytes = os.toByteArray()
            "data:image/jpeg;base64," + Base64.encodeToString(bytes, Base64.NO_WRAP)
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}