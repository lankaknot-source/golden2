package com.kina.care.presentation.map

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Place
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kina.care.presentation.util.LocalIsSinhala
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.OnlineTileSourceBase
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline

@SuppressLint("MissingPermission")
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MapScreen(
    onBackClick: () -> Unit,
    viewModel: MapViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    val isSinhala = LocalIsSinhala.current.value
    val isClient = uiState.role == "CLIENT"
    val lifecycleOwner = LocalLifecycleOwner.current

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
        }
    }

    // 🌟 Fix 1: Map එකේ Lifecycle එක නිවැරදිව හසුරුවා ගැනීම (මෙයින් Black screen වීම / ගැහෙන එක නවතියි)
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            mapView.onDetach()
        }
    }

    // 🌟 Fix 2: මුලින්ම පමණක් Map එක Focus කරන්න මේ State එක භාවිතා කරයි
    var hasCentered by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.caregiverLat, uiState.caregiverLng, uiState.clientLat, uiState.clientLng) {
        if (uiState.caregiverLat != 0.0 || uiState.clientLat != 0.0) {
            mapView.overlays.clear()

            val cgPoint = GeoPoint(uiState.caregiverLat, uiState.caregiverLng)
            val clientPoint = GeoPoint(uiState.clientLat, uiState.clientLng)

            // 1. Client ගේ ස්ථානය (නිවස/රෝගියා)
            if (uiState.clientLat != 0.0) {
                val clientMarker = Marker(mapView).apply {
                    position = clientPoint
                    title = if(isSinhala) "රෝගියා සිටින ස්ථානය" else "Patient Location"
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                }
                mapView.overlays.add(clientMarker)
            }

            // 2. Caregiver ගේ සජීවී ස්ථානය
            if (uiState.caregiverLat != 0.0) {
                val cgMarker = Marker(mapView).apply {
                    position = cgPoint
                    title = if(isSinhala) "සාත්තු සේවකයා (Live)" else "Caregiver (Live)"
                    setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
                }
                mapView.overlays.add(cgMarker)
            }

            // 3. දෙදෙනාම සිටී නම් ඔවුන් අතර රේඛාවක් (Line) ඇඳීම
            if (uiState.clientLat != 0.0 && uiState.caregiverLat != 0.0) {
                val line = Polyline().apply {
                    addPoint(clientPoint)
                    addPoint(cgPoint)
                    outlinePaint.color = android.graphics.Color.parseColor("#EF4444") // රතු පාට
                    outlinePaint.strokeWidth = 8f
                }
                mapView.overlays.add(line)
            }

            mapView.invalidate()

            // 🌟 Map එක Focus කිරීම (එක් වරක් පමණක් සිදුකරයි, එබැවින් ගැහෙන එක නවතියි)
            if (!hasCentered) {
                if (uiState.caregiverLat != 0.0) {
                    mapView.controller.setCenter(cgPoint)
                    hasCentered = true
                } else if (uiState.clientLat != 0.0) {
                    mapView.controller.setCenter(clientPoint)
                    hasCentered = true
                }
            }
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if(isSinhala) "සජීවී සිතියම (Live Map)" else "Live Tracking Map", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = onBackClick) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF0EA5E9))
            )
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF8FAFC)).padding(paddingValues)) {
            when {
                uiState.isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Color(0xFF0EA5E9)) }
                else -> {
                    Column(modifier = Modifier.fillMaxSize()) {

                        // දුර පෙන්වීම
                        if (uiState.activeBooking != null && uiState.distanceInMeters > 0) {
                            Card(
                                modifier = Modifier.fillMaxWidth().padding(16.dp),
                                colors = CardDefaults.cardColors(containerColor = Color.White),
                                elevation = CardDefaults.cardElevation(4.dp)
                            ) {
                                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Place, null, tint = Color.Red)
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Column {
                                        Text(if(isSinhala) "සේවකයාට ඇති දුර:" else "Distance to Caregiver:", color = Color.Gray, fontSize = 12.sp)
                                        Text("${uiState.distanceInMeters.toInt()} Meters", fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, color = Color(0xFF0D3B66))
                                    }
                                }
                            }
                        }

                        Box(modifier = Modifier.fillMaxWidth().weight(1f)) {
                            AndroidView(factory = { mapView }, modifier = Modifier.fillMaxSize())
                        }

                        if (!isClient && uiState.activeBooking != null && uiState.clientLat != 0.0) {
                            Card(
                                modifier = Modifier.fillMaxWidth().padding(16.dp), shape = RoundedCornerShape(20.dp),
                                colors = CardDefaults.cardColors(containerColor = Color.White), elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
                            ) {
                                Column(modifier = Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(if(isSinhala) "සේවාදායකයාගේ නිවසට ගමන් කරන්න" else "Navigate to Patient", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                                    Spacer(modifier = Modifier.height(16.dp))
                                    Button(
                                        onClick = {
                                            val uri = Uri.parse("google.navigation:q=${uiState.clientLat},${uiState.clientLng}")
                                            val intent = Intent(Intent.ACTION_VIEW, uri).apply { setPackage("com.google.android.apps.maps") }
                                            if (intent.resolveActivity(context.packageManager) != null) context.startActivity(intent)
                                            else context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${uiState.clientLat},${uiState.clientLng}")))
                                        },
                                        modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3B82F6))
                                    ) { Text(if(isSinhala) "පාර බලාගන්න (Google Maps)" else "Open Google Maps", fontSize = 16.sp, fontWeight = FontWeight.Bold) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}