import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;
import 'offline_cache.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';

class AudioService with WidgetsBindingObserver {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  // Dual BGM players for gapless/lag-free alternating
  final AudioPlayer _bgmPlayerA = AudioPlayer();
  final AudioPlayer _bgmPlayerB = AudioPlayer();
  bool _usePlayerA = true;

  // Pool of SFX players
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _nextSfxIndex = 0;

  String? _currentBgm;
  bool _isMusicMuted = false;
  bool _isSoundMuted = false;
  double _musicVolume = 0.79;
  double _soundVolume = 1.0;
  bool _isPlaylistActive = false;
  bool _wasPlayingBeforePause = false;

  AudioPlayer get _activeBgmPlayer => _usePlayerA ? _bgmPlayerA : _bgmPlayerB;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause && !_isMusicMuted && _currentBgm != null) {
        resumeBGM();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _wasPlayingBeforePause = _activeBgmPlayer.state == PlayerState.playing;
      if (_wasPlayingBeforePause) {
        pauseBGM();
      }
    }
  }

  Future<void> initialize() async {
    developer.log(
      'AudioService: Initializing (Gapless Android Edition)...',
      name: 'AudioService',
    );
    try {
      final context = AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      );

      await AudioPlayer.global.setAudioContext(context);

      // Configure BGM Players
      for (final p in [_bgmPlayerA, _bgmPlayerB]) {
        await p.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              stayAwake: true,
              usageType: AndroidUsageType.game,
              contentType: AndroidContentType.music,
              audioFocus: AndroidAudioFocus.none,
            ),
          ),
        );
        await p.setReleaseMode(ReleaseMode.stop);

        p.onPlayerComplete.listen((_) {
          if (_isPlaylistActive) _handlePlaylistNext();
        });
      }

      // Configure SFX Pool
      for (final p in _sfxPool) {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setAudioContext(context);
      }

      // Load settings
      final settings = await OfflineCache.getSettings();
      _isMusicMuted = !(settings['music'] ?? true);
      _isSoundMuted = !(settings['sfx'] ?? true);

      // FORCE VOLUME to 0.79 to override any old cached low values
      _musicVolume = 0.79;
      _soundVolume = 1.0;

      await _applyVolumes();

      // Aggressive SFX Warm-up
      unawaited(
        _warmUpPool([
          'audio/click.ogg',
          'audio/roulette.ogg',
          'audio/reward.ogg',
          'audio/levelup.ogg',
        ]),
      );

      developer.log(
        'AudioService: Initialization complete. BGM Vol: $_musicVolume',
        name: 'AudioService',
      );
    } catch (e) {
      developer.log(
        'AudioService: ERROR during initialization: $e',
        name: 'AudioService',
      );
    }
  }

  Future<void> _applyVolumes() async {
    final mVol = _isMusicMuted ? 0.0 : _musicVolume;
    final sVol = _isSoundMuted ? 0.0 : _soundVolume;

    await _bgmPlayerA.setVolume(mVol);
    await _bgmPlayerB.setVolume(mVol);
    for (final p in _sfxPool) {
      await p.setVolume(sVol);
    }
  }

  Future<void> _warmUpPool(List<String> assetPaths) async {
    for (final path in assetPaths) {
      try {
        final source = AssetSource(path);
        await AudioCache.instance.load(path);
        for (final p in _sfxPool) {
          await p.setSource(source);
        }
      } catch (e) {
        developer.log(
          'AudioService: Warmup fail for $path: $e',
          name: 'AudioService',
        );
      }
    }
  }

  void precacheSound(String assetPath) {
    unawaited(AudioCache.instance.load(assetPath));
  }

  void _handlePlaylistNext() {
    if (!_isPlaylistActive) return;

    final nextTrack = (_currentBgm == 'audio/track1.ogg')
        ? 'audio/track2.ogg'
        : 'audio/track1.ogg';

    // Gapless swap: Start next track on inactive player
    _currentBgm = nextTrack;
    final targetVol = _isMusicMuted ? 0.0 : _musicVolume;

    _usePlayerA = !_usePlayerA; // Swap!

    unawaited(_activeBgmPlayer.setVolume(targetVol));
    unawaited(_activeBgmPlayer.play(AssetSource(nextTrack)));

    developer.log(
      'AudioService: Playlist swapped to $nextTrack',
      name: 'AudioService',
    );
  }

  Future<void> playBGM(
    String assetPath, {
    bool isPlaylist = false,
    double? volumeOverride,
  }) async {
    _isPlaylistActive = isPlaylist;
    final targetVolume = _isMusicMuted ? 0.0 : (volumeOverride ?? _musicVolume);

    if (_currentBgm == assetPath &&
        _activeBgmPlayer.state == PlayerState.playing) {
      await _activeBgmPlayer.setVolume(targetVolume);
      return;
    }

    try {
      _currentBgm = assetPath;
      await _activeBgmPlayer.stop();
      await _activeBgmPlayer.setVolume(targetVolume);
      await _activeBgmPlayer.play(AssetSource(assetPath));
    } catch (e) {
      developer.log('AudioService: BGM Error: $e', name: 'AudioService');
    }
  }

  void playDashboardMusic() {
    unawaited(playBGM('audio/track1.ogg', isPlaylist: true));
  }

  Future<void> playInGameMusic() async {
    final gameVolume = (_musicVolume * 1.20).clamp(0.0, 1.0);
    final track = _currentBgm ?? 'audio/track1.ogg';
    await playBGM(track, isPlaylist: true, volumeOverride: gameVolume);
  }

  void playSFX(String assetPath) {
    if (_isSoundMuted || _soundVolume <= 0.01) return;

    // Use unawaited to trigger sound instantly without waiting for platform channel return
    unawaited(_playSfxImmediately(assetPath));
  }

  Future<void> _playSfxImmediately(String assetPath) async {
    try {
      final player = _sfxPool[_nextSfxIndex];
      _nextSfxIndex = (_nextSfxIndex + 1) % _sfxPool.length;

      // DO NOT await stop or setVolume if possible, just play.
      // But we need the volume.
      player.setVolume(_soundVolume);
      player.play(AssetSource(assetPath), mode: PlayerMode.lowLatency);
    } catch (e) {
      developer.log('AudioService: SFX Error: $e', name: 'AudioService');
    }
  }

  Future<void> playClick() async => playSFX('audio/click.ogg');
  Future<void> playRouletteSpin() async => playSFX('audio/roulette.ogg');
  Future<void> playLevelUp() async => playSFX('audio/levelup.ogg');
  Future<void> playReward() async => playSFX('audio/reward.ogg');

  Future<void> toggleMusicMute() async {
    _isMusicMuted = !_isMusicMuted;
    await _applyVolumes();
  }

  Future<void> toggleSoundMute() async {
    _isSoundMuted = !_isSoundMuted;
    await _applyVolumes();
  }

  bool get isMusicMuted => _isMusicMuted;
  bool get isSoundMuted => _isSoundMuted;
  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume;
    await _applyVolumes();
  }

  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume;
    await _applyVolumes();
  }

  Future<void> stopBGM() async {
    await _bgmPlayerA.stop();
    await _bgmPlayerB.stop();
    _currentBgm = null;
  }

  Future<void> pauseBGM() async {
    await _activeBgmPlayer.pause();
  }

  Future<void> resumeBGM() async {
    await _activeBgmPlayer.resume();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgmPlayerA.dispose();
    _bgmPlayerB.dispose();
    for (final p in _sfxPool) {
      p.dispose();
    }
  }
}
