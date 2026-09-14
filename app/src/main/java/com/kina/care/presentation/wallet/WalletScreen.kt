package com.kina.care.presentation.wallet

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.net.Uri
import android.util.Base64
import android.widget.Toast
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.ExitToApp
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.core.content.FileProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kina.care.domain.model.WalletTransaction
import com.kina.care.presentation.util.LocalIsSinhala
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WalletScreen(
    onBackClick: () -> Unit,
    viewModel: WalletViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val isSinhala = LocalIsSinhala.current.value
    val context = LocalContext.current

    var selectedSlipBase64 by remember { mutableStateOf<String?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isSinhala) "මගේ පසුම්බිය" else "My Wallet", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF1A5276))
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFFF4F8FB))
                .padding(paddingValues)
        ) {
            Card(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color(0xFF1E3A8A)),
                elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
            ) {
                Column(
                    modifier = Modifier.padding(24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Icon(Icons.Default.ShoppingCart, contentDescription = null, tint = Color.White, modifier = Modifier.size(40.dp))
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(if (isSinhala) "දැනට ඇති මුදල" else "Current Balance", color = Color.LightGray, fontSize = 14.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text("Rs. ${String.format(Locale.US, "%,.2f", uiState.balance)}", color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold)
                }
            }

            Text(
                text = if (isSinhala) "ගනුදෙනු ඉතිහාසය" else "Transaction History",
                fontWeight = FontWeight.Bold,
                fontSize = 16.sp,
                color = Color(0xFF1E293B),
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )

            if (uiState.isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = Color(0xFF1A5276))
                }
            } else if (uiState.transactions.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(if (isSinhala) "දැනට ගනුදෙනු කිසිවක් නොමැත." else "No transactions yet.", color = Color.Gray)
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(uiState.transactions) { tx ->
                        TransactionCard(tx, isSinhala, context) { slipImage ->
                            selectedSlipBase64 = slipImage
                        }
                    }
                }
            }
        }

        if (selectedSlipBase64 != null) {
            Dialog(onDismissRequest = { selectedSlipBase64 = null }) {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.White),
                    modifier = Modifier.fillMaxWidth().wrapContentHeight()
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(if(isSinhala) "ගෙවීම් පත්‍රිකාව" else "Payment Bank Slip", fontWeight = FontWeight.Bold, fontSize = 18.sp, color = Color(0xFF1A5276), modifier = Modifier.padding(bottom = 16.dp))

                        val bitmap = convertBase64ToBitmap(selectedSlipBase64!!)
                        if (bitmap != null) {
                            Image(
                                bitmap = bitmap.asImageBitmap(),
                                contentDescription = "Bank Slip",
                                modifier = Modifier.fillMaxWidth().height(350.dp),
                                contentScale = ContentScale.Fit
                            )
                        } else {
                            Text("පින්තූරය ලබාගැනීමට නොහැක", color = Color.Red, modifier = Modifier.padding(32.dp))
                        }

                        Spacer(modifier = Modifier.height(16.dp))
                        Button(
                            onClick = { selectedSlipBase64 = null },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A5276))
                        ) { Text(if(isSinhala) "වසන්න" else "Close") }
                    }
                }
            }
        }
    }
}

@Composable
fun TransactionCard(tx: WalletTransaction, isSinhala: Boolean, context: Context, onViewSlip: (String) -> Unit) {
    val isCredit = tx.type == "CREDIT"
    val icon = if (isCredit) Icons.Default.Add else Icons.Default.ExitToApp
    val iconColor = if (isCredit) Color(0xFF10B981) else Color(0xFFEF4444)
    val bgColor = if (isCredit) Color(0xFFD1FAE5) else Color(0xFFFEE2E2)
    val timeString = SimpleDateFormat("yyyy MMM dd, hh:mm a", Locale.getDefault()).format(Date(tx.timestamp))

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier.size(48.dp).background(bgColor, shape = RoundedCornerShape(12.dp)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(icon, contentDescription = null, tint = iconColor)
                }
                Spacer(modifier = Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(text = tx.description, fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color(0xFF1E293B))
                    Text(text = timeString, fontSize = 12.sp, color = Color.Gray)
                }
                Text(
                    text = "${if (isCredit) "+" else "-"} Rs.${String.format(Locale.US, "%,.2f", tx.amount)}",
                    fontWeight = FontWeight.Bold,
                    fontSize = 16.sp,
                    color = iconColor
                )
            }

            // 🌟 අලුත්: Admin විසින් සල්ලි දැමූ පසු Bank Slip එක හෝ PDF Payslip එක ගැනීමේ බොත්තම්
            if (!isCredit && !tx.receiptImageUrl.isNullOrEmpty()) {
                Spacer(modifier = Modifier.height(16.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = { onViewSlip(tx.receiptImageUrl) },
                        modifier = Modifier.weight(1f).height(40.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFF1A5276)),
                        border = BorderStroke(1.dp, Color(0xFF1A5276))
                    ) {
                        Text(if(isSinhala) "රිසිට්පත බලන්න" else "View Slip", fontWeight = FontWeight.Bold, fontSize = 11.sp)
                    }

                    Button(
                        onClick = { generatePayslip(context, tx) },
                        modifier = Modifier.weight(1f).height(40.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981))
                    ) {
                        Text(if(isSinhala) "Payslip ලබාගන්න" else "Get Payslip", fontWeight = FontWeight.Bold, fontSize = 11.sp)
                    }
                }
            }
        }
    }
}

// 🌟 අලුත්: Caregiver ට Official PDF Payslip එක ජෙනරේට් කිරීම
fun generatePayslip(context: Context, tx: WalletTransaction) {
    try {
        val width = 1200
        val height = 1400
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val bgPaint = Paint().apply { color = android.graphics.Color.WHITE }
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), bgPaint)

        val darkBlue = android.graphics.Color.parseColor("#0D3B66")
        val logoGreen = android.graphics.Color.parseColor("#53A548")

        val textPaint = Paint().apply { color = android.graphics.Color.DKGRAY; textSize = 28f; isAntiAlias = true }
        val boldPaint = Paint().apply { color = android.graphics.Color.BLACK; textSize = 32f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
        val titlePaint = Paint().apply { color = logoGreen; textSize = 60f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
        val linePaint = Paint().apply { color = android.graphics.Color.LTGRAY; strokeWidth = 2f; isAntiAlias = true }

        var yY = 120f
        val startX = 80f
        val rightX = width - 80f

        // Header
        canvas.drawText("Golden Hand Caregivers Pvt.Ltd", startX, yY, titlePaint)
        yY += 45f
        canvas.drawText("Official Caregiver Payslip", startX, yY, textPaint)

        yY = 120f
        val dateStr = SimpleDateFormat("dd MMM yyyy", Locale.getDefault()).format(Date(tx.timestamp))
        val datePaint = Paint().apply { color = darkBlue; textSize = 32f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.RIGHT; isAntiAlias = true }
        canvas.drawText("Date: $dateStr", rightX, yY, datePaint)

        yY = 280f
        canvas.drawLine(startX, yY, rightX, yY, linePaint)
        yY += 80f

        // Details
        canvas.drawText("Transaction ID:", startX, yY, textPaint)
        canvas.drawText(tx.id.take(12).uppercase(), startX + 300f, yY, boldPaint)
        yY += 60f

        canvas.drawText("Description:", startX, yY, textPaint)
        canvas.drawText(tx.description, startX + 300f, yY, boldPaint)
        yY += 60f

        canvas.drawText("Payment Type:", startX, yY, textPaint)
        canvas.drawText("Direct Bank Transfer", startX + 300f, yY, boldPaint)

        yY += 100f
        canvas.drawLine(startX, yY, rightX, yY, linePaint)
        yY += 120f

        // Amount Box
        val boxBg = Paint().apply { color = android.graphics.Color.parseColor("#E8F5E9"); style = Paint.Style.FILL }
        canvas.drawRoundRect(startX, yY - 80f, rightX, yY + 80f, 20f, 20f, boxBg)

        val amountTitle = Paint().apply { color = logoGreen; textSize = 40f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); isAntiAlias = true }
        canvas.drawText("Net Settled Amount:", startX + 40f, yY + 15f, amountTitle)

        val amountValue = Paint().apply { color = logoGreen; textSize = 50f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textAlign = Paint.Align.RIGHT; isAntiAlias = true }
        canvas.drawText("LKR ${String.format(Locale.US, "%,.2f", tx.amount)}", rightX - 40f, yY + 20f, amountValue)

        yY += 200f
        canvas.drawText("This is an automatically generated electronic payslip.", startX, yY, textPaint)

        yY = height - 80f
        val footer = Paint().apply { color = android.graphics.Color.GRAY; textSize = 24f; typeface = Typeface.create(Typeface.DEFAULT, Typeface.ITALIC); isAntiAlias = true; textAlign = Paint.Align.CENTER }
        canvas.drawText("Thank you for your excellent service - Golden Hand Caregivers", width / 2f, yY, footer)

        val imagesDir = File(context.cacheDir, "images")
        imagesDir.mkdirs()
        val imageFile = File(imagesDir, "Payslip_${tx.id.take(6)}.png")

        val outputStream = FileOutputStream(imageFile)
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
        outputStream.flush()
        outputStream.close()

        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", imageFile)

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, "Here is my official payslip from Golden Hand Caregivers! \uD83D\uDCB0")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(shareIntent, "Save or Share Payslip"))

    } catch (e: Exception) {
        e.printStackTrace()
        Toast.makeText(context, "Failed to generate payslip", Toast.LENGTH_SHORT).show()
    }
}

fun convertBase64ToBitmap(base64Str: String): Bitmap? {
    return try {
        val pureBase64 = base64Str.substringAfter("base64,")
        val decodedBytes = Base64.decode(pureBase64, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(decodedBytes, 0, decodedBytes.size)
    } catch (e: Exception) {
        e.printStackTrace()
        null
    }
}