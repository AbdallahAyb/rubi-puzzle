import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'rubi_puzzle_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(apiKey: "AIzaSyD8sqTf5SU5FqylyKZfenYKiUO0Kg_ZWKo",
        appId:"1:701547044655:android:5f958adbb65d79271b0bda",
        messagingSenderId: "701547044655",
        projectId: "rubi-puzzle")
  );
  await Firebase.initializeApp();
  runApp(RubiPuzzle());
}