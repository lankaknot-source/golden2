package com.kina.care.presentation.auth
import com.kina.care.presentation.components.BrandLogo

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

@Composable
fun SplashScreen(
    onNavigateToNext: () -> Unit
) {
    var startAnimation by remember { mutableStateOf(false) }

    val alphaAnim by animateFloatAsState(
        targetValue = if (startAnimation) 1f else 0f,
        animationSpec = tween(durationMillis = 1000), label = "alpha"
    )
    
    val scaleAnim by animateFloatAsState(
        targetValue = if (startAnimation) 1f else 0.3f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ), label = "scale"
    )

    val offsetYAnim by animateFloatAsState(
        targetValue = if (startAnimation) 0f else 50f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        ), label = "offset"
    )

    LaunchedEffect(key1 = true) {
        startAnimation = true
        delay(2500)
        onNavigateToNext()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFFF8FAFC)), // පසුබිම් වර්ණය
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.alpha(alphaAnim)
        ) {
            BrandLogo(modifier = Modifier.size(200.dp).scale(scaleAnim))
            Spacer(modifier = Modifier.height(24.dp))
            Text(
                text = "GOLDEN HAND",
                fontSize = 32.sp,
                fontWeight = FontWeight.ExtraBold,
                color = Color(0xFF0D3B66),
                letterSpacing = 2.sp,
                modifier = Modifier.offset(y = offsetYAnim.dp) // 🌟 Slide up animation
            )
            Text(
                text = "CAREGIVERS",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFF53A548),
                letterSpacing = 6.sp,
                modifier = Modifier.padding(top = 4.dp).offset(y = offsetYAnim.dp)
            )

            Spacer(modifier = Modifier.height(60.dp))

            androidx.compose.material3.CircularProgressIndicator(
                color = Color(0xFF0EA5E9),
                modifier = Modifier.size(40.dp)
            )
        }
    }
}