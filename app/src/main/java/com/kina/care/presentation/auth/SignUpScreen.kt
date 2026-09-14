package com.kina.care.presentation.auth

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.kina.care.presentation.util.LocalIsSinhala
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SignUpScreen(
    authViewModel: AuthViewModel = viewModel(),
    onSignUpSuccess: () -> Unit,
    onNavigateToLogin: () -> Unit
) {
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var selectedRole by remember { mutableStateOf("CLIENT") }
    var termsAgreed by remember { mutableStateOf(false) }

    val authState by authViewModel.authState.collectAsState()
    val coroutineScope = rememberCoroutineScope()
    val isSinhala = LocalIsSinhala.current.value
    val context = LocalContext.current

    LaunchedEffect(authState.isSuccess) {
        if (authState.isSuccess) {
            onSignUpSuccess()
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
        Text(
            text = if(isSinhala) "නව ගිණුමක් සාදන්න" else "Create Account",
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            color = Color(0xFF0EA5E9)
        )
        Text(
            text = if(isSinhala) "අදම Golden Hand Caregivers හා එක්වන්න" else "Join Golden Hand Caregivers today",
            fontSize = 16.sp,
            color = Color.Gray,
            modifier = Modifier.padding(top = 8.dp, bottom = 24.dp)
        )

        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text(if(isSinhala) "සම්පූර්ණ නම" else "Full Name") },
            leadingIcon = { Icon(Icons.Default.Person, contentDescription = "Name") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color(0xFF0EA5E9),
                focusedLabelColor = Color(0xFF0EA5E9)
            )
        )
        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text(if(isSinhala) "ඊමේල් ලිපිනය" else "Email") },
            leadingIcon = { Icon(Icons.Default.Email, contentDescription = "Email") },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color(0xFF0EA5E9),
                focusedLabelColor = Color(0xFF0EA5E9)
            )
        )
        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text(if(isSinhala) "මුරපදය" else "Password") },
            leadingIcon = { Icon(Icons.Default.Lock, contentDescription = "Lock") },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = Color(0xFF0EA5E9),
                focusedLabelColor = Color(0xFF0EA5E9)
            )
        )
        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = if(isSinhala) "ඔබේ භූමිකාව තෝරන්න" else "Select Your Role",
            fontWeight = FontWeight.Bold,
            color = Color.DarkGray,
            modifier = Modifier.align(Alignment.Start)
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = selectedRole == "CLIENT",
                    onClick = { selectedRole = "CLIENT" },
                    colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF0EA5E9))
                )
                Text(if(isSinhala) "සේවාදායකයා" else "Client", fontSize = 13.sp)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = selectedRole == "CAREGIVER",
                    onClick = { selectedRole = "CAREGIVER" },
                    colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF0EA5E9))
                )
                Text(if(isSinhala) "සාත්තු සේවක" else "Caregiver", fontSize = 13.sp)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(
                    selected = selectedRole == "NURSE",
                    onClick = { selectedRole = "NURSE" },
                    colors = RadioButtonDefaults.colors(selectedColor = Color(0xFF0EA5E9))
                )
                Text(if(isSinhala) "හෙද / Nurse" else "Nurse", fontSize = 13.sp)
            }
        }

        Spacer(modifier = Modifier.height(8.dp))

        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            Checkbox(
                checked = termsAgreed,
                onCheckedChange = { termsAgreed = it },
                colors = CheckboxDefaults.colors(checkedColor = Color(0xFF0EA5E9))
            )
            Row(modifier = Modifier.padding(start = 4.dp)) {
                Text(text = if(isSinhala) "මම " else "I agree to the ", color = Color.DarkGray, fontSize = 14.sp)
                Text(
                    text = if(isSinhala) "නීති සහ රෙගුලාසි" else "Terms and Conditions",
                    color = Color(0xFF0EA5E9),
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.clickable {
                        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.postkina.online/terms.html")))
                    }
                )
                Text(text = if(isSinhala) " වලට එකඟ වෙමි." else "", color = Color.DarkGray, fontSize = 14.sp)
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        if (authState.errorMessage != null) {
            Text(text = authState.errorMessage!!, color = Color.Red, fontSize = 14.sp, modifier = Modifier.padding(bottom = 16.dp))
        }

        Button(
            onClick = {
                if (email.isNotEmpty() && password.isNotEmpty() && name.isNotEmpty() && termsAgreed) {
                    coroutineScope.launch { authViewModel.signUp(email, password, name, selectedRole) }
                }
            },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = Color(0xFF0EA5E9),
                disabledContainerColor = Color(0xFF0EA5E9).copy(alpha = 0.5f)
            ),
            enabled = !authState.isLoading && termsAgreed
        ) {
            if (authState.isLoading) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
            } else {
                Text(if(isSinhala) "ලියාපදිංචි වන්න" else "Sign Up", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(text = if(isSinhala) "දැනටමත් ගිණුමක් තිබේද? " else "Already have an account? ", color = Color.Gray)
            Text(
                text = if(isSinhala) "ලොග් වන්න" else "Sign In",
                color = Color(0xFF0EA5E9),
                fontWeight = FontWeight.Bold,
                modifier = Modifier.clickable { onNavigateToLogin() }
            )
        }
    }
}