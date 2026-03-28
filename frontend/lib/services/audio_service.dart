import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  String? _currentBgm;
  bool _isMuted = false;
  double _volume = 0.5;

  Future<void> initialize() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_volume);
  }

  Future<void> playBGM(String assetPath) async {
    if (_currentBgm == assetPath) return;

    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.play(AssetSource(assetPath));
      _currentBgm = assetPath;
      await _bgmPlayer.setVolume(_isMuted ? 0 : _volume);
      developer.log('Playing BGM: $assetPath', name: 'AudioService');
    } catch (e) {
      developer.log('Error playing BGM: $e', name: 'AudioService', error: e);
    }
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _bgmPlayer.setVolume(_isMuted ? 0 : _volume);
    developer.log('Mute toggled: $_isMuted', name: 'AudioService');
  }

  bool get isMuted => _isMuted;

  Future<void> setVolume(double volume) async {
    _volume = volume;
    if (!_isMuted) {
      await _bgmPlayer.setVolume(_volume);
    }
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
