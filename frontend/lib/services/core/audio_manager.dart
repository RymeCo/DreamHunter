import 'package:audioplayers/audioplayers.dart';
import 'package:dreamhunter/services/core/storage_engine.dart';
import 'package:flutter/widgets.dart';
import 'dart:async';

/// Optimized Singleton service for gapless BGM and low-latency SFX.
class AudioManager with WidgetsBindingObserver {
  static final AudioManager instance = AudioManager._internal();
  factory AudioManager() => instance;
  AudioManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  // Dual BGM players for gapless alternating
  final AudioPlayer _bgmPlayerA = AudioPlayer();
  final AudioPlayer _bgmPlayerB = AudioPlayer();
  bool _usePlayerA = true;

  // Optimized SFX pool
  final List<AudioPlayer> _sfxPool = List.generate(4, (_) => AudioPlayer());
  int _nextSfxIndex = 0;

  String? _currentBgm;
  bool _isMusicMuted = false;
  bool _isSoundMuted = false;
  double _musicVolume = 0.8;
  double _soundVolume = 1.0;
  bool _isPlaylistActive = false;
  bool _wasPlayingBeforePause = false;
  bool _isGameMode = false;

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
      if (_wasPlayingBeforePause) pauseBGM();
    }
  }

  Future<void> initialize() async {
    try {
      final sfxContext = AudioContext(
        android: AudioContextAndroid(
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      );

      // Load Settings
      final settings = await StorageEngine.instance.getSettings();
      _isMusicMuted = !(settings['music'] ?? true);
      _isSoundMuted = !(settings['sfx'] ?? true);
      _musicVolume = (settings['musicVolume'] as num? ?? 0.8).toDouble();
      _soundVolume = (settings['sfxVolume'] as num? ?? 1.0).toDouble();

      // Configure Players
      for (final p in [_bgmPlayerA, _bgmPlayerB]) {
        await p.setReleaseMode(ReleaseMode.stop);
        p.onPlayerComplete.listen((_) {
          if (_isPlaylistActive) _handlePlaylistNext();
        });
      }

      for (final p in _sfxPool) {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setAudioContext(sfxContext);
      }

      await _applyVolumes();

      // Warm-up (Memory Efficient)
      unawaited(
        _warmUpPool([
          'audio/click.ogg',
          'audio/roulette.ogg',
          'audio/reward.ogg',
        ]),
      );
    } catch (e) {
      // AudioManager Init Error
    }
  }

  Future<void> _applyVolumes() async {
    final double musicBoost = _isGameMode ? 1.1 : 1.0;
    final double soundBoost = _isGameMode ? 1.1 : 1.0;

    double effectiveMusicVol = (_musicVolume * musicBoost).clamp(0.0, 1.0);
    double effectiveSoundVol = (_soundVolume * soundBoost).clamp(0.0, 1.0);

    final mVol = _isMusicMuted ? 0.0 : effectiveMusicVol;
    final sVol = _isSoundMuted ? 0.0 : effectiveSoundVol;

    await _bgmPlayerA.setVolume(mVol);
    await _bgmPlayerB.setVolume(mVol);
    for (final p in _sfxPool) {
      await p.setVolume(sVol);
    }
  }

  /// Activates a volume boost (10%) when in game mode.
  Future<void> setGameMode(bool active) async {
    _isGameMode = active;
    await _applyVolumes();
  }

  Future<void> _persistSettings() async {
    await StorageEngine.instance.saveSettings({
      'music': !_isMusicMuted,
      'sfx': !_isSoundMuted,
      'musicVolume': _musicVolume,
      'sfxVolume': _soundVolume,
    });
  }

  Future<void> _warmUpPool(List<String> assetPaths) async {
    for (final path in assetPaths) {
      await precacheSound(path);
    }
  }

  Future<void> precacheSound(String assetPath) async {
    await AudioCache.instance.load(assetPath);
  }

  void _handlePlaylistNext() {
    if (!_isPlaylistActive) return;
    final nextTrack = (_currentBgm == 'audio/track1.ogg')
        ? 'audio/track2.ogg'
        : 'audio/track1.ogg';
    playBGM(nextTrack, isPlaylist: true);
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
      _usePlayerA = !_usePlayerA; // Swap players for gapless potential
      await _activeBgmPlayer.setVolume(targetVolume);
      await _activeBgmPlayer.play(AssetSource(assetPath));
    } catch (e) {
      // AudioManager BGM Error
    }
  }

  void playDashboardMusic() =>
      unawaited(playBGM('audio/track1.ogg', isPlaylist: true));

  void playSFX(String assetPath) {
    if (_isSoundMuted || _soundVolume <= 0.01) return;
    final player = _sfxPool[_nextSfxIndex];
    _nextSfxIndex = (_nextSfxIndex + 1) % _sfxPool.length;
    player.play(AssetSource(assetPath), mode: PlayerMode.lowLatency);
  }

  // Common SFX Wrappers
  void playClick() => playSFX('audio/click.ogg');
  void playRouletteSpin() => playSFX('audio/roulette.ogg');
  void playLevelUp() => playSFX('audio/levelup.ogg');
  void playReward() => playSFX('audio/reward.ogg');
  void playError() => playSFX('audio/error.ogg');

  // Control Methods with Auto-Persistence
  Future<void> toggleMusicMute() async {
    _isMusicMuted = !_isMusicMuted;
    await _applyVolumes();
    await _persistSettings();
  }

  Future<void> toggleSoundMute() async {
    _isSoundMuted = !_isSoundMuted;
    await _applyVolumes();
    await _persistSettings();
  }

  Future<void> setMusicVolume(double vol) async {
    _musicVolume = vol;
    await _applyVolumes();
    await _persistSettings();
  }

  Future<void> setSoundVolume(double vol) async {
    _soundVolume = vol;
    await _applyVolumes();
    await _persistSettings();
  }

  bool get isMusicMuted => _isMusicMuted;
  bool get isSoundMuted => _isSoundMuted;
  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;

  Future<void> stopBGM() async {
    await _bgmPlayerA.stop();
    await _bgmPlayerB.stop();
    _currentBgm = null;
  }

  Future<void> pauseBGM() async => await _activeBgmPlayer.pause();
  Future<void> resumeBGM() async => await _activeBgmPlayer.resume();
}
