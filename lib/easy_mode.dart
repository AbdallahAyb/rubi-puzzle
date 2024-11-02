import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'game_service.dart';

class EasyPuzzle extends StatefulWidget {
  final String? gameId;
  final bool isMultiplayer;
  final bool isHost;
  final String? gameCode;

  EasyPuzzle({
    this.gameId,
    this.isMultiplayer = false,
    this.isHost = false,
    this.gameCode,
  });

  @override
  _EasyPuzzleState createState() => _EasyPuzzleState();
}

class _EasyPuzzleState extends State<EasyPuzzle> {
  final GameService _gameService = GameService();
  final int gridSize = 5;
  List<int> tiles = [];
  late int emptyIndex;
  List<int> lastTiles = [];
  DateTime lastMoveTime = DateTime.now();
  bool isLocalMove = false;

  List<Color> colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
    Colors.orange,
  ];

  List<Color> targetColors = List.filled(9, Colors.white);
  int elapsedTime = 0;
  late Timer timer;
  bool isGameOver = false;
  bool hasWon = false;
  String? winnerId;
  Stream<DocumentSnapshot>? _gameStream;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  final AudioPlayer _audioPlayerSlide = AudioPlayer();
  final AudioPlayer _audioPlayerWin = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSounds();
    if (widget.isMultiplayer) {
      _initializeMultiplayerGame();
    } else {
      _initializeSinglePlayerGame();
    }
  }

  Future<void> _loadSounds() async {
    try {
      await _audioPlayerSlide.setAsset('assets/slide.mp3');
      await _audioPlayerWin.setAsset('assets/win.mp3');
    } catch (e) {
      print('Error loading sounds: $e');
    }
  }

  void _playSound(String sound) async {
    try {
      if (sound == 'slide') {
        await _audioPlayerSlide.seek(Duration.zero);
        await _audioPlayerSlide.play();
      } else if (sound == 'win') {
        await _audioPlayerWin.seek(Duration.zero);
        await _audioPlayerWin.play();
      }
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  void _initializeMultiplayerGame() {
    if (widget.gameId == null) return;

    _gameStream = _gameService.getGameStream(widget.gameId!);
    _gameStream?.listen((snapshot) {
      if (!mounted || !snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;

      if (!isLocalMove) {
        setState(() {
          final newTiles = List<int>.from(widget.isHost ? data['hostTiles'] : data['guestTiles']);

          if (!listEquals(tiles, newTiles)) {
            tiles = newTiles;
            emptyIndex = tiles.indexOf(-1);
            lastTiles = List<int>.from(tiles);
          }

          List<int> targetColorIndices = List<int>.from(data['targetColors']);
          targetColors = targetColorIndices.map((i) => colors[i % colors.length]).toList();

          if (data['status'] == 'completed' && !isGameOver) {
            isGameOver = true;
            winnerId = data['winner'];
            hasWon = winnerId == currentUserId;
            _endGame(hasWon);
          }

          if (data['forfeited'] == true && !isGameOver) {
            isGameOver = true;
            hasWon = data['winner'] == currentUserId;
            _endGame(hasWon, wasForfeited: true, forfeitedBy: data['forfeitedBy']);
          }
        });
      }
      isLocalMove = false;
    }, onError: (error) {
      print('Error in game stream: $error');
    });

    _startTimer();
  }

  void _initializeSinglePlayerGame() {
    final gameState = _gameService.generateInitialGameState();
    setState(() {
      tiles = List<int>.from(gameState['tiles']);
      lastTiles = List<int>.from(tiles);
      emptyIndex = tiles.indexOf(-1);
      List<int> colorIndices = List<int>.from(gameState['targetColors']);
      targetColors = colorIndices.map((i) => colors[i % colors.length]).toList();
    });
    _startTimer();
  }

  void _startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted && !isGameOver) {
        setState(() {
          elapsedTime++;
        });
      }
    });
  }

  List<int> _getMovableTiles(int tappedIndex) {
    List<int> movableTiles = [];
    int tappedRow = tappedIndex ~/ gridSize;
    int tappedCol = tappedIndex % gridSize;
    int emptyRow = emptyIndex ~/ gridSize;
    int emptyCol = emptyIndex % gridSize;

    if (tappedRow == emptyRow) {
      int start = min(tappedCol, emptyCol);
      int end = max(tappedCol, emptyCol);
      for (int col = start; col <= end; col++) {
        movableTiles.add(tappedRow * gridSize + col);
      }
    } else if (tappedCol == emptyCol) {
      int start = min(tappedRow, emptyRow);
      int end = max(tappedRow, emptyRow);
      for (int row = start; row <= end; row++) {
        movableTiles.add(row * gridSize + tappedCol);
      }
    }

    return movableTiles;
  }

  Future<void> _moveTiles(List<int> indicesToMove) async {
    if (isGameOver || hasWon) return;

    final now = DateTime.now();
    if (now.difference(lastMoveTime).inMilliseconds < 100) return;
    lastMoveTime = now;

    if (indicesToMove.contains(emptyIndex)) {
      try {
        int targetIndex = indicesToMove.first == emptyIndex ? indicesToMove.last : indicesToMove.first;
        int direction = targetIndex > emptyIndex ? 1 : -1;

        // Create a copy of current tiles
        List<int> newTiles = List<int>.from(tiles);
        List<int> previousTiles = List<int>.from(tiles);

        // Sort tiles to move based on direction
        List<int> tilesToMove = List.from(indicesToMove);
        if (direction > 0) {
          // Moving right/down
          tilesToMove.sort((a, b) => a.compareTo(b));
        } else {
          // Moving left/up
          tilesToMove.sort((a, b) => b.compareTo(a));
        }

        // Move tiles one by one
        for (int i = 0; i < tilesToMove.length - 1; i++) {
          int currentIndex = tilesToMove[i];
          int nextIndex = tilesToMove[i + 1];

          // Swap tiles
          int temp = newTiles[currentIndex];
          newTiles[currentIndex] = newTiles[nextIndex];
          newTiles[nextIndex] = temp;
        }

        setState(() {
          tiles = newTiles;
          emptyIndex = targetIndex;
          _playSound('slide');
        });

        if (widget.isMultiplayer && widget.gameId != null) {
          try {
            isLocalMove = true;
            lastTiles = List<int>.from(tiles);

            await _gameService.updateGameState(
              widget.gameId!,
              tiles,
              currentUserId!,
            );

            if (_checkWinCondition()) {
              await _gameService.endGame(widget.gameId!, currentUserId!);
              _endGame(true);
            }
          } catch (e) {
            print('Error updating game state: $e');
            setState(() {
              tiles = previousTiles;
              emptyIndex = previousTiles.indexOf(-1);
            });
            isLocalMove = false;
          }
        } else {
          if (_checkWinCondition()) {
            _endGame(true);
          }
        }
      } catch (e) {
        print('Error moving tiles: $e');
      }
    }
  }

  bool _checkWinCondition() {
    List<Color> centerColors = [];
    for (int row = 1; row <= 3; row++) {
      for (int col = 1; col <= 3; col++) {
        int index = row * gridSize + col;
        centerColors.add(
          tiles[index] == -1 ? Colors.black : colors[tiles[index] % colors.length],
        );
      }
    }
    return listEquals(centerColors, targetColors);
  }

  void _endGame(bool isWin, {bool wasForfeited = false, String? forfeitedBy}) {
    if (!mounted) return;

    setState(() {
      isGameOver = true;
      hasWon = isWin;
    });

    timer.cancel();

    if (isWin && !wasForfeited) {
      _playSound('win');
    }

    _showGameOverDialog(isWin, wasForfeited: wasForfeited, forfeitedBy: forfeitedBy);
  }

  void _showGameOverDialog(bool isWin, {bool wasForfeited = false, String? forfeitedBy}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String message;
        if (widget.isMultiplayer) {
          if (wasForfeited) {
            message = forfeitedBy == currentUserId
                ? 'You forfeited the game.'
                : 'Your opponent forfeited. You win!';
          } else {
            message = isWin
                ? 'Congratulations! You won in ${formatTime(elapsedTime)}!'
                : 'Game Over! Your opponent won. Better luck next time!';
          }
        } else {
          message = 'You solved the puzzle in ${formatTime(elapsedTime)}!';
        }

        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.red, width: 2),
          ),
          title: Text(
            isWin ? 'Congratulations!' : 'Game Over',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              child: Text('Back to Menu', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        );
      },
    );
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    timer.cancel();
    _audioPlayerSlide.dispose();
    _audioPlayerWin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double tileSize = min(
      (screenWidth - (gridSize + 1) * 4) / gridSize,
      (screenHeight - 200) / gridSize,
    );

    return WillPopScope(
      onWillPop: () async {
        if (widget.isMultiplayer && !isGameOver) {
          bool shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text('Leave Game?', style: TextStyle(color: Colors.white)),
              content: Text(
                'Are you sure you want to forfeit the game?',
                style: TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  child: Text('No', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Yes', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ) ?? false;

          if (shouldExit && !isGameOver) {
            try {
              await _gameService.forfeitGame(widget.gameId!, currentUserId!);
            } catch (e) {
              print('Error forfeiting game: $e');
            }
          }
          return shouldExit;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: widget.isMultiplayer
              ? Text('Online Game - ${widget.gameCode}', style: TextStyle(color: Colors.white))
              : Text('Rubi Puzzle', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Text(
                        formatTime(elapsedTime),
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.black45,
                      ),
                      padding: EdgeInsets.all(4),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                          ),
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            return Container(
                              decoration: BoxDecoration(
                                color: targetColors[index],
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Container(
                    width: tileSize * gridSize + (gridSize + 1) * 4,
                    height: tileSize * gridSize + (gridSize + 1) * 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
                      color: Colors.black45,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GridView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridSize,
                          childAspectRatio: 1,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: tiles.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: isGameOver
                                ? null
                                : () {
                              List<int> movableTiles = _getMovableTiles(index);
                              if (movableTiles.isNotEmpty) {
                                _moveTiles(movableTiles);
                              }
                            },
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              decoration: BoxDecoration(
                                color: tiles[index] == -1
                                    ? Colors.black.withOpacity(0.3)
                                    : colors[tiles[index] % colors.length],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                                boxShadow: [
                                  if (tiles[index] != -1)
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.isMultiplayer)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                    child: Text(
                      widget.isHost ? 'You are Host' : 'You are Guest',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}