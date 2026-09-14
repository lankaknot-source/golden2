package com.kina.care.presentation.bookings

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.provider.MediaStore
import android.net.Uri
import android.os.Build
import android.util.Base64
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.kina.care.domain.model.Booking
import com.kina.care.presentation.util.LocalIsSinhala
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookingsScreen(
    onBackClick: () -> Unit,
    onNavigateToChat: (String) -> Unit,
    onNavigateToLogs: (String, String) -> Unit = { _, _ -> },
    viewModel: BookingsViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    var hasDismissedGeofenceAlert by remember { mutableStateOf(false) }
    val isSinhala = LocalIsSinhala.current.value

    LaunchedEffect(uiState.isCaregiverAway) {
        if (!uiState.isCaregiverAway) hasDismissedGeofenceAlert = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isSinhala) "මගේ වෙන්කිරීම්" else "My Bookings", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = onBackClick) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF1A5276))
            )
        }
    ) { paddingValues ->
        Box(modifier = Modifier.fillMaxSize().background(Color(0xFFF4F8FB)).padding(paddingValues)) {
            when {
                uiState.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = Color(0xFF1A5276))
                uiState.bookings.isEmpty() -> {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.align(Alignment.Center)) {
                        Icon(Icons.Default.DateRange, contentDescription = null, modifier = Modifier.size(64.dp), tint = Color.LightGray)
                        Text(if (isSinhala) "දැනට වෙන්කිරීම් කිසිවක් නොමැත." else "No bookings available.", color = Color.Gray, modifier = Modifier.padding(top = 16.dp))
                    }
                }
                else -> {
                    val activeBooking = uiState.bookings.find { it.status == "ACCEPTED" || it.status == "IN_PROGRESS" || it.status == "PENDING" || it.status == "BROADCASTED" }
                    val historyBookings = uiState.bookings.filter { it.status == "COMPLETED" || it.status == "CANCELLED" }

                    LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        if (activeBooking != null) {
                            item {
                                Text(if (isSinhala) "ක්‍රියාකාරී සේවාව" else "Active Service", fontWeight = FontWeight.Bold, color = Color(0xFF1A5276), modifier = Modifier.padding(bottom = 8.dp))
                                BookingCard(booking = activeBooking, viewModel = viewModel, onChat = { onNavigateToChat(activeBooking.id) }, onLogs = { onNavigateToLogs(activeBooking.id, activeBooking.elderId) }, isUploading = uiState.isPhotoUploading, isSinhala = isSinhala)
                            }
                        }

                        if (historyBookings.isNotEmpty()) {
                            item { Text(if (isSinhala) "සේවා ඉතිහාසය" else "Service History", fontWeight = FontWeight.Bold, color = Color.Gray, modifier = Modifier.padding(bottom = 8.dp)) }
                            items(historyBookings) { booking ->
                                BookingCard(booking = booking, viewModel = viewModel, onChat = { onNavigateToChat(booking.id) }, onLogs = { onNavigateToLogs(booking.id, booking.elderId) }, isUploading = false, isSinhala = isSinhala)
                            }
                        }
                    }
                }
            }

            if (uiState.isCaregiverAway && !hasDismissedGeofenceAlert) {
                AlertDialog(
                    onDismissRequest = { hasDismissedGeofenceAlert = true },
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Default.Warning, contentDescription = "Warning", tint = Color.Red, modifier = Modifier.size(28.dp))
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(if (isSinhala) "සේවකයා පිටතට ගොස් ඇත! 🚨" else "Caregiver Away! 🚨", fontWeight = FontWeight.Bold, color = Color.Red, fontSize = 18.sp)
                        }
                    },
                    text = {
                        Text(
                            if (isSinhala) "අවධානයට: ඔබගේ සේවකයා සේවා ස්ථානයෙන් (රෝගියා සිටින තැනින්) මීටර් 50කට වඩා ඈතට ගොස් ඇති බව නිරීක්ෂණය විය.\n\nමෙම සිදුවීම පද්ධතිය විසින් Admin වෙතද වාර්තා කර ඇත." else "Attention: It has been observed that your caregiver has moved more than 50 meters away from the patient's location.\n\nThis incident has been reported to the Admin.",
                            fontSize = 15.sp, color = Color.DarkGray
                        )
                    },
                    confirmButton = {
                        Button(
                            onClick = { hasDismissedGeofenceAlert = true },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A5276))
                        ) { Text(if (isSinhala) "මම දැනුවත් වුණා" else "Acknowledge") }
                    }
                )
            }
        }
    }
}

@Composable
fun BookingCard(booking: Booking, viewModel: BookingsViewModel, onChat: () -> Unit, onLogs: () -> Unit, isUploading: Boolean, isSinhala: Boolean) {
    val statusColor = when (booking.status) {
        "PENDING", "BROADCASTED" -> Color(0xFFF59E0B)
        "ACCEPTED" -> Color(0xFF0EA5E9)
        "IN_PROGRESS" -> Color(0xFF10B981)
        "COMPLETED" -> Color(0xFF3B82F6)
        else -> Color.Gray
    }

    val context = LocalContext.current
    val currentUserId = FirebaseAuth.getInstance().currentUser?.uid
    val isClient = booking.clientId == currentUserId

    var enteredCode by remember { mutableStateOf("") }
    var currentTimeMillis by remember { mutableStateOf(System.currentTimeMillis()) }
    var showRatingDialog by remember { mutableStateOf(false) }
    var showEndJobVerificationDialog by remember { mutableStateOf(false) }

    var showReplacementDialog by remember { mutableStateOf(false) }
    var replacementReason by remember { mutableStateOf("") }
    var isReplacing by remember { mutableStateOf(false) }

    var showManualPaymentDialog by remember { mutableStateOf(false) }

    var showComplaintResponseDialog by remember { mutableStateOf(false) }
    var complaintResponseText by remember { mutableStateOf("") }

    var tempTaskName by remember { mutableStateOf("") }
    var currentTempUri by remember { mutableStateOf<Uri?>(null) }

    fun getTempUri(): Uri {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val imageFile = File.createTempFile("PROOF_${timeStamp}_", ".jpg", File(context.cacheDir, "images").apply { mkdirs() })
        return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", imageFile)
    }

    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (success && currentTempUri != null && tempTaskName.isNotEmpty()) {
            viewModel.updateTaskWithProof(context, booking.id, tempTaskName, true, currentTempUri, booking)
        }
    }

    val cameraPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { isGranted ->
        if (isGranted) { currentTempUri = getTempUri(); cameraLauncher.launch(currentTempUri!!) }
        else { Toast.makeText(context, if (isSinhala) "කැමරා අවසරය අවශ්‍යයි!" else "Camera permission is required!", Toast.LENGTH_SHORT).show() }
    }

    fun takeProofPhoto(taskName: String) {
        tempTaskName = taskName
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            currentTempUri = getTempUri(); cameraLauncher.launch(currentTempUri!!)
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    LaunchedEffect(booking.status, booking.isClientEnded) {
        if (booking.status == "IN_PROGRESS" && !booking.isClientEnded) {
            while (isActive) { delay(1000); currentTimeMillis = System.currentTimeMillis() }
        }
    }

    val startTime = booking.startTime ?: 0L
    val endTime = booking.endTime ?: 0L
    val timePassedMs = if (startTime > 0L) {
        if (booking.status == "COMPLETED" && endTime > 0L) { endTime - startTime }
        else if (booking.status == "IN_PROGRESS") { currentTimeMillis - startTime }
        else { 0L }
    } else { 0L }

    val hoursPassed = if (timePassedMs > 0) timePassedMs.toDouble() / (1000.0 * 60 * 60) else 0.0
    val currentCalculatedEarning = if (booking.totalAmount > 0) booking.totalAmount else (hoursPassed * booking.hourlyRate)
    val formattedEarning = try { String.format(Locale.US, "%,.2f", currentCalculatedEarning) } catch (e: Exception) { "0.00" }

    fun generateAndShareInvoiceImage() {
        try {
            val width = 1200
            val height = 1600
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val bgPaint = Paint().apply { color = android.graphics.Color.WHITE }
            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)

            val darkBlue = android.graphics.Color.parseColor("#0D3B66")
            val logoGreen = android.graphics.Color.parseColor("#53A548")
            val lightBg = android.graphics.Color.parseColor("#F1F5F9")
            val lightGreenBg = android.graphics.Color.parseColor("#E8F5E9")

            val textPaint = Paint().apply { color = android.graphics.Color.DKGRAY; textSize = 28f; isAntiAlias = true }
            val boldPaint = Paint().apply { color = android.graphics.Color.BLACK; textSize = 30f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
            val titlePaint = Paint().apply { color = darkBlue; textSize = 70f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
            val subTitlePaint = Paint().apply { color = android.graphics.Color.GRAY; textSize = 36f; isAntiAlias = true }
            val linePaint = Paint().apply { color = android.graphics.Color.LTGRAY; strokeWidth = 2f; isAntiAlias = true }

            var yY = 120f
            val startX = 80f
            val rightX = width - 80f

            val companyNamePaint = Paint().apply { color = logoGreen; textSize = 38f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
            canvas.drawText("Golden Hand Caregivers Pvt.Ltd", startX, yY, companyNamePaint)
            yY += 45f
            canvas.drawText("No 200/108 Peradeniya Road", startX, yY, textPaint)
            yY += 40f
            canvas.drawText("Kandy 20000", startX, yY, textPaint)
            yY += 40f
            canvas.drawText("Sri Lanka", startX, yY, textPaint)
            yY += 40f
            canvas.drawText("goldenhandcaregivers@gmail.com", startX, yY, textPaint)

            yY = 120f
            titlePaint.textAlign = Paint.Align.RIGHT
            canvas.drawText("Invoice", rightX, yY, titlePaint)

            yY += 60f
            subTitlePaint.textAlign = Paint.Align.RIGHT
            val shortId = booking.id.take(6).uppercase()
            canvas.drawText("Invoice INV-$shortId", rightX, yY, subTitlePaint)

            yY += 80f
            val balLabelPaint = Paint().apply { color = android.graphics.Color.DKGRAY; textSize = 32f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.RIGHT; isAntiAlias = true }
            canvas.drawText("Balance Due", rightX, yY, balLabelPaint)

            yY += 50f
            val balValuePaint = Paint().apply { color = darkBlue; textSize = 40f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.RIGHT; isAntiAlias = true }
            canvas.drawText("LKR $formattedEarning", rightX, yY, balValuePaint)

            yY = 400f
            boldPaint.textAlign = Paint.Align.LEFT
            canvas.drawText("Bill To:", startX, yY, boldPaint)
            yY += 45f

            val addrLine = if (booking.address.length > 35) booking.address.take(35) + "..." else booking.address.ifEmpty { "Client Location" }
            canvas.drawText("Client: ${booking.clientId.take(8).uppercase()}", startX, yY, textPaint)
            yY += 40f
            canvas.drawText(addrLine, startX, yY, textPaint)

            yY = 400f
            val metaLabel = Paint().apply { color = android.graphics.Color.GRAY; textSize = 28f; textAlign = Paint.Align.LEFT; isAntiAlias = true }
            val metaValue = Paint().apply { color = android.graphics.Color.BLACK; textSize = 28f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.LEFT; isAntiAlias = true }

            val dateFormat = SimpleDateFormat("dd MMMM yyyy", Locale.getDefault())
            val dateStr = dateFormat.format(Date(booking.endTime ?: System.currentTimeMillis()))

            val metaLblX = width - 450f
            val metaValX = width - 250f

            canvas.drawText("Invoice Date:", metaLblX, yY, metaLabel)
            canvas.drawText(dateStr, metaValX, yY, metaValue)
            yY += 50f
            canvas.drawText("Terms:", metaLblX, yY, metaLabel)
            canvas.drawText("Custom", metaValX, yY, metaValue)
            yY += 50f
            canvas.drawText("Due Date:", metaLblX, yY, metaLabel)
            canvas.drawText(dateStr, metaValX, yY, metaValue)

            yY += 150f
            val tableTop = yY - 40f
            val tableBg = Paint().apply { color = lightBg; style = Paint.Style.FILL }
            canvas.drawRect(startX, tableTop, rightX, tableTop + 70f, tableBg)

            val tblHead = Paint().apply { color = darkBlue; textSize = 28f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
            val col1 = startX + 20f
            val col2 = startX + 120f
            val col3 = startX + 550f
            val col4 = startX + 750f
            val col5 = rightX - 20f

            tblHead.textAlign = Paint.Align.LEFT
            canvas.drawText("#", col1, yY + 5f, tblHead)
            canvas.drawText("Item Details", col2, yY + 5f, tblHead)
            canvas.drawText("Rate", col3, yY + 5f, tblHead)
            canvas.drawText("Hours", col4, yY + 5f, tblHead)

            tblHead.textAlign = Paint.Align.RIGHT
            canvas.drawText("Amount", col5, yY + 5f, tblHead)

            yY += 90f
            val rowTxt = Paint().apply { color = android.graphics.Color.BLACK; textSize = 28f; isAntiAlias = true }
            rowTxt.textAlign = Paint.Align.LEFT

            canvas.drawText("1", col1, yY, rowTxt)
            canvas.drawText("${booking.careCategory} - ${booking.serviceType}", col2, yY, rowTxt)
            canvas.drawText(String.format(Locale.US, "%,.2f", booking.hourlyRate), col3, yY, rowTxt)
            canvas.drawText(String.format(Locale.US, "%.2f", hoursPassed), col4, yY, rowTxt)

            rowTxt.textAlign = Paint.Align.RIGHT
            canvas.drawText(formattedEarning, col5, yY, rowTxt)

            yY += 60f
            canvas.drawLine(startX, yY, rightX, yY, linePaint)

            yY += 60f
            val labelCol = col4
            val valCol = col5

            val totLabel = Paint().apply { color = android.graphics.Color.DKGRAY; textSize = 30f; isAntiAlias = true; textAlign = Paint.Align.LEFT }
            val totVal = Paint().apply { color = android.graphics.Color.BLACK; textSize = 30f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true; textAlign = Paint.Align.RIGHT }

            canvas.drawText("Sub Total", labelCol, yY, totLabel)
            canvas.drawText(formattedEarning, valCol, yY, rowTxt)

            yY += 50f
            canvas.drawText("Total", labelCol, yY, totVal)
            canvas.drawText("LKR $formattedEarning", valCol, yY, totVal)

            yY += 60f
            val balBg = Paint().apply { color = lightGreenBg; style = Paint.Style.FILL }
            canvas.drawRect(labelCol - 20f, yY - 45f, rightX, yY + 25f, balBg)

            val balLabel = Paint().apply { color = logoGreen; textSize = 32f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true; textAlign = Paint.Align.LEFT }
            val balAmount = Paint().apply { color = logoGreen; textSize = 32f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true; textAlign = Paint.Align.RIGHT }

            canvas.drawText("Balance Due", labelCol, yY, balLabel)
            canvas.drawText("LKR $formattedEarning", valCol, yY, balAmount)

            yY += 150f
            val noteHead = Paint().apply { color = android.graphics.Color.GRAY; textSize = 26f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
            canvas.drawText("Notes", startX, yY, noteHead)
            yY += 40f
            canvas.drawText("It was great doing services with you.", startX, yY, textPaint)

            yY = height - 80f
            val footer = Paint().apply {
                color = android.graphics.Color.GRAY
                textSize = 24f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.ITALIC)
                isAntiAlias = true
                textAlign = Paint.Align.CENTER
            }
            canvas.drawText("Crafted with ease using Golden Hand Caregivers App", width / 2f, yY, footer)

            val imagesDir = File(context.cacheDir, "images")
            imagesDir.mkdirs()
            val imageFile = File(imagesDir, "Invoice_${booking.id.take(6)}.png")

            val outputStream = FileOutputStream(imageFile)
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            outputStream.flush()
            outputStream.close()

            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", imageFile)

            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "image/png"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_TEXT, "Here is your professional invoice from Golden Hand Caregivers! 💰")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(shareIntent, "Share Invoice via"))

        } catch (e: Exception) {
            e.printStackTrace()
            Toast.makeText(context, if (isSinhala) "ඉන්වොයිසිය සෑදීමට නොහැක: ${e.message}" else "Failed to generate invoice: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }

    Card(
        modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White), elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(20.dp)) {

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Surface(shape = RoundedCornerShape(8.dp), color = statusColor.copy(alpha = 0.1f), border = BorderStroke(1.dp, statusColor)) {
                        Text(text = booking.status, color = statusColor, fontWeight = FontWeight.Bold, fontSize = 11.sp, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                    }

                    if (booking.status == "COMPLETED") {
                        val payColor = if (booking.isPaid) Color(0xFF10B981) else Color(0xFFEF4444)
                        val payText = if (booking.isPaid) "PAID" else "PENDING PAY"
                        Surface(shape = RoundedCornerShape(8.dp), color = payColor.copy(alpha = 0.1f), border = BorderStroke(1.dp, payColor)) {
                            Text(text = payText, color = payColor, fontWeight = FontWeight.Bold, fontSize = 11.sp, modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp))
                        }
                    }
                }

                if (booking.isEmergency) {
                    Surface(shape = RoundedCornerShape(8.dp), color = Color.Red, border = BorderStroke(1.dp, Color.Red)) {
                        Text("SOS", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 10.sp, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp))
                    }
                }
            }
            Spacer(modifier = Modifier.height(12.dp))

            if (booking.scheduledTime > 0L) {
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF3C7)), modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.DateRange, contentDescription = null, tint = Color(0xFFD97706), modifier = Modifier.size(24.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(if (isSinhala) "වෙන්කළ දිනය සහ වේලාව" else "Scheduled Date & Time", fontWeight = FontWeight.Bold, color = Color(0xFFB45309), fontSize = 12.sp)
                            val schedStr = SimpleDateFormat("yyyy MMM dd, hh:mm a", Locale.getDefault()).format(Date(booking.scheduledTime))
                            Text(schedStr, fontWeight = FontWeight.ExtraBold, color = Color(0xFF92400E), fontSize = 15.sp)
                        }
                    }
                }
            } else {
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFD1FAE5)), modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)) {
                    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF059669), modifier = Modifier.size(24.dp))
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(if (isSinhala) "ඉල්ලුම් කළ දිනය සහ වේලාව" else "Requested Date & Time", fontWeight = FontWeight.Bold, color = Color(0xFF047857), fontSize = 12.sp)
                            val reqStr = SimpleDateFormat("yyyy MMM dd, hh:mm a", Locale.getDefault()).format(Date(booking.requestedTime))
                            Text(reqStr, fontWeight = FontWeight.ExtraBold, color = Color(0xFF065F46), fontSize = 15.sp)
                            Text(if (isSinhala) "වහාම අවශ්‍යයි" else "Immediate Requirement", color = Color(0xFF047857), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                    }
                }
            }

            Text(text = booking.jobDescription.ifEmpty { "N/A" }, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))

            if (booking.status != "COMPLETED" && booking.status != "PENDING" && booking.status != "BROADCASTED") {
                Spacer(modifier = Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    OutlinedButton(
                        onClick = onChat,
                        modifier = Modifier.weight(1f).height(40.dp),
                        shape = RoundedCornerShape(10.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF0EA5E9))
                    ) {
                        Icon(Icons.Default.Email, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(if (isSinhala) "පණිවිඩ" else "Messages", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }

                    OutlinedButton(
                        onClick = onLogs,
                        modifier = Modifier.weight(1f).height(40.dp),
                        shape = RoundedCornerShape(10.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF10B981))
                    ) {
                        Icon(Icons.Default.List, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(if (isSinhala) "දෛනික වාර්තා" else "Care Logs", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                    }
                }
            } else if (booking.status == "COMPLETED") {
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedButton(
                    onClick = onLogs,
                    modifier = Modifier.fillMaxWidth().height(40.dp),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF10B981))
                ) {
                    Icon(Icons.Default.List, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(if (isSinhala) "දෛනික වාර්තා (Daily Logs)" else "View Care Logs", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
            }

            if (booking.status == "PENDING" || booking.status == "BROADCASTED") {
                if (isClient) {
                    Spacer(modifier = Modifier.height(16.dp))
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFF1F5F9)), modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(modifier = Modifier.size(24.dp), color = Color.Gray, strokeWidth = 2.dp)
                            Spacer(modifier = Modifier.height(8.dp))
                            Text(if (isSinhala) "සේවකයෙකු භාරගත් පසු OTP කේතය පෙන්වනු ඇත." else "OTP code will be shown after a caregiver accepts.", color = Color.Gray, fontSize = 13.sp, textAlign = TextAlign.Center)
                            Text(if (isSinhala) "(සාත්තු සේවකයෙකු භාරගන්නා තෙක් රැඳී සිටින්න)" else "(Waiting for a Caregiver to accept)", color = Color.Gray, fontSize = 11.sp, textAlign = TextAlign.Center)
                        }
                    }
                }
            }

            if (booking.status == "ACCEPTED") {
                Spacer(modifier = Modifier.height(16.dp))
                if (isClient) {
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFEFF6FF)), modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(if (isSinhala) "මෙම කේතය ඔබගේ සේවකයාට ලබා දෙන්න" else "Provide this code to your Caregiver", color = Color(0xFF1E3A8A), fontSize = 13.sp)
                            Text(booking.startCode, fontSize = 36.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF2563EB), letterSpacing = 6.sp)
                        }
                    }
                } else {
                    OutlinedTextField(
                        value = enteredCode, onValueChange = { if(it.length <= 5) enteredCode = it.uppercase() },
                        label = { Text(if (isSinhala) "සේවාදායකයාගෙන් ලැබුණු කේතය ඇතුලත් කරන්න" else "Enter the code from Client") }, modifier = Modifier.fillMaxWidth(), singleLine = true
                    )
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(
                        onClick = { viewModel.startJob(context, booking, enteredCode) { _, msg -> Toast.makeText(context, msg, Toast.LENGTH_SHORT).show() } },
                        modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981))
                    ) { Text(if (isSinhala) "ආරම්භ කරන්න" else "Check-In (Start)", fontWeight = FontWeight.Bold, fontSize = 18.sp) }
                }
            }

            if (booking.status == "IN_PROGRESS" || booking.status == "COMPLETED") {
                Spacer(modifier = Modifier.height(16.dp))

                Card(
                    modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)),
                    border = BorderStroke(1.dp, Color(0xFFE2E8F0))
                ) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                            Text(if (isSinhala) "රාජකාරි ලැයිස්තුව" else "Duty Summary Checklist", fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66))
                            if (isUploading) {
                                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp, color = Color(0xFF0EA5E9))
                            }
                        }
                        Spacer(modifier = Modifier.height(8.dp))

                        if (booking.requestedTasks.isEmpty()) {
                            Text(if (isSinhala) "විශේෂිත රාජකාරි ලැයිස්තුගත කර නොමැත." else "No specific duties listed.", color = Color.Gray, fontSize = 12.sp)
                        } else {
                            booking.requestedTasks.forEach { task ->
                                val isCompleted = booking.completedTasks.contains(task)
                                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().padding(vertical = 0.dp)) {
                                    Checkbox(
                                        checked = isCompleted,
                                        onCheckedChange = { checked ->
                                            if (!isClient && booking.status == "IN_PROGRESS") {
                                                if (checked) {
                                                    takeProofPhoto(task)
                                                } else {
                                                    viewModel.updateTaskWithProof(context, booking.id, task, false, null, booking)
                                                }
                                            }
                                        },
                                        enabled = !isClient && booking.status == "IN_PROGRESS" && !isUploading,
                                        colors = CheckboxDefaults.colors(checkedColor = Color(0xFF10B981), disabledCheckedColor = Color(0xFF10B981).copy(alpha=0.6f))
                                    )
                                    Text(text = task, fontSize = 13.sp, color = if (isCompleted) Color(0xFF10B981) else Color.Gray)
                                }
                            }
                        }
                    }
                }

                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFF0FDF4)), modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(if (booking.status == "COMPLETED") (if (isSinhala) "අවසන් මුදල" else "Final Total Amount") else (if (isSinhala) "ඇස්තමේන්තුගත මුදල" else "Current Estimated Amount"), color = Color.Gray, fontSize = 14.sp)
                        Text("Rs. $formattedEarning", fontSize = 36.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF047857))

                        if (isClient && booking.status == "IN_PROGRESS") {
                            Text(if (isSinhala) "(සේවකයාගේ ගාස්තුව: පැයකට Rs. ${booking.hourlyRate})" else "(Caregiver Rate: Rs. ${booking.hourlyRate}/hr)", color = Color.Gray, fontSize = 11.sp, modifier = Modifier.padding(top=4.dp))
                        }

                        if (!isClient && booking.status == "COMPLETED") {
                            Text(if (isSinhala) "(ආයතනික කොමිස් මුදල අඩු කර ඇත)" else "(Platform Commission Deducted)", color = Color.Gray, fontSize = 10.sp, modifier = Modifier.padding(top=4.dp))
                        }
                    }
                }

                if (booking.status == "COMPLETED" && !isClient && booking.hasComplaint) {
                    Spacer(modifier = Modifier.height(16.dp))
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)), border = BorderStroke(1.dp, Color.Red), modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.Warning, contentDescription = null, tint = Color.Red, modifier = Modifier.size(20.dp))
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(if(isSinhala) "සේවාදායකයාගේ පැමිණිල්ල" else "Client Complaint", color = Color.Red, fontWeight = FontWeight.Bold)
                            }
                            Text(booking.complaintNotes, color = Color(0xFF991B1B), fontSize = 14.sp, modifier = Modifier.padding(top=8.dp))

                            if (booking.caregiverResponse.isEmpty()) {
                                Spacer(modifier = Modifier.height(12.dp))
                                Button(
                                    onClick = { showComplaintResponseDialog = true },
                                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red),
                                    modifier = Modifier.fillMaxWidth()
                                ) { Text(if(isSinhala) "පැමිණිල්ලට පිළිතුරු දෙන්න" else "Respond to Complaint") }
                            } else {
                                Spacer(modifier = Modifier.height(12.dp))
                                HorizontalDivider(color = Color.Red.copy(alpha=0.3f))
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(if(isSinhala) "ඔබගේ පිළිතුර:" else "Your Response:", color = Color.Gray, fontSize = 12.sp)
                                Text(booking.caregiverResponse, color = Color(0xFF1E293B), fontSize = 14.sp, fontWeight = FontWeight.Medium)
                            }
                        }
                    }
                }

                if (booking.status == "IN_PROGRESS" && isClient && !booking.isClientEnded) {
                    Spacer(modifier = Modifier.height(12.dp))
                    Button(
                        onClick = { showEndJobVerificationDialog = true },
                        modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                    ) { Text(if (isSinhala) "රැකියාව අවසන් කරන්න" else "End Job", fontWeight = FontWeight.Bold, fontSize = 18.sp) }
                }

                if (booking.status == "COMPLETED" && isClient && !booking.isPaid) {
                    Spacer(modifier = Modifier.height(16.dp))

                    Button(
                        onClick = { showManualPaymentDialog = true },
                        modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981))
                    ) {
                        Icon(Icons.Default.AccountBox, contentDescription = null, tint=Color.White, modifier = Modifier.padding(end=8.dp).size(18.dp))
                        Text(if (isSinhala) "බැංකු රිසිට්පත මගින් ගෙවන්න" else "Pay via Bank Slip", fontWeight = FontWeight.Bold, fontSize = 16.sp, color=Color.White)
                    }
                }

                // Payment කරලා තියෙනවා නම් Rate කරන්න දෙන්න. (Rate කරලත් ඉවර නම් මුකුත් පෙන්නන්න එපා හෝ "Rated" කියලා පෙන්නන්න)
                if (booking.status == "COMPLETED" && booking.isPaid && isClient) {
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {

                        OutlinedButton(
                            onClick = { generateAndShareInvoiceImage() },
                            modifier = Modifier.weight(1f).height(50.dp), shape = RoundedCornerShape(12.dp),
                            colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF0D3B66))
                        ) {
                            Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.padding(end=8.dp).size(18.dp))
                            Text(if (isSinhala) "ඉන්වොයිසිය" else "Share Invoice", fontWeight = FontWeight.Bold)
                        }

                        if (!booking.isRated && booking.caregiverId != null) {
                            Button(
                                onClick = { showRatingDialog = true },
                                modifier = Modifier.weight(1f).height(50.dp), shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF59E0B))
                            ) {
                                Icon(Icons.Default.Star, contentDescription = null, modifier = Modifier.padding(end=8.dp).size(18.dp))
                                Text(if (isSinhala) "Rate කරන්න" else "Rate Us", fontWeight = FontWeight.Bold)
                            }
                        } else if (booking.isRated) {
                            Card(modifier = Modifier.weight(1f).height(50.dp), colors = CardDefaults.cardColors(containerColor = Color(0xFFD1FAE5))) {
                                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                    Text(if (isSinhala) "✅ අදහස් දක්වා ඇත" else "✅ Rated", color = Color(0xFF047857), fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }

                // Caregiver ගේ පැත්තෙන් Confirm කිරීමේ බටන් එක (Rate කරලා ඉවර නම් මේක ඕනෙ නෑ)
                if (booking.status == "COMPLETED" && !isClient && !booking.isCaregiverAcceptedEnd && !booking.isRated) {
                    Spacer(modifier = Modifier.height(12.dp))
                    if (booking.isPaid) {
                        Button(
                            onClick = { viewModel.confirmJobEndByCaregiver(booking.id, currentCalculatedEarning) { _, msg -> Toast.makeText(context, msg, Toast.LENGTH_SHORT).show() } },
                            modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3B82F6))
                        ) { Text(if (isSinhala) "තහවුරු කර අවසන් කරන්න" else "Confirm & Finish", fontWeight = FontWeight.Bold, fontSize = 16.sp) }
                    } else {
                        Text(if (isSinhala) "සේවාදායකයා ගෙවීම් කරන තෙක් රැඳී සිටින්න..." else "Waiting for Client Payment...", color = Color.Gray, modifier = Modifier.padding(top=16.dp).align(Alignment.CenterHorizontally))
                    }
                }
            }

            if (isClient && (booking.status == "ACCEPTED" || booking.status == "IN_PROGRESS") && !booking.isClientEnded) {
                Spacer(modifier = Modifier.height(12.dp))
                OutlinedButton(
                    onClick = { showReplacementDialog = true },
                    modifier = Modifier.fillMaxWidth().height(45.dp),
                    shape = RoundedCornerShape(10.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFD97706)),
                    border = BorderStroke(1.dp, Color(0xFFD97706))
                ) {
                    Icon(Icons.Default.Refresh, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(if (isSinhala) "වෙනත් සේවකයෙකු ඉල්ලන්න" else "Request Replacement", fontWeight = FontWeight.Bold, fontSize = 13.sp)
                }
            }
        }

        if (showManualPaymentDialog) {
            ManualPaymentDialog(
                booking = booking,
                isSinhala = isSinhala,
                viewModel = viewModel, // 🌟 Updated here
                onDismiss = { showManualPaymentDialog = false },
                onSuccess = {
                    showManualPaymentDialog = false
                    showRatingDialog = true
                }
            )
        }

        if (showComplaintResponseDialog) {
            AlertDialog(
                onDismissRequest = { showComplaintResponseDialog = false },
                title = { Text(if(isSinhala) "පැමිණිල්ලට පිළිතුරු දීම" else "Complaint Response", fontWeight = FontWeight.Bold, color = Color.Red) },
                text = {
                    Column {
                        Text(if(isSinhala) "සේවාදායකයාගේ පැමිණිල්ල සඳහා ඔබගේ නිදහසට කරුණ මෙහි ලියන්න. මෙය Admin හට පෙනෙනු ඇත." else "Enter your explanation for this complaint. This will be visible to the Admin.", fontSize = 13.sp, color = Color.Gray, modifier = Modifier.padding(bottom = 8.dp))
                        OutlinedTextField(
                            value = complaintResponseText, onValueChange = { complaintResponseText = it },
                            label = { Text(if(isSinhala) "ඔබගේ පිළිතුර" else "Your Response") },
                            modifier = Modifier.fillMaxWidth().height(100.dp), maxLines = 3
                        )
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (complaintResponseText.isNotBlank()) {
                                viewModel.submitComplaintResponse(booking.id, complaintResponseText) { success, msg ->
                                    Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                                    if(success) showComplaintResponseDialog = false
                                }
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                    ) { Text(if(isSinhala) "යවන්න" else "Submit") }
                },
                dismissButton = { TextButton(onClick = { showComplaintResponseDialog = false }) { Text(if(isSinhala) "අවලංගු කරන්න" else "Cancel") } }
            )
        }

        if (showReplacementDialog) {
            AlertDialog(
                onDismissRequest = { if (!isReplacing) showReplacementDialog = false },
                title = { Text(if (isSinhala) "සේවකයා මාරු කිරීමේ ඉල්ලීම" else "Caregiver Replacement Request", fontWeight = FontWeight.Bold, color = Color(0xFFD97706)) },
                text = {
                    Column {
                        Text(if (isSinhala) "වෙනත් සේවකයෙකු ලබා දීමට අවශ්‍ය ප්‍රධාන හේතුව පහතින් සඳහන් කරන්න." else "Please state the main reason for requesting a different caregiver.", fontSize = 13.sp, color = Color.Gray, modifier = Modifier.padding(bottom = 12.dp))
                        OutlinedTextField(
                            value = replacementReason, onValueChange = { replacementReason = it },
                            label = { Text(if (isSinhala) "හේතුව" else "Reason") },
                            modifier = Modifier.fillMaxWidth().height(100.dp), maxLines = 3
                        )
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            if (replacementReason.trim().isEmpty()) {
                                Toast.makeText(context, if (isSinhala) "කරුණාකර හේතුවක් ඇතුළත් කරන්න!" else "Please enter a reason!", Toast.LENGTH_SHORT).show()
                            } else {
                                isReplacing = true
                                viewModel.requestCaregiverReplacement(booking.id, replacementReason) { success, msg ->
                                    isReplacing = false
                                    Toast.makeText(context, msg, Toast.LENGTH_LONG).show()
                                    if (success) showReplacementDialog = false
                                }
                            }
                        },
                        enabled = !isReplacing,
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFD97706))
                    ) {
                        if (isReplacing) CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Color.White)
                        else Text(if (isSinhala) "ඉල්ලීම යවන්න" else "Send Request")
                    }
                },
                dismissButton = {
                    if (!isReplacing) TextButton(onClick = { showReplacementDialog = false }) { Text(if (isSinhala) "අවලංගු කරන්න" else "Cancel", color = Color.Gray) }
                }
            )
        }

        if (showEndJobVerificationDialog) {
            val approvedTasks = remember { mutableStateListOf<String>().apply { addAll(booking.completedTasks) } }
            var complaintNotes by remember { mutableStateOf("") }
            val hasMissingTasks = approvedTasks.size < booking.requestedTasks.size

            val finalAmount = if (booking.totalAmount > 0) booking.totalAmount else currentCalculatedEarning

            AlertDialog(
                onDismissRequest = { showEndJobVerificationDialog = false },
                title = { Text(if (isSinhala) "රාජකාරි තහවුරු කරන්න" else "Verify Duties", fontWeight = FontWeight.Bold) },
                text = {
                    Column(modifier = Modifier.verticalScroll(rememberScrollState())) {

                        Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFF0FDF4)), modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)) {
                            Column(modifier = Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(if (isSinhala) "අවසන් ගෙවිය යුතු මුදල" else "Final Amount to Pay", color = Color.Gray, fontSize = 14.sp)
                                Text("Rs. ${String.format(Locale.US, "%.2f", finalAmount)}", fontSize = 28.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF047857))
                            }
                        }

                        Text(if (isSinhala) "සත්‍ය වශයෙන්ම සිදු කළ රාජකාරි පමණක් තෝරන්න." else "Please check only the duties actually completed.", fontSize = 13.sp, color = Color.Gray)
                        Spacer(modifier = Modifier.height(12.dp))

                        booking.requestedTasks.forEach { task ->
                            val isApproved = approvedTasks.contains(task)
                            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth().clickable {
                                if(isApproved) approvedTasks.remove(task) else approvedTasks.add(task)
                            }) {
                                Checkbox(checked = isApproved, onCheckedChange = { if(it) approvedTasks.add(task) else approvedTasks.remove(task) })
                                Text(text = task, fontSize = 14.sp, color = if(isApproved) Color(0xFF1E293B) else Color.Gray)
                            }
                        }

                        if (hasMissingTasks) {
                            Spacer(modifier = Modifier.height(16.dp))
                            Card(colors = CardDefaults.cardColors(containerColor = Color(0xFFFEF2F2)), modifier = Modifier.fillMaxWidth()) {
                                Column(modifier = Modifier.padding(12.dp)) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Default.Warning, contentDescription = null, tint = Color.Red, modifier = Modifier.size(16.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text(if (isSinhala) "සම්පූර්ණ නොකළ රාජකාරි ඇත. මේ පිළිබඳව Admin දැනුවත් කරනු ඇත." else "You have unapproved duties. This will be reported to Admin.", color = Color.Red, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                                    }
                                    Spacer(modifier = Modifier.height(8.dp))
                                    OutlinedTextField(
                                        value = complaintNotes, onValueChange = { complaintNotes = it },
                                        label = { Text(if (isSinhala) "හේතුව / පැමිණිල්ල" else "Reason / Complaint") },
                                        modifier = Modifier.fillMaxWidth().height(80.dp), maxLines = 2,
                                        colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = Color.Red, focusedLabelColor = Color.Red)
                                    )
                                }
                            }
                        }
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            viewModel.endJobByClientWithVerification(booking.id, approvedTasks.toList(), hasMissingTasks, complaintNotes, finalAmount) { success, msg ->
                                Toast.makeText(context, msg, Toast.LENGTH_LONG).show()
                                if(success) {
                                    showEndJobVerificationDialog = false
                                    showManualPaymentDialog = true
                                }
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = if(hasMissingTasks) Color.Red else Color(0xFF10B981))
                    ) { Text(if(hasMissingTasks) (if(isSinhala) "වාර්තා කර අවසන් කරන්න" else "Report & End Job") else (if(isSinhala) "අනුමත කර අවසන් කරන්න" else "Approve & End Job")) }
                },
                dismissButton = { TextButton(onClick = { showEndJobVerificationDialog = false }) { Text(if (isSinhala) "අවලංගු කරන්න" else "Cancel", color = Color.Gray) } }
            )
        }

        if (showRatingDialog && booking.caregiverId != null) {
            RatingBottomSheet(isSinhala = isSinhala, onDismiss = { showRatingDialog = false }, onSubmit = { rating, comment ->
                viewModel.rateCaregiver(booking.id, booking.caregiverId!!, rating, comment) { success, msg -> Toast.makeText(context, msg, Toast.LENGTH_LONG).show(); if(success) showRatingDialog = false }
            })
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RatingBottomSheet(isSinhala: Boolean, onDismiss: () -> Unit, onSubmit: (Double, String) -> Unit) {
    var rating by remember { mutableStateOf(5) }
    var comment by remember { mutableStateOf("") }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Color.White) {
        Column(modifier = Modifier.fillMaxWidth().padding(24.dp).padding(bottom = 32.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(if (isSinhala) "සේවාව පිළිබඳ ඔබගේ අදහස" else "Your feedback on the service", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66))
            Spacer(modifier = Modifier.height(24.dp))
            Row(horizontalArrangement = Arrangement.Center) {
                for (i in 1..5) {
                    Icon(imageVector = Icons.Default.Star, contentDescription = "Star $i", tint = if (i <= rating) Color(0xFFF59E0B) else Color(0xFFE2E8F0), modifier = Modifier.size(48.dp).clickable { rating = i }.padding(4.dp))
                }
            }
            Spacer(modifier = Modifier.height(24.dp))
            OutlinedTextField(value = comment, onValueChange = { comment = it }, label = { Text(if (isSinhala) "සේවකයා පිළිබඳ කමෙන්ට් එකක්" else "Comment about the Caregiver") }, modifier = Modifier.fillMaxWidth().height(100.dp), shape = RoundedCornerShape(12.dp), maxLines = 3)
            Spacer(modifier = Modifier.height(24.dp))
            Button(onClick = { onSubmit(rating.toDouble(), comment) }, modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp), colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0EA5E9))) { Text(if (isSinhala) "ඉදිරිපත් කරන්න" else "Submit Review", fontSize = 16.sp, fontWeight = FontWeight.Bold) }
        }
    }
}

// ==========================================
// 🌟 MANUAL PAYMENT DIALOG
// ==========================================

@Composable
fun ManualPaymentDialog(
    booking: Booking,
    isSinhala: Boolean,
    viewModel: BookingsViewModel, // 🌟 Updated here
    onDismiss: () -> Unit,
    onSuccess: () -> Unit
) {
    val context = LocalContext.current
    val clipboardManager = LocalClipboardManager.current
    val coroutineScope = rememberCoroutineScope()

    var selectedImageUri by remember { mutableStateOf<Uri?>(null) }
    var capturedBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var localProcessing by remember { mutableStateOf(false) }

    val galleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) { selectedImageUri = uri; capturedBitmap = null }
    }

    val cameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        if (bitmap != null) { capturedBitmap = bitmap; selectedImageUri = null }
    }

    Dialog(
        onDismissRequest = { if (!localProcessing) onDismiss() }
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .wrapContentHeight()
                .padding(vertical = 16.dp),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = Color.White)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                    Text(if(isSinhala) "ගෙවීම් තහවුරු කිරීම" else "Verify Payment", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1A5276))
                    IconButton(onClick = onDismiss, enabled = !localProcessing) {
                        Icon(Icons.Default.Clear, contentDescription = "Close")
                    }
                }

                HorizontalDivider(modifier = Modifier.padding(bottom = 16.dp))

                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFE0F2FE)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Column(modifier = Modifier.padding(16.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(if(isSinhala) "ගෙවිය යුතු මුදල" else "Amount to Pay", fontSize = 14.sp, color = Color(0xFF0369A1))
                        Text("Rs. ${String.format(Locale.US, "%.2f", booking.totalAmount ?: 0.0)}", fontSize = 24.sp, fontWeight = FontWeight.ExtraBold, color = Color(0xFF0C4A6E))
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Text(if(isSinhala) "බැංකු ගිණුම් විස්තර (මුදල් බැර කරන්න)" else "Bank Details (Transfer to)", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color.DarkGray, modifier = Modifier.align(Alignment.Start))
                Spacer(modifier = Modifier.height(8.dp))

                Column(modifier = Modifier.fillMaxWidth().background(Color(0xFFF8FAFC), RoundedCornerShape(8.dp)).padding(12.dp)) {
                    BankDetailRow(if(isSinhala) "බැංකුව" else "Bank", "Seylan Bank", clipboardManager, context)
                    BankDetailRow(if(isSinhala) "ශාඛාව" else "Branch", "Katugasthota", clipboardManager, context)
                    BankDetailRow(if(isSinhala) "ගිණුමේ නම" else "Account Name", "Golden Hand Caregivers Pvt.Ltd", clipboardManager, context)
                    BankDetailRow(if(isSinhala) "ගිණුම් අංකය" else "Account No", "149013618480001", clipboardManager, context)
                }

                Spacer(modifier = Modifier.height(16.dp))

                Text(if(isSinhala) "රිසිට්පත අප්ලෝඩ් කරන්න" else "Upload Receipt/Slip", fontWeight = FontWeight.Bold, fontSize = 14.sp, color = Color.DarkGray, modifier = Modifier.align(Alignment.Start))
                Spacer(modifier = Modifier.height(8.dp))

                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedButton(
                        onClick = { cameraLauncher.launch(null) },
                        modifier = Modifier.weight(1f).height(45.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) { Text(if(isSinhala) "කැමරාව 📸" else "Camera 📸", fontSize = 13.sp) }

                    OutlinedButton(
                        onClick = { galleryLauncher.launch("image/*") },
                        modifier = Modifier.weight(1f).height(45.dp),
                        shape = RoundedCornerShape(8.dp)
                    ) { Text(if(isSinhala) "ගැලරිය 🖼️" else "Gallery 🖼️", fontSize = 13.sp) }
                }

                Spacer(modifier = Modifier.height(16.dp))

                if (selectedImageUri != null || capturedBitmap != null) {
                    Box(
                        modifier = Modifier.fillMaxWidth().height(150.dp).clip(RoundedCornerShape(8.dp)).background(Color.LightGray),
                        contentAlignment = Alignment.Center
                    ) {
                        if (selectedImageUri != null) {
                            AsyncImage(model = selectedImageUri, contentDescription = "Receipt", contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                        } else if (capturedBitmap != null) {
                            Image(bitmap = capturedBitmap!!.asImageBitmap(), contentDescription = "Captured", contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                        }
                    }
                }

                Spacer(modifier = Modifier.height(24.dp))

                Button(
                    onClick = {
                        if (selectedImageUri == null && capturedBitmap == null) {
                            Toast.makeText(context, if(isSinhala) "කරුණාකර රිසිට්පතක් ඇතුලත් කරන්න" else "Please attach the receipt", Toast.LENGTH_SHORT).show()
                            return@Button
                        }
                        localProcessing = true

                        coroutineScope.launch {
                            try {
                                val base64String = withContext(Dispatchers.IO) {
                                    compressAndEncodeImage(context, selectedImageUri, capturedBitmap)
                                }

                                if (base64String != null) {
                                    // 🌟 සම්පූර්ණ Payment ක්‍රියාවලිය ViewModel හරහා සිදු කිරීම
                                    val amount = booking.totalAmount ?: 0.0
                                    viewModel.submitManualPaymentAndUpdateWallet(booking.id, booking.caregiverId, amount, base64String) { success, msg ->
                                        localProcessing = false
                                        Toast.makeText(context, if(success && isSinhala) "ගෙවීම සාර්ථකයි! මුදල් Caregiver ගේ ගිණුමට එකතු විය." else msg, Toast.LENGTH_LONG).show()
                                        if (success) onSuccess()
                                    }
                                } else {
                                    localProcessing = false
                                    Toast.makeText(context, if(isSinhala) "පින්තූරය සකස් කිරීමේ දෝෂයකි" else "Image processing error", Toast.LENGTH_SHORT).show()
                                }
                            } catch (e: Exception) {
                                localProcessing = false
                                Toast.makeText(context, "දෝෂයකි: ${e.message}", Toast.LENGTH_SHORT).show()
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981)),
                    enabled = !localProcessing && (selectedImageUri != null || capturedBitmap != null)
                ) {
                    if (localProcessing) {
                        CircularProgressIndicator(color = Color.White, modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(if(isSinhala) "සකස් වෙමින් පවතී..." else "Processing...", fontSize = 14.sp)
                    } else {
                        Text(if(isSinhala) "තහවුරු කරන්න" else "Submit Payment", fontSize = 15.sp, fontWeight = FontWeight.Bold)
                    }
                }
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@Composable
fun BankDetailRow(label: String, value: String, clipboardManager: androidx.compose.ui.platform.ClipboardManager, context: Context) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(label, fontSize = 11.sp, color = Color.Gray)
            Text(value, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color.Black)
        }
        TextButton(onClick = {
            clipboardManager.setText(AnnotatedString(value))
            Toast.makeText(context, "Copied", Toast.LENGTH_SHORT).show()
        }) {
            Text("Copy", color = Color(0xFF0284C7), fontSize = 12.sp)
        }
    }
}

private fun compressAndEncodeImage(context: Context, uri: Uri?, bitmap: Bitmap?): String? {
    var actualBitmap = bitmap
    if (uri != null) {
        actualBitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                ImageDecoder.decodeBitmap(ImageDecoder.createSource(context.contentResolver, uri))
            } else {
                @Suppress("DEPRECATION")
                MediaStore.Images.Media.getBitmap(context.contentResolver, uri)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
    if (actualBitmap == null) return null

    val maxDimension = 800f
    val width = actualBitmap.width
    val height = actualBitmap.height
    val scale = minOf(maxDimension / width, maxDimension / height)

    val resizedBitmap = if (scale < 1) {
        val matrix = Matrix().apply { postScale(scale, scale) }
        Bitmap.createBitmap(actualBitmap, 0, 0, width, height, matrix, true)
    } else {
        actualBitmap
    }

    val baos = ByteArrayOutputStream()
    resizedBitmap.compress(Bitmap.CompressFormat.JPEG, 40, baos)
    val imageBytes = baos.toByteArray()
    return Base64.encodeToString(imageBytes, Base64.DEFAULT)
}