import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;
import 'offline_cache.dart';
import 'package:flutter/widgets.dart';

class AudioService with WidgetsBindingObserver {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioPlayer _bgmPlayer = AudioPlayer();
  // Pool of SFX players to allow overlapping sounds (like multiple clicks)
  final List<AudioPlayer> _sfxPool = List.generate(3, (_) => AudioPlayer());
  int _nextSfxIndex = 0;
  
  String? _currentBgm;
  bool _isMusicMuted = false;
  bool _isSoundMuted = false;
  double _musicVolume = 0.79;
  double _soundVolume = 1.0;
  bool _isPlaylistActive = false;
  bool _wasPlayingBeforePause = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    developer.log('AppLifecycleState changed: $state', name: 'AudioService');
    if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause && !_isMusicMuted && _currentBgm != null) {
        developer.log('Resuming BGM after app resume: $_currentBgm', name: 'AudioService');
        resumeBGM();
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _wasPlayingBeforePause = _bgmPlayer.state == PlayerState.playing;
      if (_wasPlayingBeforePause) {
        developer.log('Pausing BGM for app background: $_currentBgm', name: 'AudioService');
        pauseBGM();
      }
    }
  }

  Future<void> initialize() async {
    developer.log('AudioService: Starting initialization (Android-focused)...', name: 'AudioService');
    try {
      // 0. Set GLOBAL Audio Context Baseline
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );

      // 1. Configure BGM Player (Main Music Focus)
      await _bgmPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            stayAwake: true,
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.none, 
          ),
        ),
      );

      // 2. Configure SFX Pool (Transparent Focus - Overlaps with Music)
      for (final player in _sfxPool) {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        );
      }

      // Load saved settings
      final settings = await OfflineCache.getSettings();
      _isMusicMuted = !(settings['music'] ?? true);
      _isSoundMuted = !(settings['sfx'] ?? true);
      _musicVolume = (settings['musicVolume'] as num?)?.toDouble() ?? 0.79;
      _soundVolume = (settings['sfxVolume'] as num?)?.toDouble() ?? 1.0;
      
      developer.log('AudioService: Settings loaded - Muted: $_isMusicMuted, Vol: $_musicVolume', name: 'AudioService');

      // Track BGM player state
      _bgmPlayer.onPlayerStateChanged.listen((state) {
        developer.log('AudioService: BGM Player State Change: $state', name: 'AudioService');
      });

      // Handle track completion for looping/playlist
      _bgmPlayer.onPlayerComplete.listen((_) {
        developer.log('AudioService: BGM Complete: PlaylistActive=$_isPlaylistActive', name: 'AudioService');
        if (_isPlaylistActive) {
          _handlePlaylistNext();
        } else if (!_isMusicMuted && _currentBgm != null) {
          _bgmPlayer.play(AssetSource(_currentBgm!));
        }
      });

      // Log Focus Changes to help debug WayDroid -1 issues
      _bgmPlayer.onLog.listen((msg) {
        developer.log('AudioService: BGM Log: $msg', name: 'AudioService');
      });

      // Apply initial volumes
      await _bgmPlayer.setVolume(_isMusicMuted ? 0 : _musicVolume);
      for (final player in _sfxPool) {
        await player.setVolume(_isSoundMuted ? 0 : _soundVolume);
      }

      // WARM UP (Non-blocking but aggressive)
      _warmUpPool(['audio/click.ogg', 'audio/roulette.ogg', 'audio/reward.ogg', 'audio/levelup.ogg']).catchError((e) {
        developer.log('AudioService: Warmup error (ignored): $e', name: 'AudioService');
      });

      developer.log('AudioService: Initialization complete', name: 'AudioService');
    } catch (e) {
      developer.log('AudioService: ERROR during initialization: $e', name: 'AudioService');
    }
  }

  /// Warm up the SFX pool by setting sources in advance.
  Future<void> _warmUpPool(List<String> assetPaths) async {
    for (final path in assetPaths) {
      try {
        await AudioCache.instance.load(path);
        // Pre-set the source on all pool players to reduce start latency
        for (final player in _sfxPool) {
          await player.setSource(AssetSource(path));
        }
      } catch (e) {
        developer.log('AudioService: Error warming up pool for $path: $e', name: 'AudioService');
      }
    }
  }

  Future<void> precacheSound(String assetPath) async {
    try {
      await AudioCache.instance.load(assetPath);
    } catch (e) {
      developer.log('AudioService: Error pre-caching sound $assetPath: $e', name: 'AudioService');
    }
  }

  void _handlePlaylistNext() {
    if (!_isPlaylistActive) return;
    
    // Toggle between track1 and track2
    final nextTrack = (_currentBgm == 'audio/track1.ogg') 
        ? 'audio/track2.ogg' 
        : 'audio/track1.ogg';
    
    developer.log('AudioService: Playlist rotating to: $nextTrack', name: 'AudioService');
    playBGM(nextTrack, isPlaylist: true);
  }

  Future<void> playBGM(String assetPath, {bool isPlaylist = false, double? volumeOverride}) async {
    _isPlaylistActive = isPlaylist;
    final targetVolume = _isMusicMuted ? 0.0 : (volumeOverride ?? _musicVolume);

    developer.log('AudioService: playBGM requested for $assetPath (Vol: $targetVolume)', name: 'AudioService');

    // If same track is already playing, just update volume and return
    if (_currentBgm == assetPath && _bgmPlayer.state == PlayerState.playing) {
      developer.log('AudioService: $assetPath already playing, updating volume.', name: 'AudioService');
      await _bgmPlayer.setVolume(targetVolume);
      return;
    }

    try {
      _currentBgm = assetPath;
      
      await _bgmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _bgmPlayer.setReleaseMode(ReleaseMode.stop);
      await _bgmPlayer.setVolume(targetVolume);
      
      if (_bgmPlayer.state != PlayerState.stopped) {
        await _bgmPlayer.stop();
      }
      
      developer.log('AudioService: Executing play for $assetPath', name: 'AudioService');
      await _bgmPlayer.play(AssetSource(assetPath));
    } catch (e) {
      developer.log('AudioService: ERROR playing BGM $assetPath: $e', name: 'AudioService');
    }
  }

  /// Plays the dashboard playlist (Track 1 & Track 2 alternating)
  Future<void> playDashboardMusic() async {
    await playBGM('audio/track1.ogg', isPlaylist: true);
  }

  /// Plays music specifically for the game, increasing volume by 20% seamlessly.
  Future<void> playInGameMusic() async {
    final gameVolume = (_musicVolume * 1.20).clamp(0.0, 1.0);
    final track = _currentBgm ?? 'audio/track1.ogg';
    
    developer.log('AudioService: playInGameMusic (Seamless Boost to $gameVolume for $track)', name: 'AudioService');
    await playBGM(track, isPlaylist: true, volumeOverride: gameVolume);
  }

  Future<void> playSFX(String assetPath) async {
    if (_isSoundMuted || _soundVolume <= 0.01) return;

    try {
      final player = _sfxPool[_nextSfxIndex];
      _nextSfxIndex = (_nextSfxIndex + 1) % _sfxPool.length;

      // Force stop before play to ensure immediate restart in lowLatency mode
      if (player.state == PlayerState.playing) {
        await player.stop();
      }

      await player.setVolume(_soundVolume);
      await player.play(AssetSource(assetPath), mode: PlayerMode.lowLatency);
    } catch (e) {
      developer.log('AudioService: Error playing SFX $assetPath: $e', name: 'AudioService');
    }
  }

  Future<void> playClick() async {
    await playSFX('audio/click.ogg');
  }

  Future<void> playRouletteSpin() async {
    await playSFX('audio/roulette.ogg');
  }

  Future<void> playLevelUp() async {
    await playSFX('audio/levelup.ogg');
  }

  Future<void> playReward() async {
    await playSFX('audio/reward.ogg');
  }

  Future<void> toggleMusicMute() async {
    _isMusicMuted = !_isMusicMuted;
    await _bgmPlayer.setVolume(_isMusicMuted ? 0 : _musicVolume);
    developer.log('Music mute toggled: $_isMusicMuted', name: 'AudioService');
  }

  Future<void> toggleSoundMute() async {
    _isSoundMuted = !_isSoundMuted;
    for (final player in _sfxPool) {
      if (_isSoundMuted) {
        await player.stop();
      }
      await player.setVolume(_isSoundMuted ? 0 : _soundVolume);
    }
    developer.log('Sound mute toggled: $_isSoundMuted', name: 'AudioService');
  }

  bool get isMusicMuted => _isMusicMuted;
  bool get isSoundMuted => _isSoundMuted;
  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume;
    if (!_isMusicMuted) {
      await _bgmPlayer.setVolume(_musicVolume);
    }
  }

  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume;
    if (!_isSoundMuted) {
      for (final player in _sfxPool) {
        await player.setVolume(_soundVolume);
      }
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
    WidgetsBinding.instance.removeObserver(this);
    _bgmPlayer.dispose();
    for (final player in _sfxPool) {
      player.dispose();
    }
  }
}
