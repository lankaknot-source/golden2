package com.kina.care.presentation.auth
import com.kina.care.presentation.components.BrandLogo

import android.app.Activity
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
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
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import kotlinx.coroutines.launch

val DarkBlue = Color(0xFF0D3B66)
val LogoGreen = Color(0xFF53A548)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(
    authViewModel: AuthViewModel = viewModel(),
    onLoginSuccess: () -> Unit,
    onNavigateToSignUp: () -> Unit,
    onNavigateToRoleSelection: () -> Unit
) {
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    val authState by authViewModel.authState.collectAsState()
    val coroutineScope = rememberCoroutineScope()
    val context = LocalContext.current

    // දෝෂය නිවැරදි කිරීම: කෙලින්ම String එකක් ලෙස ID එක ලබා දීම
    // කරුණාකර "YOUR_WEB_CLIENT_ID_HERE" වෙනුවට Firebase එකෙන් ගන්නා ඔබගේ ID එක මෙතැනට දාන්න
    val webClientId = "283184840115-dh6l2j6f0u3ov03nih26slfi4i832ev6.apps.googleusercontent.com"

    val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
        .requestIdToken(webClientId)
        .requestEmail()
        .build()

    val googleSignInClient = remember { GoogleSignIn.getClient(context, gso) }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
            try {
                val account = task.getResult(ApiException::class.java)
                val idToken = account?.idToken
                if (idToken != null) {
                    coroutineScope.launch {
                        authViewModel.loginWithGoogle(idToken)
                    }
                }
            } catch (e: ApiException) {
                Toast.makeText(context, "Google Login දෝෂයකි: Error Code ${e.statusCode}", Toast.LENGTH_LONG).show()
            }
        } else {
            Toast.makeText(context, "Google Login අවලංගු කරන ලදී", Toast.LENGTH_SHORT).show()
        }
    }

    LaunchedEffect(authState.isSuccess) {
        if (authState.isSuccess) {
            onLoginSuccess()
        }
    }

    LaunchedEffect(authState.needsRoleSelection) {
        if (authState.needsRoleSelection) {
            onNavigateToRoleSelection()
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
        BrandLogo(modifier = Modifier.size(140.dp))
        Text("GOLDEN HAND", fontSize = 32.sp, fontWeight = FontWeight.ExtraBold, color = DarkBlue)
        Text("CAREGIVERS", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = LogoGreen, modifier = Modifier.padding(top = 4.dp))
        Text("Welcome Back!", fontSize = 16.sp, color = Color.Gray, modifier = Modifier.padding(top = 8.dp, bottom = 32.dp))

        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Email") },
            leadingIcon = { Icon(Icons.Default.Email, contentDescription = "Email", tint = DarkBlue) },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = LogoGreen, focusedLabelColor = LogoGreen)
        )
        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Password") },
            leadingIcon = { Icon(Icons.Default.Lock, contentDescription = "Lock", tint = DarkBlue) },
            visualTransformation = PasswordVisualTransformation(),
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp),
            colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = LogoGreen, focusedLabelColor = LogoGreen)
        )
        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "Forgot Password?",
            color = LogoGreen,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.align(Alignment.End).clickable { /* TODO */ }
        )
        Spacer(modifier = Modifier.height(32.dp))

        if (authState.errorMessage != null) {
            Text(text = authState.errorMessage!!, color = Color.Red, fontSize = 14.sp, modifier = Modifier.padding(bottom = 16.dp))
        }

        Button(
            onClick = {
                if (email.isNotEmpty() && password.isNotEmpty()) {
                    coroutineScope.launch { authViewModel.login(email, password) }
                }
            },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = DarkBlue),
            enabled = !authState.isLoading
        ) {
            if (authState.isLoading && !authState.needsRoleSelection) {
                CircularProgressIndicator(color = Color.White, modifier = Modifier.size(24.dp))
            } else {
                Text("Sign In", fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
        Text("OR", color = Color.Gray, fontSize = 14.sp)
        Spacer(modifier = Modifier.height(16.dp))

        OutlinedButton(
            onClick = {
                val signInIntent = googleSignInClient.signInIntent
                launcher.launch(signInIntent)
            },
            modifier = Modifier.fillMaxWidth().height(50.dp),
            shape = RoundedCornerShape(12.dp),
            enabled = !authState.isLoading
        ) {
            if (authState.isLoading && !authState.needsRoleSelection) {
                CircularProgressIndicator(color = DarkBlue, modifier = Modifier.size(24.dp))
            } else {
                Text("Sign in with Google", fontSize = 16.sp, fontWeight = FontWeight.Bold, color = DarkBlue)
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(text = "Don't have an account? ", color = Color.Gray)
            Text(
                text = "Sign Up",
                color = LogoGreen,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.clickable { onNavigateToSignUp() }
            )
        }
    }
}