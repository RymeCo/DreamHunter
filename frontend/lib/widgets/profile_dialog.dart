import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dreamhunter/widgets/liquid_glass_dialog.dart';

class ProfileDialog extends StatelessWidget {
  final VoidCallback onLogoutRequested;

  const ProfileDialog({super.key, required this.onLogoutRequested});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.displayName ?? 'No Name';
    final String email = user?.email ?? 'No Email';

    return LiquidGlassDialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(displayName)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData) {
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final playerNumber = data?['playerNumber'];
                    if (playerNumber != null) {
                      return Text(
                        'Player #$playerNumber',
                        style: const TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.6),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                  }
                  return const SizedBox(height: 14);
                },
              ),
              const SizedBox(height: 10),
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color.fromRGBO(255, 255, 255, 0.3),
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(
                        Icons.person,
                        size: 50,
                        color: Color.fromRGBO(255, 255, 255, 0.7),
                      )
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                displayName,
                style: const TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                email,
                style: const TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.7),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  onLogoutRequested();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(255, 255, 255, 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  fixedSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(
                      color: Color.fromRGBO(255, 255, 255, 0.3),
                    ),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
