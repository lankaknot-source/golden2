package com.kina.care.presentation.util

import androidx.compose.runtime.MutableState
import androidx.compose.runtime.compositionLocalOf

// මුළු App එක පුරාම භාෂාව බෙදා හැරීමට මෙය භාවිතා කරයි.
// true = සිංහල, false = English
val LocalIsSinhala = compositionLocalOf<MutableState<Boolean>> { error("Language state not provided") }