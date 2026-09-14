package com.kina.care.presentation.client

import android.Manifest
import android.app.TimePickerDialog
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.Notifications
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.kina.care.domain.model.ElderProfile
import com.kina.care.presentation.util.LocalIsSinhala
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.min
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ElderProfileScreen(
    onBackClick: () -> Unit,
    viewModel: ElderProfileViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val isSinhala = LocalIsSinhala.current.value

    var showAddDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isSinhala) "වැඩිහිටි විස්තර" else "Elder Profiles", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White) }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF0EA5E9))
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { showAddDialog = true }, containerColor = Color(0xFF0EA5E9), contentColor = Color.White) {
                Icon(Icons.Default.Add, contentDescription = "Add")
            }
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC)).padding(paddingValues)) {
            when {
                uiState.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = Color(0xFF0EA5E9))
                uiState.elders.isEmpty() -> {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.align(Alignment.Center)) {
                        Icon(Icons.Default.Favorite, contentDescription = null, tint = Color.LightGray, modifier = Modifier.size(64.dp))
                        Spacer(modifier = Modifier.height(16.dp))
                        Text(text = if (isSinhala) "ඔබ තවමත් කිසිදු විස්තරයක් එකතු කර නැත." else "No profiles added yet.", color = Color.Gray, fontSize = 16.sp)
                    }
                }
                else -> {
                    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        items(uiState.elders) { elder ->
                            ElderCard(elder, isSinhala, viewModel, uiState.isSaving) { viewModel.deleteElder(elder.id) }
                        }
                    }
                }
            }
        }

        if (showAddDialog) {
            AddElderDialog(
                isSinhala = isSinhala,
                onDismiss = { showAddDialog = false },
                viewModel = viewModel,
                isSaving = uiState.isSaving
            )
        }
    }
}

@Composable
fun ElderCard(elder: ElderProfile, isSinhala: Boolean, viewModel: ElderProfileViewModel, isSaving: Boolean, onDelete: () -> Unit) {
    val context = LocalContext.current
    var showMedicineDialog by remember { mutableStateOf(false) }

    Card(
        modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White), elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(modifier = Modifier.size(48.dp).background(Color(0xFFE2E8F0), shape = RoundedCornerShape(12.dp)), contentAlignment = Alignment.Center) {
                        Icon(Icons.Default.Person, contentDescription = null, tint = Color.Gray)
                    }
                    Spacer(modifier = Modifier.width(12.dp))
                    Column {
                        Text(text = elder.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                        Text(text = "${if(isSinhala) "වයස" else "Age"}: ${elder.age} | ${elder.gender}", fontSize = 14.sp, color = Color.Gray)
                    }
                }
                IconButton(onClick = onDelete) { Icon(Icons.Default.Delete, contentDescription = "Delete", tint = Color.Red) }
            }
            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider(color = Color(0xFFF1F5F9))
            Spacer(modifier = Modifier.height(12.dp))

            Text(text = if(isSinhala) "ලෙඩ රෝග / තත්වයන්:" else "Medical Conditions:", fontSize = 12.sp, color = Color.Gray)
            Text(text = if (elder.medicalConditions.isEmpty()) (if(isSinhala) "කිසිවක් නැත" else "None") else elder.medicalConditions.joinToString(", "), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Color(0xFF0D3B66))
            Spacer(modifier = Modifier.height(8.dp))

            Text(text = if(isSinhala) "හදිසි ඇමතුම් අංකය:" else "Emergency Contact:", fontSize = 12.sp, color = Color.Gray)
            Text(text = elder.emergencyContact.ifEmpty { "N/A" }, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color(0xFF10B981))

            Spacer(modifier = Modifier.height(12.dp))
            HorizontalDivider(color = Color(0xFFF1F5F9))
            Spacer(modifier = Modifier.height(8.dp))

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(text = if(isSinhala) "ඖෂධ සිහිකැඳවීම් (Medicines)" else "Medicine Reminders", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B), fontSize = 14.sp)
                TextButton(onClick = { showMedicineDialog = true }) {
                    Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                    Text(if(isSinhala) "එකතු කරන්න" else "Add")
                }
            }

            if (elder.medicineList.isEmpty()) {
                Text(if(isSinhala) "ඖෂධ එකතු කර නැත." else "No medicines added.", fontSize = 12.sp, color = Color.Gray, modifier = Modifier.padding(bottom = 8.dp))
            } else {
                Column(modifier = Modifier.fillMaxWidth()) {
                    elder.medicineList.forEach { med ->
                        Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFF0FDF4)), modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                            Row(modifier = Modifier.fillMaxWidth().padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    if (med.photoBase64.isNotEmpty()) {
                                        val bmp = convertBase64ToBitmap(med.photoBase64)
                                        if(bmp != null) {
                                            Image(bitmap = bmp.asImageBitmap(), contentDescription = "Med", contentScale = ContentScale.Crop, modifier = Modifier.size(40.dp).clip(CircleShape).border(1.dp, Color(0xFF10B981), CircleShape))
                                        } else {
                                            Icon(Icons.Outlined.Notifications, null, tint = Color(0xFF10B981), modifier = Modifier.size(24.dp))
                                        }
                                    } else {
                                        Icon(Icons.Outlined.Notifications, null, tint = Color(0xFF10B981), modifier = Modifier.size(24.dp))
                                    }

                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column {
                                        Text(med.name, fontWeight = FontWeight.Bold, color = Color(0xFF047857), fontSize = 14.sp)
                                        Text(med.time, color = Color.Gray, fontSize = 12.sp)
                                    }
                                }
                                IconButton(onClick = { viewModel.removeMedicineReminder(context, elder.id, elder.medicineList, med) }, modifier = Modifier.size(24.dp)) {
                                    Icon(Icons.Default.Delete, contentDescription = "Remove", tint = Color.Red, modifier = Modifier.size(18.dp))
                                }
                            }
                        }
                    }
                }
            }
        }

        if (showMedicineDialog) {
            var medName by remember { mutableStateOf("") }
            var selectedTime by remember { mutableStateOf("08:00") }
            var medUri by remember { mutableStateOf<Uri?>(null) }
            val calendar = Calendar.getInstance()

            var tempUri by remember { mutableStateOf<Uri?>(null) }
            fun getTempUri(): Uri {
                val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
                val imageFile = File.createTempFile("MED_${timeStamp}_", ".jpg", File(context.cacheDir, "images").apply { mkdirs() })
                return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", imageFile)
            }

            val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
                if (success) medUri = tempUri
            }

            val cameraPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
                if (isGranted) { tempUri = getTempUri(); cameraLauncher.launch(tempUri!!) }
                else { Toast.makeText(context, "කැමරා අවසරය අවශ්‍යයි!", Toast.LENGTH_SHORT).show() }
            }

            AlertDialog(
                onDismissRequest = { if(!isSaving) showMedicineDialog = false },
                title = { Text(if(isSinhala) "ඖෂධය එක් කරන්න" else "Add Medicine", fontWeight = FontWeight.Bold) },
                text = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {

                        Box(
                            modifier = Modifier.size(100.dp).clip(RoundedCornerShape(12.dp)).background(Color(0xFFE2E8F0)).clickable {
                                if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
                                    tempUri = getTempUri(); cameraLauncher.launch(tempUri!!)
                                } else { cameraPermissionLauncher.launch(Manifest.permission.CAMERA) }
                            }, contentAlignment = Alignment.Center
                        ) {
                            if (medUri != null) {
                                AsyncImage(model = medUri, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                                Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF10B981), modifier = Modifier.align(Alignment.TopEnd).padding(4.dp))
                            } else {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Icon(Icons.Default.Add, null, tint = Color.Gray)
                                    Text(if(isSinhala) "ෆොටෝ එකක්" else "Add Photo", fontSize = 10.sp, color = Color.Gray)
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                        OutlinedTextField(
                            value = medName, onValueChange = { medName = it },
                            label = { Text(if(isSinhala) "ඖෂධයේ නම (උදා: Panadol)" else "Medicine Name") },
                            modifier = Modifier.fillMaxWidth(), singleLine = true
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        OutlinedButton(
                            onClick = {
                                TimePickerDialog(context, { _, hour, minute ->
                                    selectedTime = String.format("%02d:%02d", hour, minute)
                                }, calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), false).show()
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(if(isSinhala) "වේලාව: $selectedTime" else "Time: $selectedTime", color = Color(0xFF1A5276))
                        }

                        if(isSaving) {
                            Spacer(modifier = Modifier.height(12.dp))
                            CircularProgressIndicator(modifier = Modifier.size(24.dp), color = Color(0xFF10B981))
                            Text(if(isSinhala) "සකසමින් පවතී..." else "Processing...", fontSize = 12.sp, color = Color.Gray)
                        }
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (medName.isNotBlank()) {
                                viewModel.addMedicineReminderWithPhoto(context, elder.id, elder.medicineList, selectedTime, medName, medUri) { success ->
                                    if(success) showMedicineDialog = false
                                }
                            } else { Toast.makeText(context, "නමක් ලබා දෙන්න", Toast.LENGTH_SHORT).show() }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981)),
                        enabled = !isSaving
                    ) { Text(if(isSinhala) "සුරකින්න (Save)" else "Save") }
                },
                dismissButton = {
                    if(!isSaving) TextButton(onClick = { showMedicineDialog = false }) { Text(if(isSinhala) "අවලංගු කරන්න" else "Cancel") }
                }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddElderDialog(
    isSinhala: Boolean,
    onDismiss: () -> Unit,
    viewModel: ElderProfileViewModel,
    isSaving: Boolean
) {
    val context = LocalContext.current
    var name by remember { mutableStateOf("") }
    var age by remember { mutableStateOf("") }
    var gender by remember { mutableStateOf("Male") }
    var conditions by remember { mutableStateOf("") }

    // 🌟 Country Code එක Default ලෙස ලබා දී ඇත.
    var contact by remember { mutableStateOf("+94") }

    var language by remember { mutableStateOf("Sinhala") }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Color.White) {
        Column(modifier = Modifier.fillMaxWidth().padding(16.dp).padding(bottom = 32.dp)) {
            Text(if (isSinhala) "නව වැඩිහිටි විස්තරයක් එක් කරන්න" else "Add New Elder Profile", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66))
            Spacer(modifier = Modifier.height(16.dp))

            OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text(if(isSinhala) "සම්පූර්ණ නම" else "Full Name") }, modifier = Modifier.fillMaxWidth(), singleLine = true)
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = age, onValueChange = { age = it },
                label = { Text(if(isSinhala) "වයස" else "Age") },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = contact.removePrefix("+94"),
                onValueChange = { newValue ->
                    val digits = newValue.filter { it.isDigit() }.take(9)
                    contact = "+94$digits"
                },
                label = { Text(if(isSinhala) "හදිසි දුරකථන අංකය" else "Emergency Phone") },
                leadingIcon = {
                    Text(
                        text = " +94 ",
                        fontWeight = FontWeight.Bold,
                        color = Color(0xFF0D3B66),
                        modifier = Modifier.padding(start = 16.dp, end = 4.dp)
                    )
                },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone)
            )
            Spacer(modifier = Modifier.height(8.dp))

            OutlinedTextField(
                value = conditions, onValueChange = { conditions = it },
                label = { Text(if(isSinhala) "ලෙඩ රෝග (කොමා යොදා වෙන් කරන්න)" else "Medical Conditions (Comma separated)") },
                modifier = Modifier.fillMaxWidth().height(100.dp), maxLines = 3
            )
            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = {
                    if (contact.length == 12) {
                        viewModel.addElder(name, age, gender, conditions, contact, language) { success, msg ->
                            Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                            if (success) onDismiss()
                        }
                    } else {
                        Toast.makeText(context, if(isSinhala) "නිවැරදි දුරකථන අංකයක් ලබා දෙන්න (ඉලක්කම් 9ක්)" else "Enter a valid phone number (9 digits)", Toast.LENGTH_SHORT).show()
                    }
                },
                modifier = Modifier.fillMaxWidth().height(50.dp), shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9)), enabled = !isSaving
            ) {
                if (isSaving) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                else Text(if(isSinhala) "විස්තර සුරකින්න (Save)" else "Save Profile", fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    }
}

private fun convertBase64ToBitmap(base64Str: String): Bitmap? {
    return try {
        val pureBase64 = base64Str.substringAfter("base64,")
        val decodedBytes = Base64.decode(pureBase64, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)
    } catch (e: Exception) { e.printStackTrace(); null }
}