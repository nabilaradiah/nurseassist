import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print('⚠️ .env file not found: $e');
  }
  
  // Initialize Firebase with timeout
  try {
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('⚠️ Firebase initialization timeout - continuing without Firebase');
        throw Exception('Firebase initialization timeout');
      },
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization error: $e');
    print('App will run in offline mode. Some features may not work.');
  }
  
  runApp(const NurseAssistApp());
}

class NurseAssistApp extends StatelessWidget {
  const NurseAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nurse Assist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(), // Set SplashScreen as the home
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // For testing UI without Firebase, always show app
    // Firebase initialization errors will show as snackbars during login attempts
    
    final authService = AuthService();
    
    return StreamBuilder(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return const DashboardScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}
