package com.kina.care.presentation.profile

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.kina.care.presentation.util.LocalIsSinhala
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CaregiverVerificationScreen(
    onBackClick: () -> Unit,
    viewModel: CaregiverKycViewModel = viewModel()
) {
    val context = LocalContext.current
    val uiState by viewModel.uiState.collectAsState()
    val isSinhala = LocalIsSinhala.current.value

    // --- State Variables for All Steps ---
    var nicNumber by remember { mutableStateOf("") }
    var dob by remember { mutableStateOf("") }
    var gender by remember { mutableStateOf("Male") }
    var address by remember { mutableStateOf("") }

    var experience by remember { mutableStateOf("") }
    var skills by remember { mutableStateOf("") }
    var vaccination by remember { mutableStateOf("") }
    var illnesses by remember { mutableStateOf("") }

    var bankName by remember { mutableStateOf("") }
    var accNo by remember { mutableStateOf("") }
    var branch by remember { mutableStateOf("") }
    var expectedSalary by remember { mutableStateOf("") }

    var isLiveIn by remember { mutableStateOf(false) }
    var isLiveOut by remember { mutableStateOf(false) }
    var isAgreed by remember { mutableStateOf(false) }

    // --- Images URIs ---
    var nicFrontUri by remember { mutableStateOf<Uri?>(null) }
    var nicBackUri by remember { mutableStateOf<Uri?>(null) }
    var selfieUri by remember { mutableStateOf<Uri?>(null) }
    var policeUri by remember { mutableStateOf<Uri?>(null) }
    var certUri by remember { mutableStateOf<Uri?>(null) }
    var bankBookUri by remember { mutableStateOf<Uri?>(null) }

    // --- Camera Logic ---
    fun getTempUri(): Uri {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFile = File.createTempFile("JPEG_${timeStamp}_", ".jpg", File(context.cacheDir, "images").apply { mkdirs() })
        return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", imageFile)
    }

    var currentTempUri by remember { mutableStateOf<Uri?>(null) }
    var currentCaptureAction by remember { mutableStateOf(0) }

    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success) {
            when (currentCaptureAction) {
                1 -> nicFrontUri = currentTempUri
                2 -> nicBackUri = currentTempUri
                3 -> selfieUri = currentTempUri
                4 -> policeUri = currentTempUri
                5 -> certUri = currentTempUri
                6 -> bankBookUri = currentTempUri
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
                title = { Text(if(isSinhala) "ගිණුම් සත්‍යාපනය (KYC)" else "KYC Verification", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 18.sp) },
                navigationIcon = { IconButton(onClick = onBackClick) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF0EA5E9))
            )
        }
    ) { paddingValues ->
        Column(modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC)).padding(paddingValues)) {

            // Progress Indicator
            Row(modifier = Modifier.fillMaxWidth().background(Color.White).padding(vertical = 16.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                StepIndicator(step = 1, currentStep = uiState.currentStep, title = "Personal")
                StepIndicator(step = 2, currentStep = uiState.currentStep, title = "Professional")
                StepIndicator(step = 3, currentStep = uiState.currentStep, title = "Bank")
                StepIndicator(step = 4, currentStep = uiState.currentStep, title = "Submit")
            }
            Divider(color = Color(0xFFF1F5F9))

            Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp)) {

                when (uiState.currentStep) {
                    1 -> {
                        Text(if(isSinhala) "පියවර 1: පුද්ගලික තොරතුරු" else "Step 1: Personal Info", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), modifier = Modifier.padding(bottom=16.dp))
                        OutlinedTextField(value = nicNumber, onValueChange = { nicNumber = it }, label = { Text("ජාතික හැඳුනුම්පත් අංකය (NIC)") }, modifier = Modifier.fillMaxWidth())
                        Spacer(modifier = Modifier.height(12.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            OutlinedTextField(value = dob, onValueChange = { dob = it }, label = { Text("උපන් දිනය") }, modifier = Modifier.weight(1f))
                            OutlinedTextField(value = gender, onValueChange = { gender = it }, label = { Text("ස්ත්‍රී/පුරුෂ") }, modifier = Modifier.weight(1f))
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedTextField(value = address, onValueChange = { address = it }, label = { Text("ස්ථිර ලිපිනය") }, modifier = Modifier.fillMaxWidth(), maxLines = 3)

                        Spacer(modifier = Modifier.height(24.dp))
                        Text("හැඳුනුම්පත් ඡායාරූප", fontWeight = FontWeight.Bold)
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(top=8.dp)) {
                            Box(modifier = Modifier.weight(1f)) { PhotoCaptureBox(nicFrontUri, "ඉදිරිපස (Front)") { capturePhoto(1) } }
                            Box(modifier = Modifier.weight(1f)) { PhotoCaptureBox(nicBackUri, "පිටුපස (Back)") { capturePhoto(2) } }
                        }
                        Spacer(modifier = Modifier.height(12.dp))
                        Text("ඔබගේ ඡායාරූපයක් (Selfie with NIC)", fontWeight = FontWeight.Bold)
                        PhotoCaptureBox(selfieUri, "Selfie ඡායාරූපය") { capturePhoto(3) }
                    }

                    2 -> {
                        Text(if(isSinhala) "පියවර 2: වෘත්තීය සහ සෞඛ්‍ය" else "Step 2: Professional & Health", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), modifier = Modifier.padding(bottom=16.dp))
                        OutlinedTextField(value = experience, onValueChange = { experience = it }, label = { Text("පළපුරුද්ද (අවුරුදු)") }, modifier = Modifier.fillMaxWidth())
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedTextField(value = skills, onValueChange = { skills = it }, label = { Text("විශේෂ හැකියාවන් (Special Skills)") }, modifier = Modifier.fillMaxWidth(), maxLines = 2)
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedTextField(value = illnesses, onValueChange = { illnesses = it }, label = { Text("නිදන්ගත රෝග ඇත්නම් (Chronic Illnesses)") }, modifier = Modifier.fillMaxWidth())
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedTextField(value = vaccination, onValueChange = { vaccination = it }, label = { Text("එන්නත් විස්තර (Vaccination Status)") }, modifier = Modifier.fillMaxWidth())

                        Spacer(modifier = Modifier.height(24.dp))
                        Text("වාර්තා උඩුගත කිරීම", fontWeight = FontWeight.Bold)
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.padding(top=8.dp)) {
                            Box(modifier = Modifier.weight(1f)) { PhotoCaptureBox(policeUri, "පොලිස් වාර්තාව") { capturePhoto(4) } }
                            Box(modifier = Modifier.weight(1f)) { PhotoCaptureBox(certUri, "පුහුණු සහතිකය") { capturePhoto(5) } }
                        }
                    }

                    3 -> {
                        Text(if(isSinhala) "පියවර 3: බැංකු සහ සේවා විස්තර" else "Step 3: Bank & Services", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), modifier = Modifier.padding(bottom=16.dp))
                        OutlinedTextField(value = bankName, onValueChange = { bankName = it }, label = { Text("බැංකුවේ නම") }, modifier = Modifier.fillMaxWidth())
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedTextField(value = accNo, onValueChange = { accNo = it }, label = { Text("ගිණුම් අංකය") }, modifier = Modifier.fillMaxWidth())
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedTextField(value = branch, onValueChange = { branch = it }, label = { Text("ශාඛාව (Branch)") }, modifier = Modifier.fillMaxWidth())
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedTextField(value = expectedSalary, onValueChange = { expectedSalary = it }, label = { Text("බලාපොරොත්තු වන වැටුප/පැයකට (Rs.)") }, modifier = Modifier.fillMaxWidth())

                        Spacer(modifier = Modifier.height(16.dp))
                        Text("කැමති සේවා වර්ගය", fontWeight = FontWeight.Bold)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Checkbox(checked = isLiveIn, onCheckedChange = { isLiveIn = it })
                            Text("නැවතී සේවය (Live-in)")
                            Spacer(modifier = Modifier.width(16.dp))
                            Checkbox(checked = isLiveOut, onCheckedChange = { isLiveOut = it })
                            Text("දිනපතා පැමිණීම (Live-out)")
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                        Text("බැංකු පොතේ ඡායාරූපය", fontWeight = FontWeight.Bold)
                        PhotoCaptureBox(bankBookUri, "Bank Book") { capturePhoto(6) }
                    }

                    4 -> {
                        Text(if(isSinhala) "පියවර 4: නීතිමය එකඟතාවය" else "Step 4: Legal Declaration", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), modifier = Modifier.padding(bottom=16.dp))

                        Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)), modifier = Modifier.fillMaxWidth()) {
                            Text(
                                "මා විසින් ඉහත සපයා ඇති සියලුම තොරතුරු සහ ලේඛන සත්‍ය හා නිවැරදි බවට මම මෙයින් සහතික කරමි. GOLDEN HAND CAREGIVERS හි නීති හා රෙගුලාසි වලට යටත් වීමට මා එකඟ වෙමි.",
                                fontSize = 14.sp, modifier = Modifier.padding(16.dp), color = Color(0xFF1E3A8A), textAlign = TextAlign.Center
                            )
                        }

                        Spacer(modifier = Modifier.height(24.dp))
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                            Checkbox(checked = isAgreed, onCheckedChange = { isAgreed = it })
                            Text("මම ඉහත කොන්දේසි වලට එකඟ වෙමි.", fontWeight = FontWeight.Bold)
                        }

                        if (uiState.errorMessage != null) {
                            Text(text = uiState.errorMessage!!, color = Color.Red, fontSize = 14.sp, modifier = Modifier.padding(top=16.dp))
                        }
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    if (uiState.currentStep > 1) {
                        OutlinedButton(onClick = { viewModel.setStep(uiState.currentStep - 1) }, modifier = Modifier.height(50.dp)) {
                            Text("පෙර පියවර (Back)")
                        }
                    } else { Spacer(modifier = Modifier.width(1.dp)) }

                    if (uiState.currentStep < 4) {
                        Button(onClick = { viewModel.setStep(uiState.currentStep + 1) }, modifier = Modifier.height(50.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9))) {
                            Text("ඊළඟ පියවර (Next)")
                        }
                    } else {
                        Button(
                            onClick = {
                                if (isAgreed) {
                                    val types = mutableListOf<String>()
                                    if(isLiveIn) types.add("Live-in")
                                    if(isLiveOut) types.add("Live-out")
                                    viewModel.submitKycData(
                                        context, nicNumber, dob, gender, address, experience, skills, vaccination, illnesses,
                                        bankName, accNo, branch, expectedSalary.toDoubleOrNull() ?: 0.0, types,
                                        nicFrontUri, nicBackUri, selfieUri, policeUri, certUri, bankBookUri
                                    )
                                } else {
                                    Toast.makeText(context, "කරුණාකර නීති වලට එකඟ වන්න.", Toast.LENGTH_SHORT).show()
                                }
                            },
                            modifier = Modifier.height(50.dp),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981)),
                            enabled = !uiState.isUploading
                        ) {
                            if (uiState.isUploading) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                            else Text("අවසන් කරන්න (Submit)")
                        }
                    }
                }
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}

@Composable
fun StepIndicator(step: Int, currentStep: Int, title: String) {
    val isCompleted = currentStep > step
    val isCurrent = currentStep == step
    val color = if (isCompleted || isCurrent) Color(0xFF0EA5E9) else Color(0xFFE2E8F0)

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier.size(28.dp).clip(CircleShape).background(color),
            contentAlignment = Alignment.Center
        ) {
            if (isCompleted) Icon(Icons.Default.CheckCircle, null, tint = Color.White, modifier = Modifier.size(16.dp))
            else Text(step.toString(), color = if (isCurrent) Color.White else Color.Gray, fontWeight = FontWeight.Bold, fontSize = 12.sp)
        }
        Text(title, fontSize = 10.sp, color = if(isCurrent) Color(0xFF0EA5E9) else Color.Gray, modifier = Modifier.padding(top=4.dp), fontWeight = if(isCurrent) FontWeight.Bold else FontWeight.Normal)
    }
}

@Composable
fun PhotoCaptureBox(imageUri: Uri?, label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(120.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(Color(0xFFE2E8F0))
            .border(2.dp, if (imageUri != null) Color(0xFF10B981) else Color(0xFFCBD5E1), RoundedCornerShape(12.dp))
            .clickable { onClick() },
        contentAlignment = Alignment.Center
    ) {
        if (imageUri != null) {
            AsyncImage(model = imageUri, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            Icon(Icons.Default.CheckCircle, contentDescription = "Done", tint = Color(0xFF10B981), modifier = Modifier.size(30.dp).align(Alignment.TopEnd).padding(4.dp))
        } else {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Default.Add, contentDescription = "Add", tint = Color.Gray, modifier = Modifier.size(30.dp))
                Text(label, color = Color.Gray, fontSize = 12.sp, modifier = Modifier.padding(top = 4.dp), textAlign = TextAlign.Center)
            }
        }
    }
}