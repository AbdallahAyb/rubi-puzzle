// host_game_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_service.dart';
import 'easy_mode.dart';
import 'dart:async';

class HostGamePage extends StatefulWidget {
  @override
  _HostGamePageState createState() => _HostGamePageState();
}

class _HostGamePageState extends State<HostGamePage> {
  final GameService _gameService = GameService();
  bool _isLoading = false;
  String? _gameCode;
  String? _errorMessage;
  String? _gameId;
  StreamSubscription<DocumentSnapshot>? _gameSubscription;

  @override
  void initState() {
    super.initState();
    // Create game immediately when page loads
    _createGame();
  }

  @override
  void dispose() {
    _gameSubscription?.cancel();
    if (_gameId != null && _gameCode == null) {
      // Clean up the game if host leaves before anyone joins
      FirebaseFirestore.instance.collection('games').doc(_gameId).delete();
    }
    super.dispose();
  }

  Future<void> _createGame() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _gameService.createGame();
      if (result['success']) {
        setState(() {
          _gameCode = result['gameCode'];
          _gameId = result['gameId'];
        });

        // Listen for player joining
        _gameSubscription = FirebaseFirestore.instance
            .collection('games')
            .doc(_gameId)
            .snapshots()
            .listen((snapshot) {
          if (!snapshot.exists) return;

          final data = snapshot.data() as Map<String, dynamic>;
          if (data['status'] == 'playing' && data['guestId'].isNotEmpty) {
            _gameSubscription?.cancel();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EasyPuzzle(
                    gameId: _gameId!,
                    isMultiplayer: true,
                    isHost: true,
                    gameCode: _gameCode!,
                  ),
                ),
              );
            }
          }
        });
      } else {
        setState(() {
          _errorMessage = result['error'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create game: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Host Game', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _gameSubscription?.cancel();
            if (_gameId != null) {
              FirebaseFirestore.instance.collection('games').doc(_gameId).delete();
            }
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading && _gameCode == null)
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                if (_gameCode != null) ...[
                  Text(
                    'Game Code:',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      _gameCode!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5,
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Waiting for player to join...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  SizedBox(height: 20),
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                  ),
                ],
                if (_errorMessage != null) ...[
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}