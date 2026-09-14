package com.kina.care.presentation.auth

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel

@Composable
fun RoleSelectionScreen(
    authViewModel: AuthViewModel = viewModel(),
    onRoleSelectedSuccess: () -> Unit
) {
    val authState by authViewModel.authState.collectAsState()

    LaunchedEffect(authState.isSuccess) {
        if (authState.isSuccess) {
            onRoleSelectedSuccess()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFF8FAFC))
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text("ගිණුම සම්පූර්ණ කිරීම", fontSize = 24.sp, fontWeight = FontWeight.Bold, color = Color(0xFF0D3B66))
        Text(
            "ඔබ Golden Hand Caregivers හා සම්බන්ධ වන්නේ කුමන ආකාරයෙන්දැයි කරුණාකර තෝරන්න.",
            fontSize = 16.sp,
            color = Color.Gray,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp, bottom = 32.dp)
        )

        if (authState.errorMessage != null) {
            Text(text = authState.errorMessage!!, color = Color.Red, fontSize = 14.sp, modifier = Modifier.padding(bottom = 16.dp))
        }

        if (authState.isLoading) {
            CircularProgressIndicator(color = Color(0xFF53A548))
        } else {
            Button(
                onClick = { authViewModel.saveGoogleUserRole("CLIENT") },
                modifier = Modifier.fillMaxWidth().height(60.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF0D3B66))
            ) {
                Text("මම සේවාදායකයෙක් (Client)", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }

            Spacer(modifier = Modifier.height(16.dp))
            Text("OR", color = Color.Gray, fontSize = 14.sp)
            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = { authViewModel.saveGoogleUserRole("CAREGIVER") },
                modifier = Modifier.fillMaxWidth().height(60.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF53A548))
            ) {
                Text("මම සාත්තු සේවකයෙක් (Caregiver)", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }

            Spacer(modifier = Modifier.height(16.dp))
            Text("OR", color = Color.Gray, fontSize = 14.sp)
            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = { authViewModel.saveGoogleUserRole("NURSE") },
                modifier = Modifier.fillMaxWidth().height(60.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF8B5CF6))
            ) {
                Text("මම හෙදියක් (Nurse)", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}