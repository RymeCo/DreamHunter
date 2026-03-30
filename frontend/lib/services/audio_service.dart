import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;
import 'offline_cache.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  String? _currentBgm;
  bool _isMusicMuted = false;
  bool _isSoundMuted = false;
  double _musicVolume = 0.72;
  double _soundVolume = 1.0;
  bool _isPlaylistActive = false;

  Future<void> initialize() async {
    try {
      // Configure global audio context for Android/iOS
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        ),
      );

      // Load saved settings
      final settings = await OfflineCache.getSettings();
      _isMusicMuted = !(settings['music'] ?? true);
      _isSoundMuted = !(settings['sfx'] ?? true);
      _musicVolume = (settings['musicVolume'] as num?)?.toDouble() ?? 0.72;
      _soundVolume = (settings['sfxVolume'] as num?)?.toDouble() ?? 1.0;

      // Handle track completion for looping/playlist
      _bgmPlayer.onPlayerComplete.listen((_) {
        if (_isPlaylistActive) {
          _handlePlaylistNext();
        } else if (!_isMusicMuted && _currentBgm != null) {
          _bgmPlayer.play(AssetSource(_currentBgm!));
        }
      });

      // Apply initial volumes
      await _bgmPlayer.setVolume(_isMusicMuted ? 0 : _musicVolume);
      await _sfxPlayer.setVolume(_isSoundMuted ? 0 : _soundVolume);

      developer.log(
        'AudioService initialized: MusicMuted=$_isMusicMuted, SFXMuted=$_isSoundMuted, MusicVol=$_musicVolume, SFXVol=$_soundVolume',
        name: 'AudioService',
      );
    } catch (e) {
      developer.log(
        'Error initializing AudioService: $e',
        name: 'AudioService',
      );
    }
  }

  /// Explicitly pre-cache an audio file to avoid latency or SoundPool errors.
  Future<void> precacheSound(String assetPath) async {
    try {
      await AudioCache.instance.load(assetPath);
      developer.log('Pre-cached sound: $assetPath', name: 'AudioService');
    } catch (e) {
      developer.log('Error pre-caching sound: $assetPath - $e', name: 'AudioService');
    }
  }

  void _handlePlaylistNext() {
    if (!_isPlaylistActive) return;
    
    // Simple toggle between track1 and tract2
    final nextTrack = (_currentBgm == 'audio/track1.ogg') 
        ? 'audio/tract2.ogg' 
        : 'audio/track1.ogg';
    
    developer.log('Playlist moving to next track: $nextTrack', name: 'AudioService');
    playBGM(nextTrack, isPlaylist: true);
  }

  Future<void> playBGM(String assetPath, {bool isPlaylist = false}) async {
    _isPlaylistActive = isPlaylist;
    
    if (_currentBgm == assetPath) {
      if (_bgmPlayer.state == PlayerState.playing) return;
      await _bgmPlayer.resume();
      return;
    }

    try {
      _currentBgm = assetPath;
      developer.log('Starting BGM: $assetPath (Playlist: $isPlaylist)', name: 'AudioService');
      await _bgmPlayer.stop();
      // Only set loop mode if NOT a playlist (playlist handles completion manually)
      await _bgmPlayer.setReleaseMode(isPlaylist ? ReleaseMode.release : ReleaseMode.loop);
      await _bgmPlayer.setVolume(_isMusicMuted ? 0 : _musicVolume);
      await _bgmPlayer.play(AssetSource(assetPath));
    } catch (e) {
      developer.log('Error playing BGM: $e', name: 'AudioService', error: e);
    }
  }

  /// Plays the dashboard playlist (Track 1 & Track 2 alternating)
  Future<void> playDashboardMusic() async {
    await playBGM('audio/track1.ogg', isPlaylist: true);
  }

  Future<void> playSFX(String assetPath) async {
    developer.log(
      'playSFX: $assetPath, Muted=$_isSoundMuted, Vol=$_soundVolume',
      name: 'AudioService',
    );
    if (_isSoundMuted || _soundVolume <= 0.01) return;

    try {
      await _sfxPlayer.setVolume(_soundVolume);
      await _sfxPlayer.play(AssetSource(assetPath), mode: PlayerMode.lowLatency);
    } catch (e) {
      developer.log(
        'Error playing SFX: $assetPath - $e',
        name: 'AudioService',
        error: e,
      );
    }
  }

  Future<void> playClick() async {
    await playSFX('audio/click.ogg');
  }

  Future<void> playRouletteSpin() async {
    await playSFX('audio/roulette.ogg');
  }

  Future<void> toggleMusicMute() async {
    _isMusicMuted = !_isMusicMuted;
    await _bgmPlayer.setVolume(_isMusicMuted ? 0 : _musicVolume);
    developer.log('Music mute toggled: $_isMusicMuted', name: 'AudioService');
  }

  Future<void> toggleSoundMute() async {
    _isSoundMuted = !_isSoundMuted;
    if (_isSoundMuted) {
      await _sfxPlayer.stop();
    }
    await _sfxPlayer.setVolume(_isSoundMuted ? 0 : _soundVolume);
    developer.log('Sound mute toggled: $_isSoundMuted', name: 'AudioService');
  }

  bool get isMusicMuted => _isMusicMuted;
  bool get isSoundMuted => _isSoundMuted;
  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume;
    // Apply immediately if not muted
    if (!_isMusicMuted) {
      await _bgmPlayer.setVolume(_musicVolume);
    }
  }

  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume;
    // Apply immediately if not muted
    if (!_isSoundMuted) {
      await _sfxPlayer.setVolume(_soundVolume);
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
