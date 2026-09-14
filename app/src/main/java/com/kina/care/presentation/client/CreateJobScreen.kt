package com.kina.care.presentation.client

import android.Manifest
import android.annotation.SuppressLint
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.kina.care.domain.model.ElderProfile
import com.kina.care.presentation.util.LocalIsSinhala
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.osmdroid.config.Configuration
import org.osmdroid.events.MapListener
import org.osmdroid.events.ScrollEvent
import org.osmdroid.events.ZoomEvent
import org.osmdroid.tileprovider.tilesource.OnlineTileSourceBase
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import java.text.SimpleDateFormat
import java.util.*

@SuppressLint("MissingPermission")
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateJobScreen(
    onBackClick: () -> Unit,
    onJobCreated: () -> Unit,
    selectedCaregiverId: String? = null,
    selectedCaregiverName: String? = null,
    viewModel: CreateJobViewModel = viewModel()
) {
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    val uiState by viewModel.uiState.collectAsState()
    val isSinhala = LocalIsSinhala.current.value

    var description by remember { mutableStateOf("") }
    var isEmergency by remember { mutableStateOf(false) }

    var selectedLat by remember { mutableStateOf(6.9271) }
    var selectedLng by remember { mutableStateOf(79.8612) }
    var locationName by remember { mutableStateOf(if(isSinhala) "සිතියමෙන් ස්ථානය තෝරන්න..." else "Select location from map...") }
    var searchLocationText by remember { mutableStateOf("") }

    var expanded by remember { mutableStateOf(false) }
    var selectedElder by remember { mutableStateOf<ElderProfile?>(null) }

    var isScheduled by remember { mutableStateOf(false) }
    val calendar = Calendar.getInstance()
    var scheduledTimeMs by remember { mutableStateOf(0L) }
    var scheduledDisplay by remember { mutableStateOf(if(isSinhala) "දිනය සහ වේලාව තෝරන්න" else "Select Date & Time") }

    var careCategory by remember { mutableStateOf("Elderly Care") }
    var categoryExpanded by remember { mutableStateOf(false) }
    val categoriesList = listOf("Elderly Care", "Patient Care", "Baby Care", "Special Needs")

    var serviceType by remember { mutableStateOf("Live-out") }
    var durationType by remember { mutableStateOf("Short-term") }

    val requestedTasks = remember { mutableStateListOf<String>() }
    var newTaskText by remember { mutableStateOf("") }

    var estimatedHoursStr by remember { mutableStateOf("1") }

    LaunchedEffect(careCategory) {
        requestedTasks.clear()
        when (careCategory) {
            "Baby Care" -> requestedTasks.addAll(listOf("Feeding", "Bathing", "Changing Diapers", "Putting to Sleep"))
            "Patient Care" -> requestedTasks.addAll(listOf("Give Medicine", "Check Vitals", "Sponge Bath", "Feeding"))
            "Special Needs" -> requestedTasks.addAll(listOf("Give Medicine", "Physical Therapy", "Assisted Walking", "Feeding"))
            else -> requestedTasks.addAll(listOf("Give Medicine", "Serve Meals", "Help with Bathing", "General Cleanup"))
        }
    }

    LaunchedEffect(selectedCaregiverId) {
        if (selectedCaregiverId != null) {
            viewModel.fetchCaregiverRate(selectedCaregiverId)
        }
    }

    LaunchedEffect(uiState.isSuccess) {
        if (uiState.isSuccess) {
            Toast.makeText(context, if(isSinhala) "රැකියා ඉල්ලීම සාර්ථකව යවන ලදී!" else "Job request sent successfully!", Toast.LENGTH_LONG).show()
            onJobCreated()
        }
    }

    LaunchedEffect(uiState.elders) { if (uiState.elders.isNotEmpty() && selectedElder == null) selectedElder = uiState.elders[0] }

    val googleStreetsSource = object : OnlineTileSourceBase(
        "GoogleStreets", 0, 20, 256, "",
        arrayOf("https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
            "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
            "https://mt2.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
            "https://mt3.google.com/vt/lyrs=m&x={x}&y={y}&z={z}")
    ) {
        override fun getTileURLString(pMapTileIndex: Long): String {
            return baseUrl.replace("{x}", org.osmdroid.util.MapTileIndex.getX(pMapTileIndex).toString())
                .replace("{y}", org.osmdroid.util.MapTileIndex.getY(pMapTileIndex).toString())
                .replace("{z}", org.osmdroid.util.MapTileIndex.getZoom(pMapTileIndex).toString())
        }
    }

    Configuration.getInstance().userAgentValue = context.packageName
    Configuration.getInstance().load(context, context.getSharedPreferences("osmdroid", Context.MODE_PRIVATE))

    val mapView = remember {
        MapView(context).apply {
            setTileSource(googleStreetsSource)
            setMultiTouchControls(true)
            controller.setZoom(16.0)
            controller.setCenter(GeoPoint(selectedLat, selectedLng))

            addMapListener(object : MapListener {
                override fun onScroll(event: ScrollEvent?): Boolean {
                    selectedLat = mapCenter.latitude
                    selectedLng = mapCenter.longitude
                    return true
                }
                override fun onZoom(event: ZoomEvent?): Boolean = false
            })
        }
    }

    LaunchedEffect(selectedLat, selectedLng) {
        delay(800)
        try {
            val geocoder = Geocoder(context, Locale.getDefault())
            @Suppress("DEPRECATION")
            val addresses = withContext(Dispatchers.IO) { geocoder.getFromLocation(selectedLat, selectedLng, 1) }
            if (!addresses.isNullOrEmpty()) {
                locationName = addresses[0].getAddressLine(0) ?: if(isSinhala) "ස්ථානය තෝරාගෙන ඇත" else "Location Selected"
            }
        } catch (e: Exception) {}
    }

    fun fetchCurrentLocation() {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            val fusedClient = LocationServices.getFusedLocationProviderClient(context)
            fusedClient.getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null).addOnSuccessListener { loc: Location? ->
                if (loc != null) {
                    mapView.controller.animateTo(GeoPoint(loc.latitude, loc.longitude))
                    mapView.controller.setZoom(18.0)
                } else {
                    Toast.makeText(context, if(isSinhala) "Location ලබාගැනීමට නොහැක. GPS On කර ඇතිදැයි බලන්න." else "Cannot get location. Check GPS.", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    val locationPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted: Boolean ->
        if (isGranted) fetchCurrentLocation() else Toast.makeText(context, if(isSinhala) "Location අවසරය ලබාදී නොමැත" else "Location permission denied", Toast.LENGTH_SHORT).show()
    }

    LaunchedEffect(Unit) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            fetchCurrentLocation()
        } else {
            locationPermissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    val performSearch = {
        if (searchLocationText.isNotEmpty()) {
            coroutineScope.launch {
                try {
                    val geocoder = Geocoder(context, Locale.getDefault())
                    @Suppress("DEPRECATION")
                    val results = withContext(Dispatchers.IO) { geocoder.getFromLocationName("$searchLocationText, Sri Lanka", 1) }
                    if (!results.isNullOrEmpty()) {
                        val loc = results[0]
                        mapView.controller.animateTo(GeoPoint(loc.latitude, loc.longitude))
                        mapView.controller.setZoom(17.0)
                    } else { Toast.makeText(context, if(isSinhala) "ස්ථානය සොයාගත නොහැක!" else "Location not found!", Toast.LENGTH_SHORT).show() }
                } catch (e: Exception) { Toast.makeText(context, if(isSinhala) "සෙවීම අසාර්ථකයි" else "Search failed", Toast.LENGTH_SHORT).show() }
            }
        }
    }

    fun pickDateTime() {
        DatePickerDialog(context, { _, year, month, day ->
            calendar.set(year, month, day)
            TimePickerDialog(context, { _, hour, minute ->
                calendar.set(Calendar.HOUR_OF_DAY, hour)
                calendar.set(Calendar.MINUTE, minute)
                scheduledTimeMs = calendar.timeInMillis
                scheduledDisplay = SimpleDateFormat("yyyy MMM dd, hh:mm a", Locale.getDefault()).format(calendar.time)
            }, calendar.get(Calendar.HOUR_OF_DAY), calendar.get(Calendar.MINUTE), false).show()
        }, calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH), calendar.get(Calendar.DAY_OF_MONTH)).apply {
            datePicker.minDate = System.currentTimeMillis() - 1000
        }.show()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if(isSinhala) "නව සේවා ඉල්ලීමක්" else "New Job Request", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = onBackClick) { Icon(Icons.AutoMirrored.Filled.ArrowBack, tint = Color.White, contentDescription = "Back") } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF1A5276))
            )
        }
    ) { paddingValues ->
        Column(modifier = Modifier.fillMaxSize().padding(paddingValues).background(Color(0xFFF4F8FB)).verticalScroll(rememberScrollState())) {

            if (selectedCaregiverName != null) {
                Card(modifier = Modifier.fillMaxWidth().padding(16.dp), colors = CardDefaults.cardColors(containerColor = Color(0xFFE3F2FD)), border = BorderStroke(1.dp, Color(0xFF85C1E9))) {
                    Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Person, contentDescription = null, tint = Color(0xFF1E6091), modifier = Modifier.size(32.dp))
                        Spacer(modifier = Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(if(isSinhala) "තෝරාගත් සේවකයා:" else "Selected Caregiver:", color = Color.Gray, fontSize = 12.sp)
                            Text(selectedCaregiverName, fontWeight = FontWeight.Bold, color = Color(0xFF1A5276), fontSize = 18.sp)
                        }

                        if (uiState.selectedCaregiverRate > 0) {
                            Column(horizontalAlignment = Alignment.End) {
                                Text(if(isSinhala) "පැයක ගාස්තුව" else "Hourly Rate", color = Color.Gray, fontSize = 10.sp)
                                Text("Rs. ${uiState.selectedCaregiverRate}", fontWeight = FontWeight.ExtraBold, color = Color(0xFF10B981), fontSize = 14.sp)
                            }
                        }
                    }
                }
            }

            Text(if(isSinhala) "සේවය අවශ්‍ය ස්ථානය තෝරන්න" else "Select Service Location", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B), modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 8.dp))

            Box(modifier = Modifier.fillMaxWidth().height(300.dp).padding(horizontal = 16.dp).clip(RoundedCornerShape(16.dp))) {

                AndroidView(factory = { mapView }, modifier = Modifier.fillMaxSize())

                Icon(Icons.Default.LocationOn, contentDescription = "Pin", tint = Color.Red, modifier = Modifier.size(48.dp).align(Alignment.Center).offset(y = (-24).dp))

                OutlinedTextField(
                    value = searchLocationText, onValueChange = { searchLocationText = it },
                    placeholder = { Text(if(isSinhala) "නගරය සෙවුම් කරන්න..." else "Search city...") },
                    modifier = Modifier.fillMaxWidth().padding(8.dp).align(Alignment.TopCenter),
                    shape = RoundedCornerShape(24.dp), colors = OutlinedTextFieldDefaults.colors(unfocusedContainerColor = Color.White.copy(alpha=0.95f), focusedContainerColor = Color.White),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search), keyboardActions = KeyboardActions(onSearch = { performSearch() }),
                    trailingIcon = { IconButton(onClick = { performSearch() }) { Icon(Icons.Default.Search, contentDescription = "Search", tint = Color(0xFF0EA5E9)) } }
                )

                FloatingActionButton(
                    onClick = {
                        if (ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) fetchCurrentLocation()
                        else locationPermissionLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION)
                    },
                    modifier = Modifier.align(Alignment.BottomEnd).padding(16.dp).size(48.dp), containerColor = Color.White, contentColor = Color(0xFF0EA5E9), shape = CircleShape
                ) { Icon(Icons.Default.Place, contentDescription = "My Location") }
            }

            Card(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), colors = CardDefaults.cardColors(containerColor = Color(0xFFE8F8F5))) {
                Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.CheckCircle, null, tint = Color(0xFF52BE80))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(locationName, fontSize = 13.sp, color = Color(0xFF1E8449), fontWeight = FontWeight.Bold)
                }
            }

            Column(modifier = Modifier.padding(16.dp).fillMaxWidth()) {

                if (selectedCaregiverName != null) {
                    Text(if(isSinhala) "සේවය අවශ්‍ය පැය ගණන" else "Required Hours", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                    Spacer(modifier = Modifier.height(8.dp))
                    OutlinedTextField(
                        value = estimatedHoursStr,
                        onValueChange = { estimatedHoursStr = it },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text(if(isSinhala) "පැය ගණන" else "Hours") },
                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Color(0xFF1A5276))
                    )

                    val hours = estimatedHoursStr.toIntOrNull() ?: 1
                    val calculatedTotal = hours * uiState.selectedCaregiverRate

                    Spacer(modifier = Modifier.height(8.dp))
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFF0FDF4)), modifier = Modifier.fillMaxWidth()) {
                        Row(modifier = Modifier.padding(16.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Text(if(isSinhala) "ඇස්තමේන්තුගත මුදල (Total)" else "Estimated Total", fontWeight = FontWeight.Bold, color = Color(0xFF047857))
                            Text("Rs. $calculatedTotal", fontSize = 20.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF047857))
                        }
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    HorizontalDivider(color = Color(0xFFE2E8F0))
                    Spacer(modifier = Modifier.height(16.dp))
                }

                Text(if(isSinhala) "කාණ්ඩය (Category)" else "Category", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                Spacer(modifier = Modifier.height(8.dp))
                ExposedDropdownMenuBox(expanded = categoryExpanded, onExpandedChange = { categoryExpanded = !categoryExpanded }) {
                    OutlinedTextField(
                        value = careCategory, onValueChange = {}, readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = categoryExpanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth(), colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors(focusedBorderColor = Color(0xFF1A5276))
                    )
                    ExposedDropdownMenu(expanded = categoryExpanded, onDismissRequest = { categoryExpanded = false }, modifier = Modifier.background(Color.White)) {
                        categoriesList.forEach { cat -> DropdownMenuItem(text = { Text(cat) }, onClick = { careCategory = cat; categoryExpanded = false }) }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(if(isSinhala) "සේවා වර්ගය" else "Service Type", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B), fontSize = 14.sp)
                        Row(verticalAlignment = Alignment.CenterVertically) { RadioButton(selected = serviceType == "Live-out", onClick = { serviceType = "Live-out" }, colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF1A5276))); Text("Live-out", fontSize = 13.sp) }
                        Row(verticalAlignment = Alignment.CenterVertically) { RadioButton(selected = serviceType == "Live-in", onClick = { serviceType = "Live-in" }, colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF1A5276))); Text("Live-in", fontSize = 13.sp) }
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(if(isSinhala) "කාලය (Duration)" else "Duration", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B), fontSize = 14.sp)
                        Row(verticalAlignment = Alignment.CenterVertically) { RadioButton(selected = durationType == "Short-term", onClick = { durationType = "Short-term" }, colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF1A5276))); Text("Short-term", fontSize = 13.sp) }
                        Row(verticalAlignment = Alignment.CenterVertically) { RadioButton(selected = durationType == "Long-term", onClick = { durationType = "Long-term" }, colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF1A5276))); Text("Long-term", fontSize = 13.sp) }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
                HorizontalDivider(color = Color(0xFFE2E8F0))
                Spacer(modifier = Modifier.height(16.dp))

                Text(if(isSinhala) "දෛනික රාජකාරි ලැයිස්තුව" else "Daily Tasks List", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                Text(if(isSinhala) "සේවකයා විසින් කළ යුතු දේවල් මෙහි ඇතුලත් කරන්න." else "Enter the tasks the caregiver should perform.", fontSize = 12.sp, color = Color.Gray)
                Spacer(modifier = Modifier.height(8.dp))

                Card(colors = CardDefaults.cardColors(containerColor = Color.White), modifier = Modifier.fillMaxWidth(), elevation = CardDefaults.cardElevation(2.dp)) {
                    Column(modifier = Modifier.padding(12.dp)) {
                        requestedTasks.forEachIndexed { index, task ->
                            Row(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.weight(1f)) {
                                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF52BE80), modifier = Modifier.size(16.dp))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text(text = task, fontSize = 14.sp, color = Color(0xFF1E293B))
                                }
                                IconButton(onClick = { requestedTasks.removeAt(index) }, modifier = Modifier.size(24.dp)) {
                                    Icon(Icons.Default.Clear, contentDescription = "Remove", tint = Color.Red, modifier = Modifier.size(18.dp))
                                }
                            }
                        }

                        Row(modifier = Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                            OutlinedTextField(
                                value = newTaskText, onValueChange = { newTaskText = it },
                                placeholder = { Text(if(isSinhala) "නව රාජකාරිය..." else "New task...") },
                                modifier = Modifier.weight(1f).height(50.dp), singleLine = true,
                                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Color(0xFF1A5276))
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Button(
                                onClick = { if (newTaskText.isNotBlank()) { requestedTasks.add(newTaskText); newTaskText = "" } },
                                shape = RoundedCornerShape(8.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A5276)),
                                modifier = Modifier.height(50.dp)
                            ) { Text(if(isSinhala) "එකතු කරන්න" else "Add") }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
                HorizontalDivider(color = Color(0xFFE2E8F0))
                Spacer(modifier = Modifier.height(16.dp))

                Text(if(isSinhala) "රෝගියා / වැඩිහිටියා තෝරන්න" else "Select Patient / Elder", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                Spacer(modifier = Modifier.height(8.dp))
                if (uiState.elders.isEmpty()) {
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)), modifier = Modifier.fillMaxWidth()) {
                        Text(if(isSinhala) "කරුණාකර මුලින්ම වැඩිහිටි විස්තරයක් එකතු කරන්න." else "Please add an elder profile first.", color = Color.Red, modifier = Modifier.padding(16.dp))
                    }
                } else {
                    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = !expanded }) {
                        OutlinedTextField(
                            value = selectedElder?.name ?: if(isSinhala) "තෝරා නැත" else "Not selected", onValueChange = {}, readOnly = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                            modifier = Modifier.menuAnchor().fillMaxWidth(), colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors(focusedBorderColor = Color(0xFF1A5276))
                        )
                        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }, modifier = Modifier.background(Color.White)) {
                            uiState.elders.forEach { elder -> DropdownMenuItem(text = { Text("${elder.name} (${elder.age}y)") }, onClick = { selectedElder = elder; expanded = false }) }
                        }
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))

                Text(if(isSinhala) "දිනය සහ වේලාව" else "Date & Time", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = !isScheduled, onClick = { isScheduled = false; scheduledTimeMs = 0L }, colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF1A5276)))
                    Text(if(isSinhala) "වහාම අවශ්‍යයි" else "Immediate", modifier = Modifier.padding(end=16.dp), fontSize = 14.sp)
                    RadioButton(selected = isScheduled, onClick = { isScheduled = true }, colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF1A5276)))
                    Text(if(isSinhala) "වෙන් කරගන්න" else "Schedule", fontSize = 14.sp)
                }
                if (isScheduled) {
                    OutlinedButton(
                        onClick = { pickDateTime() },
                        modifier = Modifier.fillMaxWidth().padding(top=8.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF1A5276))
                    ) {
                        Icon(Icons.Default.DateRange, contentDescription = null, modifier = Modifier.padding(end=8.dp))
                        Text(scheduledDisplay)
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))

                Text(if(isSinhala) "අමතර විස්තර" else "Additional Details", fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                OutlinedTextField(
                    value = description, onValueChange = { description = it },
                    placeholder = { Text(if(isSinhala) "උදා: අම්මාගේ සීනි මට්ටම..." else "e.g., Need to check mother's sugar level...") },
                    modifier = Modifier.fillMaxWidth().height(100.dp).padding(top=8.dp), shape = RoundedCornerShape(12.dp), maxLines = 4,
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Color(0xFF1A5276))
                )
                Spacer(modifier = Modifier.height(8.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = isEmergency, onCheckedChange = { isEmergency = it })
                    Text(if(isSinhala) "මෙය හදිසි අවශ්‍යතාවයකි (SOS)" else "This is an Emergency (SOS)", color = Color.Red, fontWeight = FontWeight.Bold)
                }

                Spacer(modifier = Modifier.height(24.dp))

                Button(
                    onClick = {
                        if (selectedElder == null) { Toast.makeText(context, if(isSinhala) "කරුණාකර රෝගියෙකු තෝරන්න" else "Please select a patient", Toast.LENGTH_SHORT).show(); return@Button }
                        if (isScheduled && scheduledTimeMs == 0L) { Toast.makeText(context, if(isSinhala) "දිනය සහ වේලාව තෝරන්න" else "Select Date and Time", Toast.LENGTH_SHORT).show(); return@Button }
                        if (requestedTasks.isEmpty()) { Toast.makeText(context, if(isSinhala) "අවම වශයෙන් එක් රාජකාරියක් හෝ ඇතුලත් කරන්න" else "Add at least one task", Toast.LENGTH_SHORT).show(); return@Button }

                        val hours = estimatedHoursStr.toIntOrNull() ?: 1
                        val locPrefix = if(isSinhala) "ස්ථානය:" else "Location:"
                        val finalDesc = "$locPrefix $locationName\n\n$description"

                        viewModel.createJobRequest(
                            selectedLat, selectedLng, finalDesc, isEmergency, selectedElder!!.id, selectedCaregiverId, scheduledTimeMs,
                            careCategory, serviceType, durationType, requestedTasks.toList(), hours
                        )
                    },
                    modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A5276)), enabled = !uiState.isLoading && selectedElder != null
                ) {
                    if (uiState.isLoading) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
                    else Text(
                        text = if (selectedCaregiverName != null) (if(isSinhala) "ඉල්ලීම යවන්න" else "Send Request") else (if(isSinhala) "සියලු දෙනාටම යවන්න" else "Broadcast to All"),
                        fontSize = 16.sp, fontWeight = FontWeight.Bold
                    )
                }
                Spacer(modifier = Modifier.height(32.dp))
            }
        }
    }
}