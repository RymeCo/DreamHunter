import 'package:dreamhunter/domain/game/playground_service.dart';
import 'package:dreamhunter/presentation/loading_screen.dart';
import 'package:dreamhunter/presentation/widget/liquid_glass_dialog.dart';
import 'package:flutter/material.dart';

class PlayDialog extends StatefulWidget {
  const PlayDialog({super.key});

  @override
  State<PlayDialog> createState() => _PlayDialogState();
}

class _PlayDialogState extends State<PlayDialog> {
  final PlaygroundService _service = PlaygroundService();
  final List<String> characters = ['char1', 'mask_dude', 'pink_man', 'virtual_guy'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "ANTE ${_service.anteLevel}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "SELECT YOUR HUNTER",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final char = characters[index];
              final isSelected = _service.selectedCharacter == char;
              return GestureDetector(
                onTap: () => setState(() => _service.selectedCharacter = char),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.purpleAccent : Colors.white24,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected ? Colors.purple.withOpacity(0.3) : Colors.transparent,
                  ),
                  child: Image.asset(
                    'assets/sprites/character/char1.png', // Placeholder for other character images
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoadingScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purpleAccent,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
            "PLAY NOW",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
