import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'AuthPage.dart';
import'mainhome.dart';

// Initialize Firebase with offline persistence
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      // Add your Firebase config here
      apiKey: "your-api-key",
      authDomain: "your-auth-domain",
      projectId: "your-project-id",
      storageBucket: "your-storage-bucket",
      messagingSenderId: "your-messaging-sender-id",
      appId: "your-app-id",
    ),
  );

  // Enable offline persistence for Firebase Auth
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
}

class RubiPuzzle extends StatelessWidget {
  const RubiPuzzle({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rubi Puzzle',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder(
        future: initializeFirebase(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasData) {
                return  MainPAge();
              }

              return  LoginPage();
            },
          );
        },
      ),
    );
  }
}

// Authentication service to handle offline/online state
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferences _prefs;

  AuthService(this._prefs);

  // Sign in method with offline support
  Future<bool> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Store user credentials securely for offline access
        await _prefs.setString('user_email', email);
        await _prefs.setBool('is_logged_in', true);
        return true;
      }
      return false;
    } catch (e) {
      // Handle offline login if credentials are stored
      final storedEmail = _prefs.getString('user_email');
      final isLoggedIn = _prefs.getBool('is_logged_in') ?? false;

      if (isLoggedIn && email == storedEmail) {
        return true;
      }
      return false;
    }
  }

  // Sign out method
  Future<void> signOut() async {
    await _auth.signOut();
    await _prefs.clear();
  }

  // Check if user is logged in (online or offline)
  Future<bool> isLoggedIn() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return true;

    return _prefs.getBool('is_logged_in') ?? false;
  }
}