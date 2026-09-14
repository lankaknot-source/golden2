package com.kina.care.presentation.log

import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.firebase.auth.FirebaseAuth
import com.kina.care.domain.model.DailyCareLog
import com.kina.care.presentation.util.LocalIsSinhala
import java.text.SimpleDateFormat
import java.util.*
import kotlinx.coroutines.launch
import com.kina.care.presentation.log.PdfGenerator
import androidx.compose.material.icons.filled.List

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CareLogScreen(
    bookingId: String,
    elderId: String,
    onBackClick: () -> Unit,
    viewModel: CareLogViewModel = viewModel()
) {
    val isSinhala = LocalIsSinhala.current.value
    val context = LocalContext.current
    val currentUserId = FirebaseAuth.getInstance().currentUser?.uid
    
    val logs by viewModel.logs.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    
    var showAddDialog by remember { mutableStateOf(false) }
    var isGeneratingPdf by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    
    LaunchedEffect(bookingId) {
        viewModel.loadLogsForBooking(bookingId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isSinhala) "දෛනික වාර්තා" else "Daily Care Log", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White) }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF1A5276)),
                actions = {
                    if (logs.isNotEmpty()) {
                        IconButton(onClick = {
                            coroutineScope.launch {
                                isGeneratingPdf = true
                                val file = PdfGenerator.generateCareLogPdf(context, logs, "Patient_${elderId.take(4)}")
                                isGeneratingPdf = false
                                if (file != null) {
                                    Toast.makeText(context, if(isSinhala) "වාර්තාව බාගත විය (Downloads)" else "PDF saved in Downloads", Toast.LENGTH_LONG).show()
                                } else {
                                    Toast.makeText(context, if(isSinhala) "දෝෂයකි" else "Error generating PDF", Toast.LENGTH_SHORT).show()
                                }
                            }
                        }) {
                            if (isGeneratingPdf) {
                                CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
                            } else {
                                Icon(androidx.compose.material.icons.Icons.Default.List, contentDescription = "Download PDF", tint = Color.White)
                            }
                        }
                    }
                }
            )
        },
        floatingActionButton = {
            // Only caregivers should add logs
            if (logs.firstOrNull()?.caregiverId == currentUserId || logs.isEmpty()) {
                FloatingActionButton(onClick = { showAddDialog = true }, containerColor = Color(0xFF10B981), contentColor = Color.White) {
                    Icon(Icons.Default.Add, contentDescription = "Add Log")
                }
            }
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF4F8FB)).padding(paddingValues)) {
            if (isLoading && logs.isEmpty()) {
                CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = Color(0xFF1A5276))
            } else if (logs.isEmpty()) {
                Text(
                    text = if (isSinhala) "දැනට වාර්තා කිසිවක් නොමැත." else "No care logs available.",
                    modifier = Modifier.align(Alignment.Center), color = Color.Gray
                )
            } else {
                LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    items(logs) { log ->
                        CareLogCard(log, isSinhala)
                    }
                }
            }
        }
        
        if (showAddDialog) {
            AddLogDialog(
                isSinhala = isSinhala,
                onDismiss = { showAddDialog = false },
                onSubmit = { bp, sugar, temp, meal, med, notes ->
                    viewModel.addLog(bookingId, elderId, bp, sugar, temp, meal, med, notes) { success, msg ->
                        Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                        if (success) showAddDialog = false
                    }
                }
            )
        }
    }
}

@Composable
fun CareLogCard(log: DailyCareLog, isSinhala: Boolean) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            val dateStr = SimpleDateFormat("MMM dd, hh:mm a", Locale.getDefault()).format(Date(log.timestamp))
            Text(text = dateStr, fontSize = 12.sp, color = Color.Gray, fontWeight = FontWeight.Bold)
            Spacer(modifier = Modifier.height(8.dp))
            
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Column {
                    Text(if (isSinhala) "රුධිර පීඩනය: ${log.bloodPressure}" else "BP: ${log.bloodPressure}", fontSize = 14.sp, color = Color(0xFF1E293B))
                    Text(if (isSinhala) "සීනි මට්ටම: ${log.sugarLevel}" else "Sugar: ${log.sugarLevel}", fontSize = 14.sp, color = Color(0xFF1E293B))
                }
                Column {
                    Text(if (isSinhala) "උෂ්ණත්වය: ${log.temperature}" else "Temp: ${log.temperature}", fontSize = 14.sp, color = Color(0xFF1E293B))
                    Text(if (isSinhala) "ආහාර: ${log.mealStatus}" else "Meal: ${log.mealStatus}", fontSize = 14.sp, color = Color(0xFF1E293B))
                }
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = if (log.medicationGiven) Color(0xFF10B981) else Color.Gray, modifier = Modifier.size(16.dp))
                Spacer(modifier = Modifier.width(4.dp))
                Text(if (isSinhala) "බෙහෙත් ලබා දුණි" else "Medication Given", fontSize = 14.sp, color = if (log.medicationGiven) Color(0xFF10B981) else Color.Gray)
            }
            
            if (log.notes.isNotEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(if (isSinhala) "සටහන: ${log.notes}" else "Notes: ${log.notes}", fontSize = 14.sp, color = Color(0xFF475569))
            }
        }
    }
}

@Composable
fun AddLogDialog(isSinhala: Boolean, onDismiss: () -> Unit, onSubmit: (String, String, String, String, Boolean, String) -> Unit) {
    var bp by remember { mutableStateOf("") }
    var sugar by remember { mutableStateOf("") }
    var temp by remember { mutableStateOf("") }
    var meal by remember { mutableStateOf("") }
    var med by remember { mutableStateOf(false) }
    var notes by remember { mutableStateOf("") }
    
    var isSubmitting by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (isSinhala) "නව වාර්තාවක් එක්කරන්න" else "Add New Log", fontWeight = FontWeight.Bold) },
        text = {
            Column {
                OutlinedTextField(value = bp, onValueChange = { bp = it }, label = { Text("Blood Pressure (e.g. 120/80)") }, modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp), singleLine = true)
                OutlinedTextField(value = sugar, onValueChange = { sugar = it }, label = { Text("Sugar Level (e.g. 100 mg/dL)") }, modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp), singleLine = true)
                OutlinedTextField(value = temp, onValueChange = { temp = it }, label = { Text("Temperature (e.g. 98.6 F)") }, modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp), singleLine = true)
                OutlinedTextField(value = meal, onValueChange = { meal = it }, label = { Text("Meal Status (e.g. Ate well)") }, modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp), singleLine = true)
                
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
                    Checkbox(checked = med, onCheckedChange = { med = it }, colors = CheckboxDefaults.colors(checkedColor = Color(0xFF10B981)))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(if (isSinhala) "බෙහෙත් ලබා දුන්නාද?" else "Medication Given?")
                }
                
                OutlinedTextField(value = notes, onValueChange = { notes = it }, label = { Text("Notes / Observations") }, modifier = Modifier.fillMaxWidth().height(100.dp), maxLines = 3)
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    isSubmitting = true
                    onSubmit(bp, sugar, temp, meal, med, notes)
                },
                enabled = !isSubmitting,
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981))
            ) { Text(if (isSinhala) "සුරකින්න" else "Save") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(if (isSinhala) "අවලංගු කරන්න" else "Cancel") }
        }
    )
}
