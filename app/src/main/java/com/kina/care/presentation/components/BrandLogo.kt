package com.kina.care.presentation.components
import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.kina.care.R
@Composable
fun BrandLogo(modifier: Modifier = Modifier) {
    Image(painter = painterResource(R.drawable.whatsapp_image_2026_02_22_at_10_56_18), contentDescription = "Golden Hand Caregivers logo", contentScale = ContentScale.Fit, modifier = modifier)
}
