package com.kina.care.presentation.profile

import android.app.DatePickerDialog
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.kina.care.presentation.util.LocalIsSinhala
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.Date
import kotlin.math.min
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    onBackClick: () -> Unit,
    onNavigateToVerification: () -> Unit = {},
    onNavigateToClientKyc: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    viewModel: ProfileViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val isSinhala = LocalIsSinhala.current.value

    var name by remember { mutableStateOf("") }
    var phone by remember { mutableStateOf("") }
    var hourlyRate by remember { mutableStateOf("") }
    var profilePicBase64 by remember { mutableStateOf("") }

    var showLeaveDialog by remember { mutableStateOf(false) }
    var leaveReason by remember { mutableStateOf("") }
    var selectedLeaveDateMs by remember { mutableStateOf(0L) }
    var selectedLeaveDateStr by remember { mutableStateOf(if(isSinhala) "දිනය තෝරන්න" else "Select Date") }
    val calendar = Calendar.getInstance()

    var showRegistrationFeeDialog by remember { mutableStateOf(false) }
    var isProcessingFee by remember { mutableStateOf(false) }

    var feeReceiptUri by remember { mutableStateOf<Uri?>(null) }
    val feeReceiptLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        feeReceiptUri = uri
    }

    fun pickLeaveDate() {
        DatePickerDialog(
            context,
            { _, year, month, day ->
                calendar.set(year, month, day)
                selectedLeaveDateMs = calendar.timeInMillis
                selectedLeaveDateStr = SimpleDateFormat("yyyy MMM dd", Locale.getDefault()).format(calendar.time)
            },
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH),
            calendar.get(Calendar.DAY_OF_MONTH)
        ).apply {
            datePicker.minDate = System.currentTimeMillis()
        }.show()
    }

    val galleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        if (uri != null) {
            coroutineScope.launch {
                val compressed = compressImageUriToBase64(context, uri)
                if (compressed != null) {
                    profilePicBase64 = compressed
                }
            }
        }
    }

    LaunchedEffect(uiState.userData) {
        uiState.userData?.let { user ->
            if (name.isEmpty()) name = user.name
            if (phone.isEmpty()) phone = user.phone.removePrefix("+94").removePrefix("0")
            if (hourlyRate.isEmpty()) hourlyRate = if (user.hourlyRate > 0) user.hourlyRate.toString() else ""
            if (profilePicBase64.isEmpty() && user.profileImageUrl.isNotEmpty()) {
                profilePicBase64 = user.profileImageUrl
            }
        }
    }

    LaunchedEffect(uiState.isSaveSuccess) {
        if (uiState.isSaveSuccess) {
            Toast.makeText(context, if(isSinhala) "ගිණුම යාවත්කාලීන කරන ලදී!" else "Profile updated successfully!", Toast.LENGTH_SHORT).show()
            viewModel.resetSaveSuccess()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if(isSinhala) "මගේ ගිණුම (Profile)" else "My Profile", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }
                },
                actions = {
                    IconButton(onClick = onNavigateToSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF1A5276))
            )
        }
    ) { paddingValues ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFFF4F8FB))
                .padding(paddingValues)
        ) {
            when {
                uiState.isLoading -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = Color(0xFF1A5276))
                }
                uiState.userData != null -> {
                    val user = uiState.userData!!

                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Box(
                            modifier = Modifier
                                .size(120.dp)
                                .clip(CircleShape)
                                .background(Color(0xFFE2E8F0))
                                .clickable { galleryLauncher.launch("image/*") },
                            contentAlignment = Alignment.Center
                        ) {
                            if (profilePicBase64.isNotEmpty() && profilePicBase64.startsWith("data:image")) {
                                val bitmap = convertBase64ToBitmap(profilePicBase64)
                                if (bitmap != null) {
                                    Image(
                                        bitmap = bitmap.asImageBitmap(),
                                        contentDescription = "Profile Pic",
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier.fillMaxSize()
                                    )
                                } else {
                                    Icon(Icons.Default.Add, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(40.dp))
                                }
                            } else {
                                Icon(Icons.Default.Add, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(40.dp))
                                Text(
                                    if(isSinhala) "ඡායාරූපය" else "Add Photo",
                                    color = Color.Gray,
                                    fontSize = 10.sp,
                                    modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 16.dp)
                                )
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        if (user.role == "CAREGIVER" || user.role == "NURSE") {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                val rateStr = String.format(Locale.US, "%.1f", user.rating)
                                Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFF59E0B), modifier = Modifier.size(24.dp))
                                Spacer(modifier = Modifier.width(4.dp))
                                Text(
                                    text = "$rateStr (${user.reviewCount} ${if(isSinhala) "අදහස්" else "Reviews"})",
                                    fontSize = 16.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color(0xFF1E293B)
                                )
                            }

                            Spacer(modifier = Modifier.height(16.dp))

                            val isActive = user.isVerified || user.kycStatus == "APPROVED"
                            if (isActive) {
                                OutlinedButton(
                                    onClick = { showLeaveDialog = true },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(45.dp),
                                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFEAB308)),
                                    border = BorderStroke(1.dp, Color(0xFFEAB308))
                                ) {
                                    Icon(Icons.Default.DateRange, contentDescription = null)
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(if(isSinhala) "නිවාඩුවක් ඉල්ලන්න" else "Request Leave", fontWeight = FontWeight.Bold)
                                }
                                Spacer(modifier = Modifier.height(16.dp))
                            }
                        }

                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(16.dp),
                            colors = CardDefaults.cardColors(containerColor = Color.White),
                            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                        ) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                OutlinedTextField(
                                    value = name,
                                    onValueChange = { name = it },
                                    label = { Text(if(isSinhala) "සම්පූර්ණ නම" else "Full Name") },
                                    modifier = Modifier.fillMaxWidth()
                                )
                                Spacer(modifier = Modifier.height(16.dp))

                                OutlinedTextField(
                                    value = phone,
                                    onValueChange = { newValue ->
                                        val digits = newValue.filter { it.isDigit() }.take(9)
                                        phone = digits
                                    },
                                    label = { Text(if(isSinhala) "දුරකථන අංකය" else "Phone Number") },
                                    leadingIcon = {
                                        Text(
                                            text = " +94 ",
                                            fontWeight = FontWeight.Bold,
                                            color = Color(0xFF0D3B66),
                                            modifier = Modifier.padding(start = 16.dp, end = 4.dp)
                                        )
                                    },
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true
                                )
                                Spacer(modifier = Modifier.height(16.dp))

                                if (user.role == "CAREGIVER" || user.role == "NURSE") {
                                    OutlinedTextField(
                                        value = hourlyRate,
                                        onValueChange = { newValue ->
                                            if (newValue.isEmpty() || newValue.matches(Regex("^\\d*\\.?\\d*\$"))) {
                                                hourlyRate = newValue
                                            }
                                        },
                                        label = { Text(if(isSinhala) "පැයකට අය කරන මුදල (Rs.)" else "Hourly Rate (Rs.)") },
                                        modifier = Modifier.fillMaxWidth(),
                                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                                        singleLine = true
                                    )
                                    Spacer(modifier = Modifier.height(24.dp))
                                }

                                Button(
                                    onClick = {
                                        if (phone.length == 9) {
                                            val fullPhone = "+94$phone"
                                            val rateDouble = hourlyRate.toDoubleOrNull() ?: 0.0
                                            viewModel.updateProfileFull(name, fullPhone, rateDouble, profilePicBase64)
                                        } else {
                                            Toast.makeText(context, if(isSinhala) "නිවැරදි දුරකථන අංකයක් ලබා දෙන්න (ඉලක්කම් 9ක්)" else "Enter a valid 9-digit number", Toast.LENGTH_SHORT).show()
                                        }
                                    },
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .height(50.dp),
                                    shape = RoundedCornerShape(12.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9))
                                ) {
                                    if (uiState.isSaving) {
                                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                                    } else {
                                        Text(if(isSinhala) "විස්තර යාවත්කාලීන කරන්න" else "Update Details", fontSize = 16.sp, fontWeight = FontWeight.Bold)
                                    }
                                }
                            }
                        }

                        if (user.role == "CAREGIVER" || user.role == "NURSE") {
                            Spacer(modifier = Modifier.height(24.dp))
                            val isActive = user.isVerified || user.kycStatus == "APPROVED"

                            if (user.kycStatus == "REJECTED") {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)),
                                    modifier = Modifier.fillMaxWidth(),
                                    border = BorderStroke(1.dp, Color.Red)
                                ) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.Warning, contentDescription = null, tint = Color.Red, modifier = Modifier.size(24.dp))
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(if(isSinhala) "ඔබගේ KYC අයදුම්පත ප්‍රතික්ෂේප කර ඇත." else "Your KYC application was rejected.", color = Color.Red, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                        }
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text("${if(isSinhala) "හේතුව:" else "Reason:"} ${user.rejectionReason.ifEmpty { if(isSinhala) "ලේඛන පැහැදිලි නොවීම." else "Unclear documents." }}", color = Color(0xFF991B1B), fontSize = 14.sp)
                                        Spacer(modifier = Modifier.height(16.dp))
                                        Button(
                                            onClick = onNavigateToVerification,
                                            modifier = Modifier.fillMaxWidth(),
                                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                                        ) {
                                            Text(if(isSinhala) "නැවත අයදුම් කරන්න" else "Re-submit KYC", fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }
                            } else if (!isActive && user.nicNumber.isNotEmpty() && user.kycStatus == "PENDING") {
                                if (user.kycMeetingStatus == "SCHEDULED" && user.kycMeetingDateMs != null) {
                                    val meetingDate = SimpleDateFormat("yyyy MMM dd - hh:mm a", Locale.getDefault()).format(Date(user.kycMeetingDateMs))
                                    Card(
                                        colors = CardDefaults.cardColors(containerColor = Color(0xFFE0F2FE)),
                                        modifier = Modifier.fillMaxWidth(),
                                        border = BorderStroke(1.dp, Color(0xFF0284C7))
                                    ) {
                                        Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                            Text(
                                                text = if(isSinhala) "ඔබගේ KYC සම්මුඛ පරීක්ෂණය වෙන් කර ඇත" else "KYC Video Interview Scheduled",
                                                color = Color(0xFF0284C7), fontWeight = FontWeight.Bold, textAlign = TextAlign.Center
                                            )
                                            Spacer(modifier = Modifier.height(8.dp))
                                            Text(meetingDate, color = Color(0xFF0C4A6E), fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                                            Spacer(modifier = Modifier.height(12.dp))
                                            Button(
                                                onClick = {
                                                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(user.kycMeetingUrl))
                                                    context.startActivity(intent)
                                                },
                                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0284C7))
                                            ) {
                                                Text(if(isSinhala) "වීඩියෝ කෝල් එකට සම්බන්ධ වන්න" else "Join Video Call")
                                            }
                                        }
                                    }
                                } else {
                                    Card(
                                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF3C7)),
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                            Text(
                                                text = if(isSinhala) "ඔබගේ ගිණුම Admin අනුමැතිය සඳහා යොමු කර ඇත. සම්මුඛ පරීක්ෂණයක් සඳහා දිනයක් ලැබෙන තෙක් රැඳී සිටින්න." else "Your account is pending Admin approval. Please wait for an interview schedule.",
                                                color = Color(0xFFD97706), fontWeight = FontWeight.Bold, textAlign = TextAlign.Center
                                            )
                                        }
                                    }
                                }
                            } else if (!isActive) {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(
                                            text = if(isSinhala) "ඔබගේ ගිණුම තවමත් තහවුරු කර නොමැත." else "Your account is not verified yet.",
                                            color = Color.Red, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center
                                        )
                                        Spacer(modifier = Modifier.height(12.dp))
                                        Button(
                                            onClick = onNavigateToVerification,
                                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                                        ) {
                                            Text(if(isSinhala) "ගිණුම තහවුරු කරන්න" else "Verify Account")
                                        }
                                    }
                                }
                            }
                        }

                        if (user.role == "CLIENT") {
                            Spacer(modifier = Modifier.height(24.dp))
                            if (user.kycStatus == "REJECTED") {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)),
                                    modifier = Modifier.fillMaxWidth(),
                                    border = BorderStroke(1.dp, Color.Red)
                                ) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Text(if(isSinhala) "ඔබගේ අනන්‍යතා තහවුරු කිරීම ප්‍රතික්ෂේප කර ඇත. කරුණාකර නැවත උත්සාහ කරන්න." else "Your KYC was rejected. Please try again.", color = Color.Red, fontWeight = FontWeight.Bold)
                                        Spacer(modifier = Modifier.height(12.dp))
                                        Button(
                                            onClick = onNavigateToClientKyc,
                                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                                        ) {
                                            Text(if(isSinhala) "නැවත තහවුරු කරන්න" else "Re-verify KYC")
                                        }
                                    }
                                }
                            } else if (user.kycStatus == "APPROVED" && !user.isVerified) {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)),
                                    modifier = Modifier.fillMaxWidth(),
                                    border = BorderStroke(1.dp, Color(0xFF0EA5E9))
                                ) {
                                    Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(if(isSinhala) "ඔබගේ ගිණුම අනුමත කර ඇත! 🎉" else "Account Approved! 🎉", color = Color(0xFF0D3B66), fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text(
                                            if(isSinhala) "සේවාවන් ලබා ගැනීම ආරම්භ කිරීමට කරුණාකර රු. ${uiState.registrationFee.toInt()} ක ලියාපදිංචි ගාස්තුව ගෙවන්න." else "Please pay the registration fee of Rs. ${uiState.registrationFee.toInt()} to activate your account.",
                                            color = Color.Gray, fontSize = 13.sp, textAlign = TextAlign.Center
                                        )
                                        Spacer(modifier = Modifier.height(16.dp))
                                        Button(
                                            onClick = { showRegistrationFeeDialog = true },
                                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9)),
                                            modifier = Modifier.fillMaxWidth().height(50.dp)
                                        ) {
                                            Text(if(isSinhala) "ලියාපදිංචි ගාස්තුව ගෙවන්න" else "Pay Registration Fee", fontWeight = FontWeight.Bold, fontSize = 16.sp)
                                        }
                                    }
                                }
                            } else if (!user.isVerified && user.nicNumber.isNotEmpty() && user.kycStatus == "PENDING") {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF3C7)),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(
                                            if(isSinhala) "අනන්‍යතා තහවුරු කිරීම අනුමැතිය සඳහා යොමු කර ඇත. (Pending)" else "KYC is pending Admin approval.",
                                            color = Color(0xFFD97706), fontWeight = FontWeight.Bold, textAlign = TextAlign.Center
                                        )
                                    }
                                }
                            } else if (!user.isVerified) {
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)),
                                    modifier = Modifier.fillMaxWidth(),
                                    border = BorderStroke(1.dp, Color(0xFF0EA5E9))
                                ) {
                                    Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                        Text(
                                            if(isSinhala) "ආරක්ෂාව තහවුරු කිරීම සඳහා කරුණාකර ඔබගේ අනන්‍යතාවය (KYC) තහවුරු කරන්න." else "Please verify your identity (KYC) for security.",
                                            color = Color(0xFF0D3B66), fontWeight = FontWeight.Bold, textAlign = TextAlign.Center
                                        )
                                        Spacer(modifier = Modifier.height(12.dp))
                                        Button(
                                            onClick = onNavigateToClientKyc,
                                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9))
                                        ) {
                                            Text(if(isSinhala) "අනන්‍යතාවය තහවුරු කරන්න" else "Verify KYC")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        if (showRegistrationFeeDialog) {
            AlertDialog(
                onDismissRequest = { if(!isProcessingFee) { showRegistrationFeeDialog = false; feeReceiptUri = null } },
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Person, contentDescription = null, tint = Color(0xFF1A5276))
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(if(isSinhala) "ලියාපදිංචි ගාස්තුව ගෙවීම" else "Pay Registration Fee", color = Color(0xFF1A5276), fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                    }
                },
                text = {
                    Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                        Text(if(isSinhala) "ඔබගේ ගිණුම සක්‍රීය කිරීමට ගාස්තුව ගෙවන්න" else "Pay the fee to activate your account", color = Color.Gray, fontSize = 12.sp)
                        Text("Rs. ${String.format(Locale.US, "%,.2f", uiState.registrationFee)}", fontWeight = FontWeight.ExtraBold, color = Color(0xFF047857), fontSize = 24.sp, modifier = Modifier.padding(bottom=16.dp))

                        Card(
                            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                            colors = CardDefaults.cardColors(containerColor = Color(0xFFF1F5F9))
                        ) {
                            Column(modifier = Modifier.padding(12.dp)) {
                                Text(if(isSinhala) "අපගේ බැංකු ගිණුම් විස්තර:" else "Our Bank Details:", fontWeight = FontWeight.Bold, fontSize = 13.sp, color = Color.DarkGray)
                                Spacer(modifier = Modifier.height(4.dp))
                                Text("Bank: Seylan Bank", fontSize = 13.sp)
                                Text("Account Name: Golden Hand", fontSize = 13.sp)
                                Text("Account No: 14 901 361 84 8000 1", fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF1A5276))
                                Text("Branch: Katugasthota", fontSize = 13.sp)
                            }
                        }

                        Text(if(isSinhala) "මුදල් ගෙවා රිසිට්පත මෙහි අප්ලෝඩ් කරන්න:" else "Upload your payment receipt here:", fontSize = 13.sp, fontWeight = FontWeight.Medium)
                        Spacer(modifier = Modifier.height(8.dp))

                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(140.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .border(1.dp, Color.Gray, RoundedCornerShape(12.dp))
                                .background(Color.White)
                                .clickable { feeReceiptLauncher.launch("image/*") },
                            contentAlignment = Alignment.Center
                        ) {
                            if (feeReceiptUri != null) {
                                AsyncImage(
                                    model = feeReceiptUri,
                                    contentDescription = "Receipt Image",
                                    contentScale = ContentScale.Crop,
                                    modifier = Modifier.fillMaxSize()
                                )
                            } else {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Icon(Icons.Default.Add, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(32.dp))
                                    Spacer(modifier = Modifier.height(8.dp))
                                    Text(if(isSinhala) "රිසිට්පත තෝරන්න (Tap here)" else "Tap to select receipt", color = Color.Gray, fontSize = 12.sp)
                                }
                            }
                        }
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (feeReceiptUri == null) {
                                Toast.makeText(context, if(isSinhala) "කරුණාකර රිසිට්පත අප්ලෝඩ් කරන්න" else "Please upload the payment receipt", Toast.LENGTH_SHORT).show()
                                return@Button
                            }

                            isProcessingFee = true
                            viewModel.payRegistrationFee { success, msg ->
                                isProcessingFee = false
                                val displayMsg = if(success) {
                                    if(isSinhala) "රිසිට්පත ලැබුණි! Admin අනුමත කළ පසු ගිණුම සක්‍රීය වේ." else "Receipt received! Account will be active after Admin approval."
                                } else { msg }

                                Toast.makeText(context, displayMsg, Toast.LENGTH_LONG).show()

                                if(success) {
                                    showRegistrationFeeDialog = false
                                    feeReceiptUri = null
                                }
                            }
                        },
                        enabled = !isProcessingFee,
                        modifier = Modifier.fillMaxWidth().height(50.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9))
                    ) {
                        if (isProcessingFee) {
                            CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                        } else {
                            Text(if(isSinhala) "රිසිට්පත යවන්න" else "Submit Receipt", fontWeight = FontWeight.Bold)
                        }
                    }
                },
                dismissButton = {
                    if (!isProcessingFee) {
                        TextButton(onClick = { showRegistrationFeeDialog = false; feeReceiptUri = null }) {
                            Text(if(isSinhala) "අවලංගු කරන්න" else "Cancel", color = Color.Gray)
                        }
                    }
                }
            )
        }

        if (showLeaveDialog) {
            AlertDialog(
                onDismissRequest = { showLeaveDialog = false },
                title = { Text(if(isSinhala) "නිවාඩු ඉල්ලුම් පත්‍රය" else "Leave Request", fontWeight = FontWeight.Bold, color = Color(0xFF1A5276)) },
                text = {
                    Column {
                        OutlinedButton(onClick = { pickLeaveDate() }, modifier = Modifier.fillMaxWidth()) {
                            Icon(Icons.Default.DateRange, contentDescription = null, modifier = Modifier.padding(end=8.dp))
                            Text(selectedLeaveDateStr)
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedTextField(
                            value = leaveReason,
                            onValueChange = { leaveReason = it },
                            label = { Text(if(isSinhala) "හේතුව" else "Reason") },
                            modifier = Modifier.fillMaxWidth().height(100.dp),
                            maxLines = 3
                        )
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (selectedLeaveDateMs == 0L || leaveReason.isEmpty()) {
                                Toast.makeText(context, if(isSinhala) "කරුණාකර දිනයක් සහ හේතුවක් ලබා දෙන්න" else "Please provide date and reason", Toast.LENGTH_SHORT).show()
                            } else {
                                viewModel.requestLeave(selectedLeaveDateMs, leaveReason) { success, msg ->
                                    Toast.makeText(context, msg, Toast.LENGTH_LONG).show()
                                    if (success) { showLeaveDialog = false }
                                }
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A5276))
                    ) { Text(if(isSinhala) "ඉල්ලුම් කරන්න" else "Submit") }
                },
                dismissButton = {
                    TextButton(onClick = { showLeaveDialog = false }) {
                        Text(if(isSinhala) "අවලංගු කරන්න" else "Cancel", color = Color.Gray)
                    }
                }
            )
        }
    }
}

private fun convertBase64ToBitmap(base64Str: String): Bitmap? {
    return try {
        val pureBase64 = base64Str.substringAfter("base64,")
        val decodedBytes = Base64.decode(pureBase64, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)
    } catch (e: Exception) {
        e.printStackTrace()
        null
    }
}

suspend fun compressImageUriToBase64(context: android.content.Context, uri: Uri): String? {
    return withContext(Dispatchers.IO) {
        try {
            val ins = context.contentResolver.openInputStream(uri)
            val bmp = BitmapFactory.decodeStream(ins) ?: return@withContext null
            val scale = min(400f / bmp.width, 400f / bmp.height)
            val scaled = Bitmap.createScaledBitmap(bmp, (bmp.width * scale).roundToInt(), (bmp.height * scale).roundToInt(), true)
            val os = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.JPEG, 60, os)
            "data:image/jpeg;base64,${Base64.encodeToString(os.toByteArray(), Base64.DEFAULT)}"
        } catch (e: Exception) {
            null
        }
    }
}