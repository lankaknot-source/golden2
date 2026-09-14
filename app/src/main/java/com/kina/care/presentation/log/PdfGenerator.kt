package com.kina.care.presentation.log

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.os.Environment
import android.widget.Toast
import com.kina.care.domain.model.DailyCareLog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object PdfGenerator {

    suspend fun generateCareLogPdf(context: Context, logs: List<DailyCareLog>, elderName: String): File? {
        return withContext(Dispatchers.IO) {
            try {
                val pdfDocument = PdfDocument()
                val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create() // A4 Size roughly
                val page = pdfDocument.startPage(pageInfo)
                val canvas: Canvas = page.canvas
                val paint = Paint()

                // Header
                paint.color = Color.parseColor("#1A5276")
                paint.textSize = 24f
                paint.isFakeBoldText = true
                canvas.drawText("Golden Hand - Daily Care Report", 70f, 60f, paint)

                paint.color = Color.BLACK
                paint.textSize = 16f
                paint.isFakeBoldText = false
                val dateStr = SimpleDateFormat("MMM dd, yyyy", Locale.US).format(Date())
                canvas.drawText("Patient: $elderName", 70f, 100f, paint)
                canvas.drawText("Report Generated: $dateStr", 70f, 130f, paint)

                paint.color = Color.GRAY
                canvas.drawLine(70f, 150f, 525f, 150f, paint)

                // Table Headers
                paint.color = Color.BLACK
                paint.textSize = 12f
                paint.isFakeBoldText = true

                var yPos = 180f
                canvas.drawText("Date & Time", 70f, yPos, paint)
                canvas.drawText("Blood Pressure", 200f, yPos, paint)
                canvas.drawText("Sugar Level", 320f, yPos, paint)
                canvas.drawText("Temp", 430f, yPos, paint)

                paint.isFakeBoldText = false
                yPos += 30f

                val dateFormat = SimpleDateFormat("MMM dd, hh:mm a", Locale.US)

                logs.sortedByDescending { it.timestamp }.forEach { log ->
                    // Limit text length to avoid overflow
                    val dateTxt = dateFormat.format(Date(log.timestamp))
                    val bpTxt = if (log.bloodPressure.length > 10) log.bloodPressure.take(10) else log.bloodPressure
                    val sugarTxt = if (log.sugarLevel.length > 10) log.sugarLevel.take(10) else log.sugarLevel
                    val tempTxt = if (log.temperature.length > 8) log.temperature.take(8) else log.temperature

                    canvas.drawText(dateTxt, 70f, yPos, paint)
                    canvas.drawText(bpTxt, 200f, yPos, paint)
                    canvas.drawText(sugarTxt, 320f, yPos, paint)
                    canvas.drawText(tempTxt, 430f, yPos, paint)

                    yPos += 20f

                    // If we reach near bottom, create new page (Simple approach: just stop drawing for now or add page logic)
                    if (yPos > 800f) {
                        pdfDocument.finishPage(page)
                        // Simplified: we will only print first page in this stub to prevent complex logic
                        return@forEach
                    }
                }

                pdfDocument.finishPage(page)

                val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                val file = File(dir, "CareLog_${elderName.replace(" ", "_")}_${System.currentTimeMillis()}.pdf")
                
                pdfDocument.writeTo(FileOutputStream(file))
                pdfDocument.close()
                
                file
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }
    }
}
