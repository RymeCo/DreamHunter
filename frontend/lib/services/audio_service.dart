import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  String? _currentBgm;
  bool _isMusicMuted = false;
  bool _isSoundMuted = false;
  double _musicVolume = 0.5;
  double _soundVolume = 1.0;

  Future<void> initialize() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_musicVolume);
    await _sfxPlayer.setVolume(_soundVolume);
  }

  Future<void> playBGM(String assetPath) async {
    if (_currentBgm == assetPath) return;

    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource(assetPath));
      _currentBgm = assetPath;
      await _bgmPlayer.setVolume(_isMusicMuted ? 0 : _musicVolume);
      developer.log('Playing BGM: $assetPath', name: 'AudioService');
    } catch (e) {
      developer.log('Error playing BGM: $e', name: 'AudioService', error: e);
    }
  }

  Future<void> playSFX(String assetPath) async {
    if (_isSoundMuted) return;
    try {
      // Use a new player for each SFX to allow overlapping sounds
      final player = AudioPlayer();
      await player.setVolume(_soundVolume);
      await player.play(AssetSource(assetPath));
      player.onPlayerComplete.listen((_) => player.dispose());
    } catch (e) {
      developer.log('Error playing SFX: $e', name: 'AudioService', error: e);
    }
  }

  Future<void> playClick() async {
    await playSFX('audio/click.ogg');
  }

  Future<void> toggleMusicMute() async {
    _isMusicMuted = !_isMusicMuted;
    await _bgmPlayer.setVolume(_isMusicMuted ? 0 : _musicVolume);
    developer.log('Music mute toggled: $_isMusicMuted', name: 'AudioService');
  }

  Future<void> toggleSoundMute() async {
    _isSoundMuted = !_isSoundMuted;
    developer.log('Sound mute toggled: $_isSoundMuted', name: 'AudioService');
  }

  bool get isMusicMuted => _isMusicMuted;
  bool get isSoundMuted => _isSoundMuted;

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume;
    if (!_isMusicMuted) {
      await _bgmPlayer.setVolume(_musicVolume);
    }
  }

  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume;
  }

  Future<void> stopBGM() async {
    await _bgmPlayer.stop();
    _currentBgm = null;
  }

  Future<void> pauseBGM() async {
    await _bgmPlayer.pause();
  }

  Future<void> resumeBGM() async {
    await _bgmPlayer.resume();
  }

  void dispose() {
    _bgmPlayer.dispose();
  }
}
