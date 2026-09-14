package com.kina.care.presentation.profile

import android.content.Context
import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class SettingsViewModel : ViewModel() {
    private val _isSinhala = MutableStateFlow(false)
    val isSinhala: StateFlow<Boolean> = _isSinhala.asStateFlow()

    fun loadLanguagePreference(context: Context) {
        val sharedPrefs = context.getSharedPreferences("KinaCarePrefs", Context.MODE_PRIVATE)
        _isSinhala.value = sharedPrefs.getBoolean("is_sinhala", false)
    }

    fun setLanguage(context: Context, isSinhalaLang: Boolean) {
        val sharedPrefs = context.getSharedPreferences("KinaCarePrefs", Context.MODE_PRIVATE)
        sharedPrefs.edit().putBoolean("is_sinhala", isSinhalaLang).apply()
        _isSinhala.value = isSinhalaLang
    }
}