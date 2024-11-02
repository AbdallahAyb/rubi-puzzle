import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'dart:async';

class GameService {
  static final GameService _instance = GameService._internal();

  factory GameService() {
    return _instance;
  }

  GameService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<int> _generateBalancedTargetColors() {
    final random = Random();
    List<int> targetColors = [];
    Map<int, int> colorCount = {};

    // Initialize color counts
    for (int i = 0; i < 6; i++) {
      colorCount[i] = 0;
    }

    // Fill the 3x3 grid (9 positions)
    while (targetColors.length < 9) {
      int color = random.nextInt(6);

      // Check if this color has been used less than 4 times
      if (colorCount[color]! < 4) {
        targetColors.add(color);
        colorCount[color] = colorCount[color]! + 1;
      }
    }

    return targetColors;
  }

  Map<String, dynamic> generateInitialGameState() {
    final random = Random();

    // For 5x5 grid: Generate exactly 4 tiles of each color
    List<int> tiles = [];
    for (int i = 0; i < 6; i++) {  // 6 colors
      tiles.addAll(List.filled(4, i));  // Add exactly 4 tiles of each color
    }
    tiles.add(-1); // Add the empty tile

    // Shuffle until we get a solvable configuration
    do {
      tiles.shuffle(random);
    } while (!isSolvable(tiles));

    // Generate balanced target colors for 3x3 grid
    List<int> targetColors = _generateBalancedTargetColors();

    return {
      'tiles': tiles,
      'targetColors': targetColors,
      'gridSize': 5
    };
  }

  bool isSolvable(List<int> tiles) {
    int inversions = 0;
    int emptyTileRow = tiles.indexOf(-1) ~/ 5;

    for (int i = 0; i < tiles.length - 1; i++) {
      if (tiles[i] == -1) continue;
      for (int j = i + 1; j < tiles.length; j++) {
        if (tiles[j] != -1 && tiles[i] > tiles[j]) {
          inversions++;
        }
      }
    }

    bool emptyOnEvenRow = ((4 - emptyTileRow) % 2) == 0;
    return emptyOnEvenRow ? (inversions % 2 == 1) : (inversions % 2 == 0);
  }

  Future<Map<String, dynamic>> createGame() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      await cleanupUserGames(user.uid);

      final gameState = generateInitialGameState();
      final gameCode = _generateGameCode();

      DocumentReference gameRef = await _firestore.collection('games').add({
        'hostId': user.uid,
        'hostName': user.displayName ?? 'Player 1',
        'guestId': '',
        'guestName': '',
        'status': 'waiting',
        'created': FieldValue.serverTimestamp(),
        'lastUpdateTime': FieldValue.serverTimestamp(),
        'initialTiles': gameState['tiles'],
        'hostTiles': gameState['tiles'],
        'guestTiles': gameState['tiles'],
        'targetColors': gameState['targetColors'],
        'gridSize': gameState['gridSize'],
        'winner': '',
        'gameCode': gameCode,
        'moves': {
          'host': 0,
          'guest': 0
        },
        'lastMoveBy': '',
        'startTime': null,
        'endTime': null,
        'forfeited': false,
        'forfeitedBy': '',
        'hostReady': true,
        'guestReady': false
      });

      return {
        'success': true,
        'gameId': gameRef.id,
        'gameCode': gameCode,
      };
    } catch (e) {
      print('Error creating game: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> joinGame(String gameCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'error': 'User not authenticated'};
      }

      final gameQuery = await _firestore
          .collection('games')
          .where('gameCode', isEqualTo: gameCode.toUpperCase())
          .where('status', isEqualTo: 'waiting')
          .limit(1)
          .get();

      if (gameQuery.docs.isEmpty) {
        return {'success': false, 'error': 'Game not found or already started'};
      }

      final gameDoc = gameQuery.docs.first;
      final gameData = gameDoc.data();

      if (gameData['hostId'] == user.uid) {
        return {'success': false, 'error': 'Cannot join your own game'};
      }

      if (gameData['guestId'] != null && gameData['guestId'].isNotEmpty) {
        return {'success': false, 'error': 'Game is already full'};
      }

      await gameDoc.reference.update({
        'guestId': user.uid,
        'guestName': user.displayName ?? 'Player 2',
        'status': 'playing',
        'lastUpdateTime': FieldValue.serverTimestamp(),
        'startTime': FieldValue.serverTimestamp(),
        'guestReady': true
      });

      return {
        'success': true,
        'gameId': gameDoc.id,
      };
    } catch (e) {
      print('Error joining game: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Stream<DocumentSnapshot> getGameStream(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots();
  }

  Future<void> updateGameState(String gameId, List<int> tiles, String playerId) async {
    try {
      final gameRef = _firestore.collection('games').doc(gameId);

      final isHost = playerId == _auth.currentUser?.uid;
      final updateField = isHost ? 'hostTiles' : 'guestTiles';

      Map<String, dynamic> updates = {
        updateField: tiles,
        'lastUpdateTime': FieldValue.serverTimestamp(),
        'lastMoveBy': playerId,
        'moves.${isHost ? 'host' : 'guest'}': FieldValue.increment(1),
      };

      await gameRef.update(updates);
    } catch (e) {
      print('Error updating game state: $e');
    }
  }

  Future<void> endGame(String gameId, String winnerId) async {
    try {
      final updates = {
        'status': 'completed',
        'winner': winnerId,
        'endTime': FieldValue.serverTimestamp(),
        'lastUpdateTime': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('games').doc(gameId).update(updates);
    } catch (e) {
      print('Error ending game: $e');
    }
  }

  Future<void> forfeitGame(String gameId, String forfeitingPlayerId) async {
    try {
      final gameDoc = await _firestore.collection('games').doc(gameId).get();

      if (!gameDoc.exists) return;

      final data = gameDoc.data()!;
      if (data['status'] != 'playing') return;

      final winnerId = forfeitingPlayerId == data['hostId']
          ? data['guestId']
          : data['hostId'];

      final updates = {
        'status': 'completed',
        'winner': winnerId,
        'forfeited': true,
        'forfeitedBy': forfeitingPlayerId,
        'endTime': FieldValue.serverTimestamp(),
        'lastUpdateTime': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('games').doc(gameId).update(updates);
    } catch (e) {
      print('Error forfeiting game: $e');
    }
  }

  String _generateGameCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  Future<void> cleanupUserGames(String userId) async {
    try {
      final userGames = await _firestore
          .collection('games')
          .where('hostId', isEqualTo: userId)
          .where('status', isEqualTo: 'waiting')
          .get();

      final batch = _firestore.batch();
      for (var doc in userGames.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error cleaning up user games: $e');
    }
  }
}