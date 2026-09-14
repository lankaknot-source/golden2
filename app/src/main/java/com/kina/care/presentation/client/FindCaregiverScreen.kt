package com.kina.care.presentation.client

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kina.care.domain.model.User
import com.kina.care.presentation.util.LocalIsSinhala
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FindCaregiverScreen(
    onBackClick: () -> Unit,
    onNavigateToCreateJob: (String, String) -> Unit,
    viewModel: FindCaregiverViewModel = viewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val selectedCategory by viewModel.selectedCategory.collectAsState()
    val reviews by viewModel.reviewsState.collectAsState()
    val isReviewsLoading by viewModel.isReviewsLoading.collectAsState()
    val favoriteIds by viewModel.favoriteCaregiverIds.collectAsState()
    val isSinhala = LocalIsSinhala.current.value

    var selectedUserForDetails by remember { mutableStateOf<User?>(null) }

    // 🌟 Fix: අලුත් ෆිල්ටර්ස් එකතු කිරීම
    val categories = listOf("All", "Caregiver", "Nurse")

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isSinhala) "සේවකයන් සොයන්න" else "Find Caregivers", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = { IconButton(onClick = onBackClick) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White) } },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color(0xFF1A5276))
            )
        }
    ) { paddingValues ->
        Column(modifier = Modifier.fillMaxSize().background(Color(0xFFF4F8FB)).padding(paddingValues)) {

            OutlinedTextField(
                value = searchQuery, onValueChange = { viewModel.updateSearchQuery(it) },
                modifier = Modifier.fillMaxWidth().padding(16.dp), placeholder = { Text(if (isSinhala) "නම හෝ නගරය..." else "Search by name or city...") },
                leadingIcon = { Icon(Icons.Default.Search, contentDescription = "Search") },
                shape = RoundedCornerShape(24.dp), colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Color(0xFF1A5276),
                    unfocusedBorderColor = Color.LightGray,
                    focusedContainerColor = Color.White,
                    unfocusedContainerColor = Color.White
                )
            )

            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(bottom = 8.dp)
            ) {
                items(categories) { cat ->
                    val isSelected = selectedCategory == cat
                    FilterChip(
                        selected = isSelected,
                        onClick = { viewModel.updateCategory(cat) },
                        label = {
                            // 🌟 Fix: සිංහලෙන් පෙන්වීම සකස් කිරීම
                            val displayTxt = when (cat) {
                                "All" -> if (isSinhala) "සියල්ල" else "All"
                                "Caregiver" -> if (isSinhala) "සාත්තු සේවකයින්" else "Caregivers"
                                "Nurse" -> if (isSinhala) "හෙදියන්" else "Nurses"
                                else -> cat
                            }
                            Text(displayTxt, fontWeight = if(isSelected) FontWeight.Bold else FontWeight.Normal)
                        },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = Color(0xFF1A5276),
                            selectedLabelColor = Color.White
                        )
                    )
                }
            }

            Box(modifier = Modifier.fillMaxSize()) {
                when {
                    uiState.isLoading -> CircularProgressIndicator(modifier = Modifier.align(Alignment.Center), color = Color(0xFF1A5276))
                    uiState.caregivers.isEmpty() -> Text(if (isSinhala) "දැනට සේවකයින් නොමැත" else "No caregivers available", color = Color.Gray, modifier = Modifier.align(Alignment.Center))
                    else -> {
                        LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            items(uiState.caregivers) { user ->
                                val isFav = favoriteIds.contains(user.id)
                                CaregiverRealCard(
                                    user = user, 
                                    isSinhala = isSinhala,
                                    isFavorite = isFav,
                                    onFavoriteToggle = { viewModel.toggleFavorite(user.id) },
                                    onClick = {
                                        selectedUserForDetails = user
                                        viewModel.fetchReviewsForCaregiver(user.id)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }

        if (selectedUserForDetails != null) {
            val user = selectedUserForDetails!!
            ModalBottomSheet(onDismissRequest = { selectedUserForDetails = null; viewModel.clearReviews() }, containerColor = Color.White) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 32.dp).verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (user.profileImageUrl.isNotEmpty()) {
                        val bitmap = convertBase64ToBitmap(user.profileImageUrl)
                        if (bitmap != null) Image(bitmap = bitmap.asImageBitmap(), contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(100.dp).clip(CircleShape))
                        else Box(modifier = Modifier.size(100.dp).clip(CircleShape).background(Color(0xFFE2E8F0)), contentAlignment = Alignment.Center) { Text(if(user.name.isNotEmpty()) user.name.first().toString().uppercase() else "?", fontSize = 40.sp, fontWeight = FontWeight.Bold, color = Color.Gray) }
                    } else {
                        Box(modifier = Modifier.size(100.dp).clip(CircleShape).background(Color(0xFFE2E8F0)), contentAlignment = Alignment.Center) { Text(if(user.name.isNotEmpty()) user.name.first().toString().uppercase() else "?", fontSize = 40.sp, fontWeight = FontWeight.Bold, color = Color.Gray) }
                    }

                    Spacer(modifier = Modifier.height(16.dp))
                    Text(user.name, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))

                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top=8.dp, bottom=16.dp)) {
                        Icon(Icons.Default.Star, contentDescription = null, tint = Color(0xFFF59E0B), modifier = Modifier.size(24.dp))
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("${String.format(Locale.US, "%.1f", user.rating)} / 5.0 (${user.reviewCount} Reviews)", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.Gray)
                    }

                    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Color(0xFFF8FAFC)), elevation = CardDefaults.cardElevation(0.dp)) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text(if (isSinhala) "සාත්තු සේවක තොරතුරු (Verified KYC)" else "Caregiver Information (Verified KYC)", fontWeight = FontWeight.ExtraBold, color = Color(0xFF0D3B66), fontSize = 16.sp, modifier = Modifier.padding(bottom = 12.dp))

                            val kycData = listOf(
                                (if(isSinhala) "වයස හා ස්ත්‍රී/පුරුෂ:" else "Age & Gender:") to "${user.dob} | ${user.gender}",
                                (if(isSinhala) "පළපුරුද්ද (අවුරුදු):" else "Experience (Years):") to (user.experienceYears.ifEmpty { "N/A" }),
                                (if(isSinhala) "කැමති සේවා වර්ග:" else "Preferred Service Types:") to (if (user.preferredServiceTypes.isNotEmpty()) user.preferredServiceTypes.joinToString(", ") else "Any"),
                                (if(isSinhala) "කැමති සේවා කාණ්ඩ:" else "Preferred Categories:") to (if (user.categories.isNotEmpty()) user.categories.joinToString(", ") else "Any"),
                                (if(isSinhala) "එන්නත් විස්තර:" else "Vaccination Status:") to (user.vaccinationStatus.ifEmpty { "N/A" }),
                                (if(isSinhala) "නිදන්ගත රෝග:" else "Chronic Illnesses:") to (user.chronicIllnesses.ifEmpty { "None" }),
                                (if(isSinhala) "විශේෂ හැකියාවන්:" else "Special Skills:") to (user.specialSkills.ifEmpty { "None" })
                            )

                            kycData.forEach { (label, value) ->
                                Row(modifier = Modifier.fillMaxWidth().padding(bottom = 6.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text(label, color = Color.Gray, fontSize = 13.sp, modifier = Modifier.weight(1f))
                                    Text(value, color = Color(0xFF1E293B), fontSize = 13.sp, fontWeight = FontWeight.Medium, textAlign = TextAlign.End, modifier = Modifier.weight(1.5f))
                                }
                            }

                            Spacer(modifier = Modifier.height(8.dp))
                            HorizontalDivider(color = Color(0xFFE2E8F0))
                            Spacer(modifier = Modifier.height(8.dp))

                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF10B981), modifier = Modifier.size(16.dp))
                                Text(" ජාතික හැඳුනුම්පත (NIC) Verified", fontSize = 12.sp, color = Color(0xFF10B981), modifier = Modifier.padding(start=4.dp))
                            }
                            if (user.policeClearanceUrl.isNotEmpty()) {
                                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top=4.dp)) {
                                    Icon(Icons.Default.CheckCircle, contentDescription = null, tint = Color(0xFF10B981), modifier = Modifier.size(16.dp))
                                    Text(" පොලිස් වාර්තාව Verified", fontSize = 12.sp, color = Color(0xFF10B981), modifier = Modifier.padding(start=4.dp))
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
                                            Row { for(i in 1..5) Icon(Icons.Default.Star, contentDescription = null, tint = if(i <= review.rating) Color(0xFFF59E0B) else Color(0xFFE2E8F0), modifier = Modifier.size(14.dp)) }
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
                        onClick = { selectedUserForDetails = null; viewModel.clearReviews(); onNavigateToCreateJob(user.id, user.name) },
                        modifier = Modifier.fillMaxWidth().height(55.dp), shape = RoundedCornerShape(12.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF10B981))
                    ) { Text(if (isSinhala) "මෙම සේවකයා තෝරාගන්න (Book)" else "Book this Caregiver", fontSize = 16.sp, fontWeight = FontWeight.Bold) }
                }
            }
        }
    }
}

@Composable
fun CaregiverRealCard(user: User, isSinhala: Boolean, isFavorite: Boolean, onFavoriteToggle: () -> Unit, onClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth().clickable { onClick() }, shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(containerColor = Color.White), elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)) {
        Row(modifier = Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            if (user.profileImageUrl.isNotEmpty()) {
                val bitmap = convertBase64ToBitmap(user.profileImageUrl)
                if (bitmap != null) Image(bitmap = bitmap.asImageBitmap(), contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.size(60.dp).clip(CircleShape))
                else Box(modifier = Modifier.size(60.dp).clip(CircleShape).background(Color(0xFFE2E8F0)), contentAlignment = Alignment.Center) { Text(text = if(user.name.isNotEmpty()) user.name.first().toString().uppercase() else "?", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color.Gray) }
            } else {
                Box(modifier = Modifier.size(60.dp).clip(CircleShape).background(Color(0xFFE2E8F0)), contentAlignment = Alignment.Center) { Text(text = if(user.name.isNotEmpty()) user.name.first().toString().uppercase() else "?", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color.Gray) }
            }

            Spacer(modifier = Modifier.width(16.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(text = user.name, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color(0xFF1E293B))
                    if (user.rating >= 4.5 && user.reviewCount >= 5) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Box(modifier = Modifier.clip(RoundedCornerShape(4.dp)).background(Color(0xFFFEF08A)).padding(horizontal=4.dp, vertical=2.dp)) {
                            Text("Top Rated", fontSize=10.sp, color=Color(0xFF92400E), fontWeight=FontWeight.Bold)
                        }
                    }
                }
                Text(user.address.ifEmpty { "Location not provided" }, fontSize = 12.sp, color = Color.Gray)
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                    Icon(Icons.Default.Star, contentDescription = "Rating", tint = Color(0xFFF59E0B), modifier = Modifier.size(16.dp))
                    Text(text = " ${String.format(Locale.US, "%.1f", user.rating)} (${user.reviewCount})", fontSize = 12.sp, color = Color.Gray)
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                IconButton(onClick = onFavoriteToggle, modifier = Modifier.size(24.dp).padding(bottom = 4.dp)) {
                    Icon(
                        imageVector = if (isFavorite) Icons.Default.Favorite else Icons.Outlined.FavoriteBorder,
                        contentDescription = "Favorite",
                        tint = if (isFavorite) Color.Red else Color.Gray
                    )
                }
                Text(text = "Rs.${user.hourlyRate}/hr", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color(0xFF10B981))
                Spacer(modifier = Modifier.height(4.dp))
                OutlinedButton(onClick = onClick, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)) { Text(if (isSinhala) "විස්තර බලන්න" else "View Profile", fontSize = 12.sp) }
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