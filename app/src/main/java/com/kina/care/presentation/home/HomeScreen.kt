package com.kina.care.presentation.home
import com.kina.care.presentation.components.BrandLogo

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.kina.care.domain.model.SubscriptionPlan
import com.kina.care.domain.model.User
import com.kina.care.presentation.util.LocalIsSinhala
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.min
import kotlin.math.roundToInt
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.Spring
import androidx.compose.ui.composed
import androidx.compose.ui.draw.scale

val ColorBlue = Color(0xFF1E6091)
val ColorGreen = Color(0xFF52BE80)
val ColorLightBlue = Color(0xFF5DADE2)
val ColorDarkNavy = Color(0xFF1A5276)
val ColorBackground = Color(0xFFF4F8FB)

fun Modifier.bouncyClickable(onClick: () -> Unit): Modifier = composed {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(stiffness = Spring.StiffnessLow, dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "bouncy"
    )
    this
        .scale(scale)
        .clickable(
            interactionSource = interactionSource,
            indication = null, // Disable standard ripple focusing on premium premium bounce effect
            onClick = onClick
        )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onLogoutSuccess: () -> Unit,
    onNavigateToFindCaregiver: () -> Unit = {},
    onNavigateToProfile: () -> Unit = {},
    onNavigateToMap: () -> Unit = {},
    onNavigateToJobFeed: () -> Unit = {},
    onNavigateToBookings: () -> Unit = {},
    onNavigateToWallet: () -> Unit = {},
    onNavigateToElderProfile: () -> Unit = {},
    onNavigateToVerification: () -> Unit = {},
    onNavigateToClientKyc: () -> Unit = {},
    onNavigateToCreateJobWithCaregiver: (String, String) -> Unit = { _, _ -> },
    homeViewModel: HomeViewModel = viewModel()
) {
    val uiState by homeViewModel.uiState.collectAsState()
    val plans by homeViewModel.subscriptionPlans.collectAsState()
    val reviews by homeViewModel.reviewsState.collectAsState()
    val isReviewsLoading by homeViewModel.isReviewsLoading.collectAsState()

    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var selectedBottomTab by remember { mutableStateOf(0) }
    val isSinhalaState = LocalIsSinhala.current
    val isSinhala by isSinhalaState

    var selectedUserForDetails by remember { mutableStateOf<User?>(null) }
    var showKycPrompt by rememberSaveable { mutableStateOf(false) }
    var showFeePrompt by rememberSaveable { mutableStateOf(false) }
    var hasCheckedKyc by rememberSaveable { mutableStateOf(false) }

    var showPackagesSheet by remember { mutableStateOf(false) }
    var selectedPlanToBuy by remember { mutableStateOf<SubscriptionPlan?>(null) }
    var selectedElderId by remember { mutableStateOf("") }
    var elderDropdownExpanded by remember { mutableStateOf(false) }
    var isProcessingPayment by remember { mutableStateOf(false) }

    var pendingJobCount by remember { mutableStateOf(0) }
    var hideBadge by remember { mutableStateOf(false) }
    var showSosDialog by remember { mutableStateOf(false) }

    var selectedSlipUri by remember { mutableStateOf<Uri?>(null) }
    var base64Slip by remember { mutableStateOf<String?>(null) }
    val slipPickerLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        selectedSlipUri = uri
        uri?.let {
            coroutineScope.launch {
                base64Slip = compressImageUriToBase64Home(context, it)
            }
        }
    }

    LaunchedEffect(uiState.userData) {
        uiState.userData?.let { user ->
            if (!hasCheckedKyc) {
                hasCheckedKyc = true
                if (!user.isVerified && user.nicNumber.isEmpty()) {
                    showKycPrompt = true
                } else if (user.role == "CLIENT" && user.kycStatus == "APPROVED" && !user.isVerified) {
                    showFeePrompt = true
                }
            }
        }
    }

    val currentUser = uiState.userData
    DisposableEffect(currentUser?.id) {
        var listener: ListenerRegistration? = null
        if (currentUser != null && (currentUser.role == "CAREGIVER" || currentUser.role == "NURSE")) {
            listener = FirebaseFirestore.getInstance().collection("bookings")
                .addSnapshotListener { snap, _ ->
                    if (snap != null) {
                        val currentCount = snap.documents.count { doc ->
                            val status = doc.getString("status")?.uppercase() ?: ""
                            val cId = doc.getString("caregiverId") ?: ""
                            (status == "PENDING" && cId == currentUser.id) || (status == "BROADCASTED")
                        }

                        if (currentCount > pendingJobCount) {
                            hideBadge = false
                        }

                        pendingJobCount = currentCount
                    }
                }
        }
        onDispose {
            listener?.remove()
        }
    }

    Scaffold(
        floatingActionButton = {
            if (currentUser != null) {
                ExtendedFloatingActionButton(
                    onClick = { showSosDialog = true },
                    containerColor = Color(0xFFEF4444),
                    contentColor = Color.White,
                    icon = { Icon(Icons.Default.Warning, contentDescription = "SOS") },
                    text = { Text("SOS", fontWeight = FontWeight.ExtraBold) }
                )
            }
        },
        bottomBar = {
            NavigationBar(containerColor = Color.White, tonalElevation = 8.dp) {
                NavigationBarItem(
                    icon = { Icon(Icons.Filled.Home, "Home") },
                    label = { Text(if (isSinhala) "මුල් පිටුව" else "Home", fontSize = 10.sp) },
                    selected = selectedBottomTab == 0,
                    onClick = { selectedBottomTab = 0 },
                    colors = NavigationBarItemDefaults.colors(selectedIconColor = ColorBlue, indicatorColor = ColorBlue.copy(alpha = 0.1f))
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Outlined.DateRange, "Bookings") },
                    label = { Text(if (isSinhala) "වෙන්කිරීම්" else "Bookings", fontSize = 10.sp) },
                    selected = selectedBottomTab == 1,
                    onClick = { selectedBottomTab = 1; onNavigateToBookings() },
                    colors = NavigationBarItemDefaults.colors(selectedIconColor = ColorBlue, indicatorColor = ColorBlue.copy(alpha = 0.1f))
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Outlined.Email, "Messages") },
                    label = { Text(if (isSinhala) "පණිවිඩ" else "Messages", fontSize = 10.sp) },
                    selected = selectedBottomTab == 2,
                    onClick = { selectedBottomTab = 2; onNavigateToBookings() },
                    colors = NavigationBarItemDefaults.colors(selectedIconColor = ColorBlue, indicatorColor = ColorBlue.copy(alpha = 0.1f))
                )
                NavigationBarItem(
                    icon = { Icon(Icons.Outlined.Person, "Profile") },
                    label = { Text(if (isSinhala) "ගිණුම" else "Profile", fontSize = 10.sp) },
                    selected = selectedBottomTab == 3,
                    onClick = { selectedBottomTab = 3; onNavigateToProfile() },
                    colors = NavigationBarItemDefaults.colors(selectedIconColor = ColorBlue, indicatorColor = ColorBlue.copy(alpha = 0.1f))
                )
            }
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().background(ColorBackground).padding(paddingValues)) {
            when {
                uiState.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = ColorBlue)
                uiState.userData != null -> {
                    val user = uiState.userData!!
                    Column(modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {

                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(bottomStart = 32.dp, bottomEnd = 32.dp))
                                .background(Brush.verticalGradient(listOf(ColorDarkNavy, ColorBlue)))
                                .padding(start = 24.dp, end = 24.dp, top = 16.dp, bottom = 32.dp)
                        ) {
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    BrandLogo(modifier = Modifier.size(48.dp))
                                    Spacer(modifier = Modifier.width(8.dp))
                                    Text("Golden Hand", fontSize = 20.sp, fontWeight = FontWeight.ExtraBold, color = Color.White)
                                }
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    TextButton(onClick = { isSinhalaState.value = !isSinhalaState.value }) {
                                        Text(text = if (isSinhala) "EN" else "සිං", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 14.sp)
                                    }
                                    IconButton(onClick = { homeViewModel.logout(); onLogoutSuccess() }) {
                                        Icon(Icons.Default.ExitToApp, contentDescription = "Logout", tint = Color.White)
                                    }
                                }
                            }
                            Spacer(modifier = Modifier.height(24.dp))
                            Text(text = if (isSinhala) "ආයුබෝවන්, ${user.name.split(" ").first()}!" else "Hello, ${user.name.split(" ").first()}!", fontSize = 26.sp, fontWeight = FontWeight.ExtraBold, color = Color.White)
                            Spacer(modifier = Modifier.height(24.dp))
                            Card(
                                modifier = Modifier.fillMaxWidth().height(55.dp).bouncyClickable { onNavigateToFindCaregiver() },
                                shape = RoundedCornerShape(28.dp),
                                colors = CardDefaults.cardColors(containerColor = Color.White),
                                elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
                            ) {
                                Row(modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Default.Search, contentDescription = "Search", tint = ColorBlue, modifier = Modifier.size(24.dp))
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text(if (isSinhala) "සාත්තු සේවකයෙකු හෝ හෙදියක් සොයන්න..." else "Search for a caregiver or nurse...", color = Color.Gray, fontSize = 15.sp)
                                }
                            }
                        }

                        Column(modifier = Modifier.padding(top = 24.dp, start = 16.dp, end = 16.dp, bottom = 16.dp)) {

                            if ((user.role == "CAREGIVER" || user.role == "NURSE") && user.kycMeetingStatus == "SCHEDULED" && user.kycMeetingDateMs != null) {
                                val meetingDate = SimpleDateFormat("yyyy MMM dd - hh:mm a", Locale.getDefault()).format(Date(user.kycMeetingDateMs))
                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFE0F2FE)),
                                    modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                                    border = BorderStroke(1.dp, Color(0xFF0284C7))
                                ) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.Call, contentDescription = null, tint = Color(0xFF0284C7))
                                            Spacer(modifier = Modifier.width(8.dp))
                                            Text(if(isSinhala) "ඔබගේ KYC සම්මුඛ පරීක්ෂණය" else "KYC Video Interview", fontWeight = FontWeight.Bold, color = Color(0xFF0369A1), fontSize = 16.sp)
                                        }
                                        Spacer(modifier = Modifier.height(8.dp))
                                        Text(if(isSinhala) "දිනය සහ වේලාව: $meetingDate" else "Scheduled for: $meetingDate", color = Color(0xFF0C4A6E), fontSize = 14.sp)
                                        Text(if(isSinhala) "කරුණාකර නියමිත වේලාවට පහත බොත්තම ඔබා සම්බන්ධ වන්න." else "Please join the meeting at the scheduled time.", color = Color(0xFF0C4A6E), fontSize = 12.sp, modifier = Modifier.padding(top=4.dp))
                                        Spacer(modifier = Modifier.height(12.dp))
                                        Button(
                                            onClick = {
                                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(user.kycMeetingUrl))
                                                context.startActivity(intent)
                                            },
                                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0284C7)),
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Text(if(isSinhala) "වීඩියෝ කෝල් එකට සම්බන්ධ වන්න" else "Join Video Call", fontWeight = FontWeight.Bold)
                                        }
                                    }
                                }
                            }

                            if (user.role == "CAREGIVER" || user.role == "NURSE") {
                                CaregiverHorizontalGrid(
                                    isSinhala = isSinhala,
                                    pendingJobCount = if (hideBadge) 0 else pendingJobCount,
                                    onNavigateToJobFeed = {
                                        hideBadge = true
                                        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                                        notificationManager.cancelAll()
                                        onNavigateToJobFeed()
                                    },
                                    onNavigateToMap = onNavigateToMap,
                                    onNavigateToProfile = onNavigateToProfile,
                                    onNavigateToWallet = onNavigateToWallet
                                )

                                if (uiState.activeBooking != null && uiState.activeElder != null) {
                                    Spacer(modifier = Modifier.height(24.dp))
                                    Text(if (isSinhala) "දැනට භාරගත් රෝගියා" else "Current Patient", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = ColorDarkNavy)
                                    Spacer(modifier = Modifier.height(8.dp))
                                    val elder = uiState.activeElder!!
                                    Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(containerColor = Color.White), elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)) {
                                        Column(modifier = Modifier.padding(16.dp)) {
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Icon(Icons.Default.Person, contentDescription = null, tint = ColorBlue, modifier = Modifier.size(24.dp))
                                                Spacer(modifier = Modifier.width(8.dp))
                                                Text(elder.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = ColorDarkNavy)
                                            }
                                            Spacer(modifier = Modifier.height(8.dp))
                                            Text("${if(isSinhala) "වයස" else "Age"}: ${elder.age} | ${elder.gender}", color = Color.Gray, fontSize = 14.sp)
                                            if (elder.medicalConditions.isNotEmpty()) {
                                                Spacer(modifier = Modifier.height(4.dp))
                                                Text("${if(isSinhala) "ලෙඩ රෝග" else "Medical"}: ${elder.medicalConditions.joinToString(", ")}", color = Color.Red, fontSize = 14.sp)
                                            }
                                            Spacer(modifier = Modifier.height(16.dp))
                                            Button(
                                                onClick = {
                                                    if (elder.emergencyContact.isNotEmpty()) {
                                                        val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${elder.emergencyContact}"))
                                                        context.startActivity(intent)
                                                    } else { Toast.makeText(context, "දුරකථන අංකයක් ලබා දී නොමැත.", Toast.LENGTH_SHORT).show() }
                                                },
                                                modifier = Modifier.fillMaxWidth().height(45.dp), shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = ColorGreen)
                                            ) {
                                                Icon(Icons.Default.Call, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                                                Spacer(modifier = Modifier.width(8.dp))
                                                Text(if(isSinhala) "හදිසි ඇමතුමක් ගන්න" else "Emergency Call", fontSize = 14.sp, fontWeight = FontWeight.Bold)
                                            }
                                        }
                                    }
                                }
                            } else {
                                ClientHorizontalGrid(isSinhala, onNavigateToFindCaregiver, onNavigateToBookings, onNavigateToProfile, onNavigateToElderProfile)
                            }

                            Spacer(modifier = Modifier.height(24.dp))

                            if (user.role == "CLIENT") {
                                Card(
                                    modifier = Modifier.fillMaxWidth().bouncyClickable { showPackagesSheet = true },
                                    shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF3C7)), elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                                ) {
                                    Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFD97706), modifier = Modifier.size(32.dp))
                                        Spacer(modifier = Modifier.width(12.dp))
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(if (isSinhala) "විශේෂ පැකේජ සහ දායකත්වයන්" else "Premium Packages & Subscriptions", fontWeight = FontWeight.Bold, color = Color(0xFF92400E))
                                            Text(if (isSinhala) "මාසික දායකත්වයන් සහ විශේෂ සේවකයින්" else "Monthly subscriptions & Premium staff", fontSize = 12.sp, color = Color(0xFFB45309))
                                        }
                                        Icon(Icons.Default.KeyboardArrowRight, contentDescription = null, tint = Color(0xFF92400E))
                                    }
                                }
                                Spacer(modifier = Modifier.height(24.dp))
                            }

                            PromoBannerSlider(isSinhala)
                            Spacer(modifier = Modifier.height(24.dp))

                            if (user.role != "CAREGIVER" && user.role != "NURSE") {
                                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                                    Text(text = if (isSinhala) "මෑතකදී වෙන් කළ / ඉහළම" else "Top Rated Caregivers & Nurses", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = ColorDarkNavy)
                                    Text(text = if (isSinhala) "සියල්ල" else "View all", fontSize = 12.sp, color = ColorBlue, fontWeight = FontWeight.Bold, modifier = Modifier.bouncyClickable { onNavigateToFindCaregiver() })
                                }
                                Spacer(modifier = Modifier.height(16.dp))

                                if (uiState.topCaregivers.isEmpty()) {
                                    Text(text = if (isSinhala) "දැනට සේවකයින් නොමැත." else "No caregivers available yet.", fontSize = 14.sp, color = Color.Gray)
                                } else {
                                    LazyRow(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                        items(uiState.topCaregivers) { caregiver ->
                                            CircularCaregiverCard(caregiver) {
                                                selectedUserForDetails = caregiver
                                                homeViewModel.fetchReviewsForCaregiver(caregiver.id)
                                            }
                                        }
                                    }
                                }
                                Spacer(modifier = Modifier.height(16.dp))
                            }
                        }
                    }
                }
            }

            if (showPackagesSheet) {
                ModalBottomSheet(onDismissRequest = { showPackagesSheet = false }, containerColor = Color.White) {
                    Column(modifier = Modifier.fillMaxWidth().padding(24.dp).padding(bottom = 32.dp)) {
                        Text(if(isSinhala) "විශේෂ පැකේජ" else "Special Packages", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = ColorDarkNavy)
                        Spacer(modifier = Modifier.height(16.dp))

                        if (plans.isEmpty()) {
                            Text(if(isSinhala) "දැනට පැකේජ කිසිවක් නොමැත." else "No packages available.", color = Color.Gray)
                        } else {
                            LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                items(plans) { plan ->
                                    Card(
                                        modifier = Modifier.fillMaxWidth().bouncyClickable {
                                            showPackagesSheet = false
                                            selectedPlanToBuy = plan
                                        },
                                        colors = CardDefaults.cardColors(containerColor = Color(0xFFFFF7ED)), border = BorderStroke(1.dp, Color(0xFFF97316))
                                    ) {
                                        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                            Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFEA580C), modifier = Modifier.size(36.dp))
                                            Spacer(modifier = Modifier.width(16.dp))
                                            Column {
                                                Text(plan.title, fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color(0xFF9A3412))
                                                Text(plan.description, fontSize = 12.sp, color = Color.Gray, modifier = Modifier.padding(top=4.dp))
                                                Spacer(modifier = Modifier.height(8.dp))
                                                Text("Rs. ${String.format(Locale.US, "%,.2f", plan.price)}", fontWeight = FontWeight.ExtraBold, color = Color(0xFFC2410C), fontSize = 16.sp)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if (selectedPlanToBuy != null) {
                val plan = selectedPlanToBuy!!
                AlertDialog(
                    onDismissRequest = {
                        if(!isProcessingPayment) {
                            selectedPlanToBuy = null
                            selectedSlipUri = null
                            base64Slip = null
                        }
                    },
                    title = { Text(if(isSinhala) "පැකේජය මිලදී ගැනීම" else "Purchase Package", fontWeight = FontWeight.Bold, color = ColorDarkNavy) },
                    text = {
                        Column {
                            Text(plan.title, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, color = Color(0xFF047857))
                            Spacer(modifier = Modifier.height(12.dp))

                            if (uiState.clientElders.isEmpty()) {
                                Text(if(isSinhala) "ඔබ තවමත් රෝගී විස්තර එකතු කර නැත. කරුණාකර 'රෝගී රැකවරණය' වෙත ගොස් එකතු කරන්න." else "Please add a patient profile first.", color = Color.Red, fontSize = 13.sp)
                            } else {
                                Text(if(isSinhala) "සේවය අවශ්‍ය රෝගියා තෝරන්න:" else "Select Patient:", fontWeight = FontWeight.Bold)
                                ExposedDropdownMenuBox(expanded = elderDropdownExpanded, onExpandedChange = { elderDropdownExpanded = !elderDropdownExpanded }) {
                                    OutlinedTextField(
                                        value = uiState.clientElders.find { it.id == selectedElderId }?.name ?: "තෝරා නැත",
                                        onValueChange = {}, readOnly = true, modifier = Modifier.menuAnchor().fillMaxWidth(),
                                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = elderDropdownExpanded) }
                                    )
                                    ExposedDropdownMenu(expanded = elderDropdownExpanded, onDismissRequest = { elderDropdownExpanded = false }) {
                                        uiState.clientElders.forEach { elder ->
                                            DropdownMenuItem(text = { Text("${elder.name} (${elder.age}y)") }, onClick = { selectedElderId = elder.id; elderDropdownExpanded = false })
                                        }
                                    }
                                }

                                Spacer(modifier = Modifier.height(16.dp))

                                Card(
                                    colors = CardDefaults.cardColors(containerColor = Color(0xFFEBF5FB)),
                                    modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Text(if(isSinhala) "අපගේ බැංකු ගිණුම් විස්තර:" else "Our Bank Details:", fontWeight = FontWeight.Bold, fontSize = 14.sp)
                                        Spacer(modifier = Modifier.height(4.dp))
                                        Text("Bank: Seylan Bank\nBranch: Katugasthota\nAccount Name: Golden Hand Caregivers\nAccount No: 14 901 361 84 8000 1", fontSize = 13.sp)
                                    }
                                }

                                Text(if(isSinhala) "බැංකු රිසිට්පත අප්ලෝඩ් කරන්න" else "Upload Bank Slip", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                                Spacer(modifier = Modifier.height(8.dp))
                                OutlinedButton(onClick = { slipPickerLauncher.launch("image/*") }, modifier = Modifier.fillMaxWidth()) {
                                    Text(if(isSinhala) "රිසිට්පත තෝරන්න (Select Slip)" else "Select Bank Slip")
                                }

                                if (selectedSlipUri != null) {
                                    Spacer(modifier = Modifier.height(8.dp))
                                    AsyncImage(
                                        model = selectedSlipUri,
                                        contentDescription = "Selected Slip",
                                        modifier = Modifier.fillMaxWidth().height(120.dp).clip(RoundedCornerShape(8.dp)).border(1.dp, Color.LightGray, RoundedCornerShape(8.dp)),
                                        contentScale = ContentScale.Crop
                                    )
                                }
                            }
                        }
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                if (selectedElderId.isEmpty()) {
                                    Toast.makeText(context, if(isSinhala) "කරුණාකර රෝගියෙකු තෝරන්න" else "Please select a patient", Toast.LENGTH_SHORT).show()
                                } else if (selectedSlipUri == null) {
                                    Toast.makeText(context, if(isSinhala) "කරුණාකර බැංකු රිසිට්පත අප්ලෝඩ් කරන්න" else "Please upload the bank slip", Toast.LENGTH_SHORT).show()
                                } else {
                                    isProcessingPayment = true
                                    homeViewModel.purchaseSubscriptionPlan(plan, selectedElderId) { success, msg ->
                                        isProcessingPayment = false
                                        Toast.makeText(context, msg, Toast.LENGTH_LONG).show()
                                        if(success) {
                                            selectedPlanToBuy = null
                                            selectedSlipUri = null
                                            base64Slip = null
                                            onNavigateToBookings()
                                        }
                                    }
                                }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2563EB)),
                            enabled = !isProcessingPayment && uiState.clientElders.isNotEmpty()
                        ) {
                            if (isProcessingPayment) CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp))
                            else Text(if(isSinhala) "තහවුරු කරන්න (Confirm)" else "Confirm Rs. ${plan.price.toInt()}")
                        }
                    },
                    dismissButton = {
                        if(!isProcessingPayment) {
                            TextButton(onClick = {
                                selectedPlanToBuy = null
                                selectedSlipUri = null
                                base64Slip = null
                            }) { Text(if(isSinhala) "අවලංගු කරන්න" else "Cancel") }
                        }
                    }
                )
            }

            if (showKycPrompt && uiState.userData != null) {
                val currentUserData = uiState.userData!!
                AlertDialog(
                    onDismissRequest = { showKycPrompt = false },
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Warning, contentDescription = null, tint = Color(0xFFD97706))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(if (isSinhala) "අනන්‍යතාවය තහවුරු කරන්න" else "Verify Identity", fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), fontSize = 18.sp)
                        }
                    },
                    text = {
                        Text(
                            if (isSinhala) "ඔබගේ ගිණුමේ ආරක්ෂාව තහවුරු කිරීම සහ සියලු සේවාවන් ලබා ගැනීම සඳහා කරුණාකර ඔබගේ තොරතුරු (KYC) ලබා දෙන්න."
                            else "Please complete your KYC verification to ensure account security and access all features.",
                            color = Color.DarkGray
                        )
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                showKycPrompt = false
                                if (currentUserData.role == "CAREGIVER" || currentUserData.role == "NURSE") {
                                    onNavigateToVerification()
                                } else {
                                    onNavigateToClientKyc()
                                }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9))
                        ) { Text(if (isSinhala) "දැන්ම සම්පූර්ණ කරන්න" else "Complete Now", fontWeight = FontWeight.Bold) }
                    },
                    dismissButton = {
                        TextButton(onClick = { showKycPrompt = false }) { Text(if (isSinhala) "පසුවට" else "Later", color = Color.Gray) }
                    }
                )
            }

            if (showFeePrompt && uiState.userData != null) {
                AlertDialog(
                    onDismissRequest = { showFeePrompt = false },
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Info, contentDescription = null, tint = Color(0xFF0EA5E9))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(if (isSinhala) "ලියාපදිංචි ගාස්තුව" else "Registration Fee", fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), fontSize = 18.sp)
                        }
                    },
                    text = {
                        Text(
                            if (isSinhala) "ඔබගේ ගිණුම අනුමත කර ඇත. සේවාවන් ලබා ගැනීම ආරම්භ කිරීමට කරුණාකර ලියාපදිංචි ගාස්තුව ගෙවන්න."
                            else "Your account is approved. Please pay the registration fee to start using our services.",
                            color = Color.DarkGray
                        )
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                showFeePrompt = false
                                onNavigateToProfile()
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9))
                        ) { Text(if (isSinhala) "ගෙවීම් කරන්න" else "Pay Now", fontWeight = FontWeight.Bold) }
                    },
                    dismissButton = {
                        TextButton(onClick = { showFeePrompt = false }) { Text(if (isSinhala) "පසුවට" else "Later", color = Color.Gray) }
                    }
                )
            }
            
            if (showSosDialog && uiState.userData != null) {
                AlertDialog(
                    onDismissRequest = { showSosDialog = false },
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Warning, contentDescription = null, tint = Color.Red, modifier = Modifier.size(28.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(if (isSinhala) "හදිසි අවස්ථාවක්ද?" else "Emergency SOS?", fontWeight = FontWeight.ExtraBold, color = Color.Red, fontSize = 20.sp)
                        }
                    },
                    text = {
                        Text(
                            if (isSinhala) "ඔබේ හදිසි පණිවිඩය (SOS) පද්ධතියට සහ සම්බන්ධිත පාර්ශවයන්ට යවන්නද? කරුණාකර මෙය සැබෑ හදිසි අවස්ථාවකදී පමණක් භාවිතා කරන්න."
                            else "Send an emergency SOS alert to the system and connected parties? Please use this only in real emergencies.",
                            color = Color.DarkGray
                        )
                    },
                    confirmButton = {
                        Button(
                            onClick = {
                                val alert = hashMapOf(
                                    "userId" to uiState.userData!!.id,
                                    "userName" to uiState.userData!!.name,
                                    "userRole" to uiState.userData!!.role,
                                    "timestamp" to System.currentTimeMillis()
                                )
                                FirebaseFirestore.getInstance().collection("sos_alerts").add(alert).addOnSuccessListener {
                                    Toast.makeText(context, if(isSinhala) "හදිසි පණිවිඩය යවන ලදි!" else "SOS Alert Sent!", Toast.LENGTH_SHORT).show()
                                }
                                showSosDialog = false
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                        ) { Text(if (isSinhala) "පණිවිඩය යවන්න" else "Send Alert", fontWeight = FontWeight.Bold) }
                    },
                    dismissButton = {
                        TextButton(onClick = { showSosDialog = false }) { Text(if (isSinhala) "අවලංගු කරන්න" else "Cancel", color = Color.Gray) }
                    }
                )
            }
        }

        if (selectedUserForDetails != null) {
            val popupUser = selectedUserForDetails!!
            ModalBottomSheet(onDismissRequest = { selectedUserForDetails = null; homeViewModel.clearReviews() }, containerColor = Color.White) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp).verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (popupUser.profileImageUrl.isNotEmpty()) {
                        val bitmap = convertBase64ToBitmapHome(popupUser.profileImageUrl)
                        if (bitmap != null) {
                            Image(bitmap = bitmap.asImageBitmap(), contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(100.dp).clip(CircleShape))
                        } else {
                            Box(modifier = Modifier.size(100.dp).clip(CircleShape).background(Color(0xFFE2E8F0)), contentAlignment = Alignment.Center) {
                                Text(if(popupUser.name.isNotEmpty()) popupUser.name.first().toString().uppercase() else "?", fontSize = 40.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                            }
                        }
                    } else {
                        Box(modifier = Modifier.size(100.dp).clip(CircleShape).background(Color(0xFFE2E8F0)), contentAlignment = Alignment.Center) {
                            Text(if(popupUser.name.isNotEmpty()) popupUser.name.first().toString().uppercase() else "?", fontSize = 40.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))
                    Text(popupUser.name, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))

                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top=8.dp, bottom=16.dp)) {
                        Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFF59E0B), modifier = Modifier.size(24.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("${String.format(Locale.US, "%.1f", popupUser.rating)} / 5.0 (${popupUser.reviewCount} Reviews)", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                    }

                    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)), elevation = CardDefaults.cardElevation(0.dp)) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(if (isSinhala) "KYC තහවුරු කළ තොරතුරු" else "Verified KYC Information", fontWeight = FontWeight.ExtraBold, color = Color(0xFF0D3B66), fontSize = 16.sp, modifier = Modifier.padding(bottom = 12.dp))

                            val kycData = listOf(
                                (if(isSinhala) "වයස හා ස්ත්‍රී/පුරුෂ:" else "Age & Gender:") to "${popupUser.dob} | ${popupUser.gender}",
                                (if(isSinhala) "පළපුරුද්ද:" else "Experience:") to (popupUser.experienceYears.ifEmpty { "N/A" }),
                                (if(isSinhala) "සේවා වර්ග:" else "Service Types:") to (if (popupUser.preferredServiceTypes.isNotEmpty()) popupUser.preferredServiceTypes.joinToString(", ") else "Any"),
                                (if(isSinhala) "සේවා කාණ්ඩ:" else "Categories:") to (if (popupUser.categories.isNotEmpty()) popupUser.categories.joinToString(", ") else "Any"),
                                (if(isSinhala) "එන්නත් විස්තර:" else "Vaccination:") to (popupUser.vaccinationStatus.ifEmpty { "N/A" }),
                                (if(isSinhala) "නිදන්ගත රෝග:" else "Chronic Illnesses:") to (popupUser.chronicIllnesses.ifEmpty { "None" }),
                                (if(isSinhala) "විශේෂ හැකියාවන්:" else "Special Skills:") to (popupUser.specialSkills.ifEmpty { "None" })
                            )

                            kycData.forEach { (label, value) ->
                                Row(modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(label, color = Color.Gray, fontSize = 13.sp, modifier = Modifier.weight(1f))
                                    Text(value, color = Color(0xFF1E293B), fontSize = 13.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.End, modifier = Modifier.weight(1.5f))
                                }
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(24.dp))

                    Text(if (isSinhala) "සේවාදායකයින්ගේ අදහස් (Reviews):" else "Client Reviews:", fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66), modifier = Modifier.align(Alignment.Start))
                    Spacer(modifier = Modifier.height(8.dp))

                    if (isReviewsLoading) {
                        CircularProgressIndicator(color = Color(0xFF0EA5E9), modifier = Modifier.padding(16.dp))
                    } else if (reviews.isEmpty()) {
                        Text(if (isSinhala) "දැනට අදහස් කිසිවක් නොමැත." else "No reviews available yet.", color = Color.Gray, fontSize = 14.sp, modifier = Modifier.padding(bottom = 16.dp))
                    } else {
                        Column(modifier = Modifier.fillMaxWidth().heightIn(max = 250.dp)) {
                            reviews.forEach { review ->
                                Card(
                                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                                    colors = CardDefaults.cardColors(containerColor = Color.White),
                                    border = BorderStroke(1.dp, Color(0xFFF1F5F9))
                                ) {
                                    Column(modifier = Modifier.padding(12.dp)) {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Row {
                                                for(i in 1..5) {
                                                    Icon(Icons.Default.Star, contentDescription = null, tint = if(i <= review.rating) Color(0xFFF59E0B) else Color(0xFFE2E8F0), modifier = Modifier.size(14.dp))
                                                }
                                            }
                                            Spacer(modifier = Modifier.weight(1f))
                                            Text(SimpleDateFormat("MMM dd, yyyy", Locale.getDefault()).format(Date(review.timestamp)), fontSize = 10.sp, color = Color.Gray)
                                        }
                                        Text(review.comment.ifEmpty { if (isSinhala) "කමෙන්ට් එකක් ලබා දී නැත." else "No comment provided." }, fontSize = 13.sp, color = Color(0xFF1E293B), modifier = Modifier.padding(top=6.dp))
                                    }
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(16.dp))
                    Button(
                        onClick = {
                            selectedUserForDetails = null
                            homeViewModel.clearReviews()
                            onNavigateToCreateJobWithCaregiver(popupUser.id, popupUser.name)
                        },
                        modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = ColorGreen)
                    ) { Text(if (isSinhala) "මෙම සේවකයා තෝරාගන්න (Book)" else "Book this Caregiver/Nurse", fontSize = 16.sp, fontWeight = FontWeight.Bold) }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun PromoBannerSlider(isSinhala: Boolean) {
    var banners by remember { mutableStateOf<List<BannerData>>(emptyList()) }
    val uriHandler = LocalUriHandler.current

    LaunchedEffect(Unit) {
        FirebaseFirestore.getInstance().collection("settings").document("promotion")
            .addSnapshotListener { snap, _ ->
                if (snap != null && snap.exists()) {
                    val bannersList = snap.get("banners") as? List<Map<String, Any>>
                    val newBanners = mutableListOf<BannerData>()

                    if (bannersList != null && bannersList.isNotEmpty()) {
                        for (b in bannersList) {
                            newBanners.add(BannerData(
                                title = b["title"] as? String ?: "",
                                subtitle = b["subtitle"] as? String ?: "",
                                imageUrl = b["imageUrl"] as? String ?: "",
                                buttonText = b["buttonText"] as? String ?: "",
                                buttonLink = b["buttonLink"] as? String ?: "",
                                showButton = b["showButton"] as? Boolean ?: false
                            ))
                        }
                    }

                    if (newBanners.isEmpty()) {
                        newBanners.add(BannerData(
                            if (isSinhala) "දවසේ දීමනාව:" else "Deal of the Day:",
                            if (isSinhala) "පළමු වෙන්කිරීමට 20% වට්ටමක්!" else "20% Off your first booking!",
                            "", if (isSinhala) "දැන්ම එකතු වන්න" else "Join now", "", true
                        ))
                    }
                    banners = newBanners
                }
            }
    }

    if (banners.isNotEmpty()) {
        val pagerState = rememberPagerState(pageCount = { banners.size })

        LaunchedEffect(pagerState.currentPage) {
            while (banners.size > 1) {
                delay(20000)
                val nextPage = (pagerState.currentPage + 1) % banners.size
                pagerState.animateScrollToPage(nextPage)
            }
        }

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.fillMaxWidth().height(150.dp)
            ) { page ->
                val banner = banners[page]
                Card(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 4.dp),
                    shape = RoundedCornerShape(20.dp),
                    elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
                ) {
                    Box(modifier = Modifier.fillMaxSize()) {
                        if (banner.imageUrl.isNotEmpty()) {
                            AsyncImage(
                                model = banner.imageUrl,
                                contentDescription = "Promo Banner",
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize()
                            )
                        } else {
                            Box(modifier = Modifier.fillMaxSize().background(
                                Brush.horizontalGradient(listOf(Color(0xFF1E6091), Color(0xFF52BE80)))
                            ))
                        }

                        if (banner.title.isNotEmpty() || banner.subtitle.isNotEmpty()) {
                            Box(modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)))
                        }

                        Row(modifier = Modifier.fillMaxSize().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                            Column(modifier = Modifier.weight(1f)) {
                                if (banner.title.isNotEmpty()) {
                                    Text(text = banner.title, color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Medium)
                                }
                                if (banner.subtitle.isNotEmpty()) {
                                    Text(
                                        text = banner.subtitle, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold,
                                        modifier = Modifier.padding(top = 4.dp, bottom = 12.dp), maxLines = 2
                                    )
                                }
                                if (banner.showButton && banner.buttonText.isNotEmpty()) {
                                    Button(
                                        onClick = {
                                            if (banner.buttonLink.isNotEmpty()) {
                                                try { uriHandler.openUri(banner.buttonLink) } catch (e: Exception) {}
                                            }
                                        },
                                        colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = Color(0xFF1E6091)),
                                        shape = RoundedCornerShape(50),
                                        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp),
                                        modifier = Modifier.height(32.dp)
                                    ) { Text(banner.buttonText, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
                                }
                            }
                            if (banner.imageUrl.isEmpty()) {
                                Icon(Icons.Default.Favorite, contentDescription = null, tint = Color.White.copy(alpha=0.8f), modifier = Modifier.size(60.dp))
                            }
                        }
                    }
                }
            }

            if (banners.size > 1) {
                Row(
                    Modifier.fillMaxWidth().padding(top = 8.dp),
                    horizontalArrangement = Arrangement.Center
                ) {
                    repeat(banners.size) { iteration ->
                        val color = if (pagerState.currentPage == iteration) ColorBlue else Color.LightGray
                        Box(modifier = Modifier.padding(2.dp).clip(CircleShape).background(color).size(8.dp))
                    }
                }
            }
        }
    }
}

data class BannerData(val title: String, val subtitle: String, val imageUrl: String, val buttonText: String, val buttonLink: String, val showButton: Boolean)

@Composable
fun ClientHorizontalGrid(isSinhala: Boolean, onNavigateToFindCaregiver: () -> Unit, onNavigateToBookings: () -> Unit, onNavigateToProfile: () -> Unit, onNavigateToElderProfile: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        HorizontalGridCard(title = if (isSinhala) "වැඩිහිටි\nසත්කාර" else "Elder\nCare", icon = Icons.Default.Search, bgColor = ColorBlue, onClick = onNavigateToFindCaregiver)
        HorizontalGridCard(title = if (isSinhala) "රෝගී\nරැකවරණය" else "Patient\nProfiles", icon = Icons.Default.Favorite, bgColor = ColorGreen, onClick = onNavigateToElderProfile)
        HorizontalGridCard(title = if (isSinhala) "පණිවිඩ\nහා කතා" else "Chats &\nMessages", icon = Icons.Default.Email, bgColor = ColorLightBlue, onClick = onNavigateToBookings)
        HorizontalGridCard(title = if (isSinhala) "ගිණුම\nහා සැකසුම්" else "Account\nSettings", icon = Icons.Default.AccountCircle, bgColor = ColorDarkNavy, onClick = onNavigateToProfile)
    }
}

@Composable
fun CaregiverHorizontalGrid(isSinhala: Boolean, pendingJobCount: Int, onNavigateToJobFeed: () -> Unit, onNavigateToMap: () -> Unit, onNavigateToProfile: () -> Unit, onNavigateToWallet: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        HorizontalGridCard(title = if (isSinhala) "නව\nඉල්ලීම්" else "Job\nRequests", icon = Icons.Default.Notifications, bgColor = ColorBlue, badgeCount = pendingJobCount, onClick = onNavigateToJobFeed)
        HorizontalGridCard(title = if (isSinhala) "සිතියම\n(Live Map)" else "Live\nMap", icon = Icons.Default.Place, bgColor = ColorLightBlue, onClick = onNavigateToMap)
        HorizontalGridCard(title = if (isSinhala) "මගේ\nඉපැයීම්" else "My\nEarnings", icon = Icons.Default.ShoppingCart, bgColor = ColorGreen, onClick = onNavigateToWallet)
        HorizontalGridCard(title = if (isSinhala) "මගේ\nගිණුම" else "My\nProfile", icon = Icons.Default.AccountCircle, bgColor = ColorDarkNavy, onClick = onNavigateToProfile)
    }
}

@Composable
fun HorizontalGridCard(title: String, icon: ImageVector, bgColor: Color, badgeCount: Int = 0, onClick: () -> Unit) {
    Box(modifier = Modifier.width(110.dp).height(120.dp)) {
        Card(
            modifier = Modifier.fillMaxSize().clickable { onClick() },
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(containerColor = bgColor),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Column(modifier = Modifier.fillMaxSize().padding(12.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(imageVector = icon, contentDescription = title, tint = Color.White, modifier = Modifier.size(32.dp))
                Spacer(modifier = Modifier.height(12.dp))
                Text(text = title, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 13.sp, textAlign = TextAlign.Center, lineHeight = 16.sp)
            }
        }

        if (badgeCount > 0) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(top = 8.dp, end = 8.dp)
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFEF4444))
                    .border(2.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = if (badgeCount > 9) "9+" else badgeCount.toString(),
                    color = Color.White,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
fun CircularCaregiverCard(caregiver: User, onClick: () -> Unit) {
    val isSuperCaregiver = caregiver.rating >= 4.8 && caregiver.reviewCount >= 5
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.width(85.dp).clickable { onClick() }
    ) {
        Box(contentAlignment = Alignment.BottomCenter) {
            if (caregiver.profileImageUrl.isNotEmpty()) {
                val bitmap = convertBase64ToBitmapHome(caregiver.profileImageUrl)
                if (bitmap != null) {
                    Image(bitmap = bitmap.asImageBitmap(), contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(72.dp).clip(CircleShape).border(if(isSuperCaregiver) 3.dp else 2.dp, if(isSuperCaregiver) Color(0xFFFFD700) else Color.White, CircleShape))
                } else {
                    Box(modifier = Modifier.size(72.dp).clip(CircleShape).background(Color(0xFFE2E8F0)).border(if(isSuperCaregiver) 3.dp else 0.dp, if(isSuperCaregiver) Color(0xFFFFD700) else Color.Transparent, CircleShape), contentAlignment = Alignment.Center) {
                        Text(text = if (caregiver.name.isNotEmpty()) caregiver.name.first().toString().uppercase() else "?", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                    }
                }
            } else {
                Box(modifier = Modifier.size(72.dp).clip(CircleShape).background(Color(0xFFE2E8F0)).border(if(isSuperCaregiver) 3.dp else 0.dp, if(isSuperCaregiver) Color(0xFFFFD700) else Color.Transparent, CircleShape), contentAlignment = Alignment.Center) {
                    Text(text = if (caregiver.name.isNotEmpty()) caregiver.name.first().toString().uppercase() else "?", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                }
            }

            if (isSuperCaregiver) {
                Box(
                    modifier = Modifier
                        .offset(x = 24.dp, y = (-50).dp)
                        .clip(CircleShape)
                        .background(Color(0xFFFFD700))
                        .size(22.dp)
                        .border(1.dp, Color.White, CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(Icons.Default.Star, contentDescription = "Super", tint = Color.White, modifier = Modifier.size(14.dp))
                }
            }

            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                elevation = CardDefaults.cardElevation(2.dp),
                modifier = Modifier.offset(y = 8.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)) {
                    Text(String.format(Locale.US, "%.1f", caregiver.rating), fontSize = 10.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                    Spacer(modifier = Modifier.width(2.dp))
                    Icon(Icons.Default.Star, contentDescription = "Rating", tint = Color(0xFFF59E0B), modifier = Modifier.size(10.dp))
                }
            }
        }

        Spacer(modifier = Modifier.height(14.dp))
        Text(caregiver.name.split(" ").first(), fontSize = 12.sp, fontWeight = FontWeight.Bold, color = ColorDarkNavy, maxLines = 1)
    }
}

fun convertBase64ToBitmapHome(base64Str: String): Bitmap? {
    return try {
        val pureBase64 = base64Str.substringAfter("base64,")
        val decodedBytes = Base64.decode(pureBase64, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)
    } catch (e: Exception) { null }
}

suspend fun compressImageUriToBase64Home(context: Context, uri: Uri): String? {
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