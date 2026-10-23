import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/splash_screen.dart';

/// Run against the local Firebase Emulator Suite instead of the real project:
///   flutter run --dart-define=USE_FIREBASE_EMULATOR=true
/// Off by default, so normal runs and release builds always use real Firebase.
/// See tools/firebase-emulator/README.md.
const bool kUseFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

/// Address of the computer running the emulators. 10.0.2.2 is how the
/// Android emulator reaches the host machine.
const String _emulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

Future<void> _connectToFirebaseEmulators() async {
  await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
  await FirebaseStorage.instance.useStorageEmulator(_emulatorHost, 9199);
  print('🧪 Using local Firebase emulators at $_emulatorHost');
}

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
    if (kUseFirebaseEmulator) await _connectToFirebaseEmulators();
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
      theme: kNurseAssistTheme,
      home: SplashScreen(), // Set SplashScreen as the home
      // A corner banner makes it obvious when the app is on local test data
      builder: kUseFirebaseEmulator
          ? (context, child) => Banner(
                message: 'TEST DATA',
                location: BannerLocation.topEnd,
                color: Colors.deepOrange,
                child: child!,
              )
          : null,
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
