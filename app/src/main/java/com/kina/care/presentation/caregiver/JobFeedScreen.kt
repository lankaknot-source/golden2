package com.kina.care.presentation.caregiver

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.Booking
import com.kina.care.domain.model.ElderProfile
import com.kina.care.presentation.util.LocalIsSinhala
import kotlinx.coroutines.tasks.await
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JobFeedScreen(
    onBackClick: () -> Unit,
    onNavigateToChat: (String) -> Unit,
    viewModel: JobFeedViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val isSinhala = LocalIsSinhala.current.value

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (!isGranted) Toast.makeText(context, if(isSinhala) "Notifications පෙන්වීමට අවසර ලබා දී නොමැත." else "Notification permission denied.", Toast.LENGTH_SHORT).show()
    }

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if(isSinhala) "නව රැකියා ඉල්ලීම්" else "New Job Requests", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) { Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White) }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF1A5276))
            )
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF4F8FB)).padding(paddingValues)) {
            when {
                uiState.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = Color(0xFF1A5276))
                uiState.errorMessage != null -> Text(text = uiState.errorMessage!!, color = Color.Red, modifier = Modifier.align(Alignment.Center).padding(16.dp))
                uiState.jobs.isEmpty() -> Text(text = if(isSinhala) "දැනට නව ඉල්ලීම් කිසිවක් නොමැත" else "No new requests available", color = Color.Gray, modifier = Modifier.align(Alignment.Center))
                else -> {
                    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        items(uiState.jobs) { job ->
                            JobCard(
                                job = job,
                                viewModel = viewModel,
                                context = context,
                                isSinhala = isSinhala,
                                onAccept = {
                                    viewModel.acceptJob(context, job.id) { success, msg ->
                                        Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                                        if(success) { onBackClick() }
                                    }
                                },
                                onChat = { onNavigateToChat(job.id) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun JobCard(job: Booking, viewModel: JobFeedViewModel, context: Context, isSinhala: Boolean, onAccept: () -> Unit, onChat: () -> Unit) {
    val reqTimeString = SimpleDateFormat("MMM dd, hh:mm a", Locale.getDefault()).format(Date(job.requestedTime))
    var elder by remember { mutableStateOf<ElderProfile?>(null) }
    var isAccepting by remember { mutableStateOf(false) }
    var isRejecting by remember { mutableStateOf(false) }
    var caregiverRate by remember { mutableStateOf(0.0) }

    LaunchedEffect(job.elderId) {
        if (job.elderId.isNotEmpty()) {
            try {
                val doc = FirebaseFirestore.getInstance().collection("elders").document(job.elderId).get().await()
                if (doc.exists()) elder = doc.toObject(ElderProfile::class.java)
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    LaunchedEffect(Unit) {
        val currentUserId = FirebaseAuth.getInstance().currentUser?.uid
        if (currentUserId != null) {
            try {
                val doc = FirebaseFirestore.getInstance().collection("users").document(currentUserId).get().await()
                if (doc.exists()) caregiverRate = doc.getDouble("hourlyRate") ?: 0.0
            } catch (e: Exception) { e.printStackTrace() }
        }
    }

    Card(
        modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {

            if (job.status == "PENDING") {
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)), modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFF0EA5E9), modifier = Modifier.size(18.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(if(isSinhala) "විශේෂිත ආරාධනාවකි (Direct Request)" else "Direct Request (Invited)", fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), fontSize = 12.sp)
                    }
                }
            }

            if (job.scheduledTime > 0L) {
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF3C7)), modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.DateRange, contentDescription = null, tint = Color(0xFFD97706), modifier = Modifier.size(20.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(if(isSinhala) "දිනය වෙන්කර ඇති සේවාවකි" else "Scheduled Service", fontWeight = FontWeight.Bold, color = Color(0xFFB45309), fontSize = 12.sp)
                            val schedStr = SimpleDateFormat("yyyy MMM dd, hh:mm a", Locale.getDefault()).format(Date(job.scheduledTime))
                            Text(schedStr, fontWeight = FontWeight.ExtraBold, color = Color(0xFF92400E), fontSize = 14.sp)
                        }
                    }
                }
            } else {
                Text(if(isSinhala) "වහාම අවශ්‍යයි" else "Immediate Request", color = Color(0xFF10B981), fontWeight = FontWeight.Bold, fontSize = 12.sp, modifier = Modifier.padding(bottom=8.dp))
            }

            if (elder != null) {
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFF1F5F9)), modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Favorite, contentDescription = null, tint = Color(0xFF0EA5E9), modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(6.dp))
                            val agePrefix = if(isSinhala) "වයස:" else "Age:"
                            Text(text = "${elder!!.name} ($agePrefix ${elder!!.age})", fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), fontSize = 14.sp)
                        }
                        if (elder!!.medicalConditions.isNotEmpty()) {
                            val medPrefix = if(isSinhala) "ලෙඩ රෝග:" else "Medical:"
                            Text("$medPrefix ${elder!!.medicalConditions.joinToString(", ")}", color = Color.Red, fontSize = 12.sp, modifier = Modifier.padding(top=4.dp))
                        }
                    }
                }
            }

            Text(text = if(isSinhala) "අමතර විස්තරය:" else "Additional Details:", fontSize = 12.sp, color = Color.Gray)
            Text(text = job.jobDescription.ifEmpty { if(isSinhala) "නැත" else "None" }, fontSize = 16.sp, fontWeight = FontWeight.Medium, color = Color(0xFF1E293B))
            Spacer(modifier = Modifier.height(12.dp))

            Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFE0F2FE)), modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(modifier = Modifier.size(24.dp).background(Color(0xFF0284C7), CircleShape), contentAlignment = Alignment.Center) {
                        Text("Rs", color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                    Column {
                        Text(if(isSinhala) "ඇස්තමේන්තුගත ගාස්තුව (ඔබේ පැයක ගාස්තුව)" else "Estimated Rate (Your Hourly Rate)", fontWeight = FontWeight.Bold, color = Color(0xFF0369A1), fontSize = 12.sp)
                        Text("Rs. ${String.format(Locale.US, "%.2f", caregiverRate)} /hr", fontWeight = FontWeight.ExtraBold, color = Color(0xFF0C4A6E), fontSize = 14.sp)
                    }
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.LocationOn, contentDescription = "Location", tint = Color.Gray, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text(text = if(isSinhala) "සිතියමෙන් තෝරාගත් ස්ථානය" else "Location selected on map", fontSize = 14.sp, color = Color.Gray)
                Spacer(modifier = Modifier.weight(1f))
                Text(text = "Req: $reqTimeString", fontSize = 11.sp, color = Color.Gray)
            }
            Spacer(modifier = Modifier.height(16.dp))

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = {
                        isRejecting = true
                        viewModel.rejectJob(job.id) { success, msg ->
                            if (!success) isRejecting = false
                            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                        }
                    },
                    modifier = Modifier.weight(1f).height(45.dp),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color.Red),
                    border = BorderStroke(1.dp, Color.Red),
                    enabled = !isAccepting && !isRejecting
                ) {
                    if (isRejecting) {
                        CircularProgressIndicator(color = Color.Red, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Icon(Icons.Default.Clear, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(if(isSinhala) "ප්‍රතික්ෂේප කරන්න" else "Reject", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }
                }

                Button(
                    onClick = {
                        isAccepting = true
                        onAccept()
                    },
                    modifier = Modifier.weight(1.3f).height(45.dp),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981)),
                    enabled = !isAccepting && !isRejecting
                ) {
                    if (isAccepting) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Text(if(isSinhala) "භාරගන්න" else "Accept", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                }
            }
        }
    }
}