import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_mode_selection.dart';
import 'AuthPage.dart';
import 'home.dart';

class MainPAge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Settings Icon
          Positioned(
            top: 40, // Adjust this value for desired top spacing
            right: 20, // Adjust this value for desired right spacing
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(30),
              ),
              child: PopupMenuButton(
                icon: Icon(Icons.settings, color: Colors.white, size: 30),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: Colors.white,
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text('Sign Out'),
                      onTap: () async {
                        // Close the popup menu
                        Navigator.pop(context);

                        // Show confirmation dialog
                        bool confirm = await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Sign Out'),
                                content:
                                    Text('Are you sure you want to sign out?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text('Sign Out',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            ) ??
                            false;

                        if (confirm) {
                          try {
                            await FirebaseAuth.instance.signOut();
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => LoginPage()),
                              (Route<dynamic> route) => false,
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Error signing out. Please try again.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Choose Mode',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 30),
                _buildDifficultyButton(
                  context: context,
                  text: 'Offline mode',
                  color: Colors.blue,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => HomePage()),
                  ),
                ),
                SizedBox(height: 15),
                _buildDifficultyButton(
                  context: context,
                  text: ' Online Mode',
                  color: Colors.orange,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => MultiplayerMenu()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyButton({
    required BuildContext context,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 200,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 5,
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
