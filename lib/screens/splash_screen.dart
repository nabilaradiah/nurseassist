import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  void _navigateToLogin() {
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFB3E5FC), // Light blue background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Medical Icon (Heart with Cross)
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Color(0xFF2196F3), // Blue icon background
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.favorite,
                color: Colors.white,
                size: 70,
              ),
            ),
            SizedBox(height: 30),
            // App Name
            Text(
              'NurseAssist',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}