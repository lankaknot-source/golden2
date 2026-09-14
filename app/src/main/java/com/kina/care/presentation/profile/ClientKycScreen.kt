package com.kina.care.presentation.profile

import android.Manifest
import android.app.DatePickerDialog // 🌟 අලුත්: Date Picker සඳහා
import android.content.pm.PackageManager
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kina.care.presentation.util.LocalIsSinhala
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClientKycScreen(
    onBackClick: () -> Unit,
    viewModel: ClientKycViewModel = viewModel()
) {
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()
    val isSinhala = LocalIsSinhala.current.value

    var nicNumber by remember { mutableStateOf("") }
    var dob by remember { mutableStateOf("") } // 🌟 අලුත්: Date of Birth State එක
    var homeAddress by remember { mutableStateOf("") }
    var serviceAddress by remember { mutableStateOf("") }
    var billingName by remember { mutableStateOf("") }
    var billingAddress by remember { mutableStateOf("") }
    var isAgreed by remember { mutableStateOf(false) }

    var nicFrontUri by remember { mutableStateOf<Uri?>(null) }
    var nicBackUri by remember { mutableStateOf<Uri?>(null) }
    var selfieUri by remember { mutableStateOf<Uri?>(null) }

    var currentTempUri by remember { mutableStateOf<Uri?>(null) }
    var currentCaptureAction by remember { mutableStateOf(0) }
    val calendar = Calendar.getInstance()

    fun getTempUri(): Uri {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFile = File.createTempFile("JPEG_${timeStamp}_", ".jpg", File(context.cacheDir, "images").apply { mkdirs() })
        return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", imageFile)
    }

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success) {
            when (currentCaptureAction) {
                1 -> nicFrontUri = currentTempUri
                2 -> nicBackUri = currentTempUri
                3 -> selfieUri = currentTempUri
            }
        }
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
        if (isGranted) {
            currentTempUri = getTempUri(); launcher.launch(currentTempUri!!)
        } else { Toast.makeText(context, "කැමරා අවසරය අවශ්‍යයි!", Toast.LENGTH_SHORT).show() }
    }

    fun capturePhoto(actionId: Int) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            currentCaptureAction = actionId; currentTempUri = getTempUri(); launcher.launch(currentTempUri!!)
        } else {
            currentCaptureAction = actionId; cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    LaunchedEffect(uiState.uploadSuccess) {
        if (uiState.uploadSuccess) {
            Toast.makeText(context, if(isSinhala) "සාර්ථකව යවන ලදී! පරිපාලක අනුමැතිය ලැබෙන තෙක් රැඳී සිටින්න." else "Submitted successfully! Await admin approval.", Toast.LENGTH_LONG).show()
            onBackClick()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if(isSinhala) "සේවාදායක තහවුරු කිරීම" else "Client Verification", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp) },
                navigationIcon = { IconButton(onClick = onBackClick) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF0D3B66))
            )
        }
    ) { paddingValues ->
        Column(modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC)).padding(paddingValues).verticalScroll(rememberScrollState()).padding(20.dp)) {

            Text(if(isSinhala) "අනන්‍යතා තහවුරු කිරීම (Identity Verification)" else "Identity Verification", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), modifier = Modifier.padding(bottom=16.dp))
            OutlinedTextField(value = nicNumber, onValueChange = { nicNumber = it }, label = { Text("NIC / Passport Number") }, modifier = Modifier.fillMaxWidth())

            // 🌟 අලුත්: උපන්දිනය තෝරාගැනීමේ කොටස
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedButton(
                onClick = {
                    DatePickerDialog(context, { _, year, month, day ->
                        val m = (month + 1).toString().padStart(2, '0')
                        val d = day.toString().padStart(2, '0')
                        dob = "$year-$m-$d"
                    }, calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH), calendar.get(Calendar.DAY_OF_MONTH)).show()
                },
                modifier = Modifier.fillMaxWidth().height(55.dp),
                shape = RoundedCornerShape(4.dp)
            ) {
                Text(
                    text = if (dob.isEmpty()) (if (isSinhala) "උපන් දිනය තෝරන්න (Date of Birth)" else "Select Date of Birth") else "Date of Birth: $dob",
                    color = Color(0xFF0D3B66)
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
            Text("NIC / Passport Photos", fontWeight = FontWeight.Bold, color = Color.Gray)
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(top=8.dp)) {
                Box(modifier = Modifier.weight(1f)) { PhotoCaptureBox(nicFrontUri, "Front Photo") { capturePhoto(1) } }
                Box(modifier = Modifier.weight(1f)) { PhotoCaptureBox(nicBackUri, "Back Photo") { capturePhoto(2) } }
            }
            Spacer(modifier = Modifier.height(12.dp))
            Text("Selfie Verification", fontWeight = FontWeight.Bold, color = Color.Gray)
            PhotoCaptureBox(selfieUri, "Take a Selfie") { capturePhoto(3) }

            Spacer(modifier = Modifier.height(24.dp))
            Text(if(isSinhala) "ලිපිනය සහ බිල්පත් විස්තර" else "Address & Billing Details", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), modifier = Modifier.padding(bottom=16.dp))
            OutlinedTextField(value = homeAddress, onValueChange = { homeAddress = it }, label = { Text("Home Address") }, modifier = Modifier.fillMaxWidth(), maxLines = 2)
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedTextField(value = serviceAddress, onValueChange = { serviceAddress = it }, label = { Text("Service Address (If different)") }, modifier = Modifier.fillMaxWidth(), maxLines = 2)
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedTextField(value = billingName, onValueChange = { billingName = it }, label = { Text("Billing Name") }, modifier = Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(12.dp))
            OutlinedTextField(value = billingAddress, onValueChange = { billingAddress = it }, label = { Text("Billing Address") }, modifier = Modifier.fillMaxWidth(), maxLines = 2)

            Spacer(modifier = Modifier.height(24.dp))
            Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)), modifier = Modifier.fillMaxWidth()) {
                Text(
                    "I confirm that the information provided is correct and I agree to the Golden Hand Caregivers terms & conditions and payment policy.",
                    fontSize = 13.sp, modifier = Modifier.padding(16.dp), color = Color(0xFF1E3A8A), textAlign = TextAlign.Center
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Checkbox(checked = isAgreed, onCheckedChange = { isAgreed = it })
                Text("I Agree (මම එකඟ වෙමි)", fontWeight = FontWeight.Bold)
            }

            if (uiState.errorMessage != null) {
                Text(text = uiState.errorMessage!!, color = Color.Red, fontSize = 14.sp, modifier = Modifier.padding(top=16.dp))
            }

            Spacer(modifier = Modifier.height(24.dp))
            Button(
                onClick = {
                    if (isAgreed && nicNumber.isNotEmpty() && dob.isNotEmpty() && homeAddress.isNotEmpty()) {
                        viewModel.submitClientKyc(context, nicNumber, dob, homeAddress, serviceAddress, billingName, billingAddress, nicFrontUri, nicBackUri, selfieUri)
                    } else { Toast.makeText(context, "Please fill all required details and agree to terms.", Toast.LENGTH_SHORT).show() }
                },
                modifier = Modifier.fillMaxWidth().height(55.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981)),
                enabled = !uiState.isUploading,
                shape = RoundedCornerShape(12.dp)
            ) {
                if (uiState.isUploading) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                else Text("Submit KYC", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(modifier = Modifier.height(32.dp))
        }
    }
}