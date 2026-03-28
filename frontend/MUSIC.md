# 🎵 DreamHunter Music & Sound Design Guide

This guide outlines the workflow for creating "Creepy & Catchy" (Liquid Horror) audio that stays in the player's mind while remaining 100% free and copyright-safe.

---

## 🛠️ Recommended Free Tools

| Tool | Purpose | Best For |
| :--- | :--- | :--- |
| **[Suno AI](https://suno.com/)** | Music Generation | **Catchy Earworms.** Best for melodic, rhythmic background tracks. |
| **[Udio](https://www.udio.com/)** | Music Generation | **Atmospheric Horror.** Best for high-fidelity, cinematic soundscapes. |
| **[MusicGen](https://huggingface.co/spaces/facebook/MusicGen)** | Music Generation | **Experimental & Open-Source.** Safest for pure "No Copyright" use. |
| **[ElevenLabs](https://elevenlabs.io/)** | SFX Generation | **Whispers & Creepy Effects.** Use their "Sound Effects" generator. |
| **[Audacity](https://www.audacityteam.org/)** | Audio Editing | **The "Remix" Phase.** Use this to distort and loop your AI sounds. |

---

## 🧠 The "Creepy & Catchy" Strategy

A sound stays in the mind through **Repetition** and **Dissonance** (sounds that feel slightly "wrong").

### 1. The Prompt (Suno/Udio/MusicGen)
Use these specific keywords to get the *DreamHunter* vibe:
> **Prompt:** *"Dark ambient, 120bpm, repetitive creepy nursery rhyme, out-of-tune music box, deep distorted sub-bass, minimalist horror, catchy hypnotic loop, 8-bit glitch, haunting female hum, minimalist."*

### 2. The "Remix" (Audacity Techniques)
Never use AI audio "as-is." Perform these 3 steps in Audacity to make it unique:
1.  **The Slow Down:** `Effect -> Pitch and Tempo -> Change Speed`. Reduce by **10-15%**. This makes "happy" melodies sound uncanny and heavy.
2.  **The Reverb (The "Dream" Feel):** `Effect -> Delay and Reverb -> Reverb`. Set Room Size to **80%**. This adds a "haunted house" atmosphere.
3.  **The Reverse Echo:** 
    - Copy a 2-second snippet.
    - Reverse it (`Effect -> Reverse`).
    - Layer it *before* the original sound begins. This creates a "sucking" ghost sound.

---

## ⚖️ Copyright & Safety Mandates

To ensure you are **never** copyrighted:
1.  **NO "In the Style of":** Never use artist names (e.g., "In the style of Hans Zimmer") in your prompts. Describe **instruments** instead (e.g., "broken toy piano").
2.  **Derivative Work:** By slowing down, reversing, or layering SFX over the AI music in Audacity, you create a "Derivative Work," which is legally distinct from the original AI output.
3.  **School/Indie Use:** As a student/indie dev, Suno/Udio's free tiers are generally safe. If you plan to sell the game, paying for **1 month of Pro** legally transfers ownership of all tracks generated that month to you permanently.

---

## 🚀 Flutter Implementation

Once you have your `.mp3` or `.wav` file:

1.  Place it in: `frontend/assets/audio/background_music.mp3`
2.  Register in `pubspec.yaml`:
    ```yaml
    flutter:
      assets:
        - assets/audio/
    ```
3.  Use the `audioplayers` package (already in project) to loop:
    ```dart
    final player = AudioPlayer();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('audio/background_music.mp3'));
    ```

---

*“The best horror music is the one you can’t stop humming, but makes you feel like someone is watching you.”*
