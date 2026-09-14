package com.kina.care.presentation.profile

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Settings // 🌟 Language වෙනුවට Settings අයිකනය
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kina.care.presentation.util.LocalIsSinhala

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    onBackClick: () -> Unit,
    viewModel: SettingsViewModel = viewModel()
) {
    val context = LocalContext.current
    val isSinhalaState = LocalIsSinhala.current
    val isSinhala by isSinhalaState
    val viewModelIsSinhala by viewModel.isSinhala.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.loadLanguagePreference(context)
    }

    LaunchedEffect(viewModelIsSinhala) {
        isSinhalaState.value = viewModelIsSinhala
    }

    var showAboutDialog by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isSinhala) "සැකසුම්" else "Settings", color = Color.White, fontWeight = FontWeight.Bold) },
                navigationIcon = {
                    IconButton(onClick = onBackClick) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = Color.White)
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
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            Text(
                text = if (isSinhala) "පොදු සැකසුම්" else "General Settings",
                fontWeight = FontWeight.Bold,
                color = Color(0xFF1E293B),
                modifier = Modifier.padding(bottom = 8.dp, start = 8.dp)
            )

            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Column {
                    SettingsItem(
                        icon = Icons.Default.Settings, // 🌟 මෙහි Language වෙනුවට Settings අයිකනය භාවිතා කර ඇත
                        title = if (isSinhala) "භාෂාව මාරු කරන්න (Language)" else "Change Language (භාෂාව)",
                        subtitle = if (isSinhala) "දැනට තෝරාගෙන ඇත්තේ: සිංහල" else "Currently selected: English",
                        onClick = { viewModel.setLanguage(context, !viewModelIsSinhala) }
                    )
                }
            }

            Spacer(modifier = Modifier.height(24.dp))

            Text(
                text = if (isSinhala) "තොරතුරු සහ නීති" else "Information & Legal",
                fontWeight = FontWeight.Bold,
                color = Color(0xFF1E293B),
                modifier = Modifier.padding(bottom = 8.dp, start = 8.dp)
            )

            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = Color.White),
                elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
            ) {
                Column {
                    SettingsItem(
                        icon = Icons.Default.Info,
                        title = if (isSinhala) "අප ගැන (About Us)" else "About Us",
                        subtitle = if (isSinhala) "Golden Hand Caregivers පිළිබඳව" else "Learn more about Golden Hand Caregivers",
                        onClick = { showAboutDialog = true }
                    )
                    HorizontalDivider(color = Color(0xFFF1F5F9))
                    SettingsItem(
                        icon = Icons.Default.Lock,
                        title = if (isSinhala) "පෞද්ගලිකත්ව ප්‍රතිපත්තිය" else "Privacy Policy",
                        subtitle = if (isSinhala) "අපගේ නීති සහ රෙගුලාසි කියවන්න" else "Read our terms and conditions",
                        onClick = {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.postkina.online/privacy.html"))
                            context.startActivity(intent)
                        }
                    )
                }
            }

            Spacer(modifier = Modifier.weight(1f))

            Text(
                text = "App Version 1.0.0",
                color = Color.Gray,
                fontSize = 12.sp,
                modifier = Modifier.align(Alignment.CenterHorizontally).padding(bottom = 16.dp)
            )
        }

        if (showAboutDialog) {
            AlertDialog(
                onDismissRequest = { showAboutDialog = false },
                title = { Text(if (isSinhala) "අප ගැන" else "About Us", fontWeight = FontWeight.Bold, color = Color(0xFF1A5276)) },
                text = {
                    Text(
                        if (isSinhala) "Golden Hand Caregivers යනු ශ්‍රී ලංකාවේ ප්‍රමුඛතම සහ විශ්වාසවන්තම සාත්තු සේවා ජාලයයි. අපගේ අරමුණ වන්නේ ඔබට අවශ්‍ය සේවාව ඉතාමත් කඩිනමින් සහ ආරක්ෂිතව ලබා දීමයි."
                        else "Golden Hand Caregivers is Sri Lanka's premier and most trusted caregiver network. Our goal is to provide you with the necessary care quickly and safely.",
                        fontSize = 14.sp,
                        color = Color.DarkGray
                    )
                },
                confirmButton = {
                    Button(
                        onClick = { showAboutDialog = false },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A5276))
                    ) {
                        Text(if (isSinhala) "හරි" else "OK")
                    }
                }
            )
        }
    }
}

@Composable
fun SettingsItem(icon: ImageVector, title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(Color(0xFFF1F5F9), shape = RoundedCornerShape(10.dp)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = Color(0xFF1A5276))
        }
        Spacer(modifier = Modifier.width(16.dp))
        Column {
            Text(title, fontWeight = FontWeight.Bold, fontSize = 16.sp, color = Color(0xFF1E293B))
            Text(subtitle, fontSize = 12.sp, color = Color.Gray)
        }
    }
}