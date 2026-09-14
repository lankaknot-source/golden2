package com.kina.care.presentation.navigation

import androidx.compose.runtime.Composable
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import com.google.firebase.auth.FirebaseAuth
import com.kina.care.presentation.auth.LoginScreen
import com.kina.care.presentation.auth.RoleSelectionScreen
import com.kina.care.presentation.auth.SignUpScreen
import com.kina.care.presentation.auth.SplashScreen // 🌟 අලුත්: Splash Screen
import com.kina.care.presentation.client.CreateJobScreen
import com.kina.care.presentation.client.FindCaregiverScreen
import com.kina.care.presentation.home.HomeScreen
import com.kina.care.presentation.map.MapScreen
import com.kina.care.presentation.profile.CaregiverVerificationScreen
import com.kina.care.presentation.profile.ClientKycScreen
import com.kina.care.presentation.profile.ProfileScreen
import com.kina.care.presentation.caregiver.JobFeedScreen
import com.kina.care.presentation.bookings.BookingsScreen
import com.kina.care.presentation.wallet.WalletScreen
import com.kina.care.presentation.client.ElderProfileScreen
import com.kina.care.presentation.chat.ChatScreen
import com.kina.care.presentation.profile.SettingsScreen
import com.kina.care.presentation.log.CareLogScreen

@Composable
fun AppNavigation(
    // මෙන්න මේක තමයි MainActivity එකෙන් එන notification function එක බාරගන්න හදපු අලුත් parameter එක
    onShowNotification: (String, String) -> Unit = { _, _ -> }
) {
    val navController = rememberNavController()

    // 🌟 අලුත්: ආරම්භක තිරය ලෙස 'splash' තබන්න. පේජ් මාරු වෙද්දි ලස්සනට Animation එකක් වෙන්න මෙතැනට Transitions එකතු කළා.
    NavHost(
        navController = navController,
        startDestination = "splash",
        enterTransition = { slideInHorizontally(initialOffsetX = { 1000 }, animationSpec = tween(400)) + fadeIn(animationSpec = tween(400)) },
        exitTransition = { slideOutHorizontally(targetOffsetX = { -1000 }, animationSpec = tween(400)) + fadeOut(animationSpec = tween(400)) },
        popEnterTransition = { slideInHorizontally(initialOffsetX = { -1000 }, animationSpec = tween(400)) + fadeIn(animationSpec = tween(400)) },
        popExitTransition = { slideOutHorizontally(targetOffsetX = { 1000 }, animationSpec = tween(400)) + fadeOut(animationSpec = tween(400)) }
    ) {

        // 1. Splash තිරය
        composable("splash") {
            SplashScreen(
                onNavigateToNext = {
                    val currentUser = FirebaseAuth.getInstance().currentUser
                    val nextDest = if (currentUser != null) "home" else "login"

                    navController.navigate(nextDest) {
                        popUpTo("splash") { inclusive = true } // Splash Screen එක back stack එකෙන් ඉවත් කිරීම
                    }
                }
            )
        }

        composable("login") {
            LoginScreen(
                onLoginSuccess = { navController.navigate("home") { popUpTo("login") { inclusive = true } } },
                onNavigateToSignUp = { navController.navigate("signup") },
                onNavigateToRoleSelection = { navController.navigate("role_selection") }
            )
        }

        composable("signup") {
            SignUpScreen(
                onSignUpSuccess = { navController.navigate("home") { popUpTo("signup") { inclusive = true } } },
                onNavigateToLogin = { navController.popBackStack() }
            )
        }

        composable("role_selection") {
            RoleSelectionScreen(
                onRoleSelectedSuccess = { navController.navigate("home") { popUpTo("role_selection") { inclusive = true } } }
            )
        }

        composable("home") {
            HomeScreen(
                onLogoutSuccess = { navController.navigate("login") { popUpTo("home") { inclusive = true } } },
                onNavigateToFindCaregiver = { navController.navigate("find_caregiver") },
                onNavigateToProfile = { navController.navigate("profile") },
                onNavigateToMap = { navController.navigate("map") },
                onNavigateToJobFeed = { navController.navigate("job_feed") },
                onNavigateToBookings = { navController.navigate("bookings") },
                onNavigateToWallet = { navController.navigate("wallet") },
                onNavigateToElderProfile = { navController.navigate("elder_profile") },
                onNavigateToVerification = { navController.navigate("verification") },
                onNavigateToClientKyc = { navController.navigate("client_kyc") },
                onNavigateToCreateJobWithCaregiver = { id, name ->
                    navController.navigate("create_job?caregiverId=$id&caregiverName=$name")
                }
            )
        }

        composable("find_caregiver") {
            FindCaregiverScreen(
                onBackClick = { navController.popBackStack() },
                onNavigateToCreateJob = { id, name ->
                    navController.navigate("create_job?caregiverId=$id&caregiverName=$name")
                }
            )
        }

        composable(
            route = "create_job?caregiverId={caregiverId}&caregiverName={caregiverName}",
            arguments = listOf(
                navArgument("caregiverId") { type = NavType.StringType; nullable = true; defaultValue = null },
                navArgument("caregiverName") { type = NavType.StringType; nullable = true; defaultValue = null }
            )
        ) { backStackEntry ->
            val cgId = backStackEntry.arguments?.getString("caregiverId")
            val cgName = backStackEntry.arguments?.getString("caregiverName")
            CreateJobScreen(
                onBackClick = { navController.popBackStack() },
                onJobCreated = { navController.popBackStack() },
                selectedCaregiverId = cgId,
                selectedCaregiverName = cgName
            )
        }

        composable("job_feed") {
            JobFeedScreen(
                onBackClick = { navController.popBackStack() },
                onNavigateToChat = { bookingId -> navController.navigate("chat/$bookingId") }
            )
        }

        composable("profile") {
            ProfileScreen(
                onBackClick = { navController.popBackStack() },
                onNavigateToVerification = { navController.navigate("verification") },
                onNavigateToClientKyc = { navController.navigate("client_kyc") },
                onNavigateToSettings = { navController.navigate("settings") }
            )
        }

        composable("verification") {
            CaregiverVerificationScreen(onBackClick = { navController.popBackStack() })
        }

        composable("client_kyc") {
            ClientKycScreen(onBackClick = { navController.popBackStack() })
        }

        composable("map") {
            MapScreen(onBackClick = { navController.popBackStack() })
        }

        composable("bookings") {
            BookingsScreen(
                onBackClick = { navController.popBackStack() },
                onNavigateToChat = { bookingId -> navController.navigate("chat/$bookingId") },
                onNavigateToLogs = { bId, eId -> navController.navigate("care_log?bookingId=$bId&elderId=$eId") }
            )
        }

        composable("wallet") {
            WalletScreen(onBackClick = { navController.popBackStack() })
        }

        composable("elder_profile") {
            ElderProfileScreen(onBackClick = { navController.popBackStack() })
        }

        composable("chat/{bookingId}") { backStackEntry ->
            val bookingId = backStackEntry.arguments?.getString("bookingId") ?: ""
            ChatScreen(
                bookingId = bookingId,
                onBackClick = { navController.popBackStack() }
            )
        }

        composable("settings") {
            SettingsScreen(onBackClick = { navController.popBackStack() })
        }

        composable(
            route = "care_log?bookingId={bookingId}&elderId={elderId}",
            arguments = listOf(
                navArgument("bookingId") { type = NavType.StringType; nullable = true; defaultValue = null },
                navArgument("elderId") { type = NavType.StringType; nullable = true; defaultValue = null }
            )
        ) { backStackEntry ->
            val bookingId = backStackEntry.arguments?.getString("bookingId") ?: ""
            val elderId = backStackEntry.arguments?.getString("elderId") ?: ""
            CareLogScreen(
                bookingId = bookingId,
                elderId = elderId,
                onBackClick = { navController.popBackStack() }
            )
        }
    }
}