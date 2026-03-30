import 'package:audioplayers/audioplayers.dart';
import 'dart:developer' as developer;
import 'offline_cache.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _bgmPlayer = AudioPlayer();
  final List<AudioPlayer> _sfxPlayers = List.generate(3, (_) => AudioPlayer());
  int _nextSfxPlayerIndex = 0;
  
  String? _currentBgm;
  bool _isMusicMuted = false;
  bool _isSoundMuted = false;
  double _musicVolume = 0.72;
  double _soundVolume = 1.0;
  bool _isPlaylistActive = false;

  Future<void> initialize() async {
    try {
      // 0. Set GLOBAL Audio Context to prevent focus conflicts
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.assistanceSonification,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none, // Do not snatch focus by default
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );

      // 1. Configure BGM Player specifically for GAIN (persistent focus)
      await _bgmPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gain, // Request persistent focus
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );

      // 2. Configure SFX Players for NO focus
      for (final player in _sfxPlayers) {
        await player.setAudioContext(
          AudioContext(
            android: AudioContextAndroid(
              usageType: AndroidUsageType.assistanceSonification,
              contentType: AndroidContentType.sonification,
              audioFocus: AndroidAudioFocus.none, // Never steal focus
            ),
            iOS: AudioContextIOS(
              category: AVAudioSessionCategory.ambient,
              options: {AVAudioSessionOptions.mixWithOthers},
            ),
          ),
        );
      }

      // Load saved settings
      final settings = await OfflineCache.getSettings();
      _isMusicMuted = !(settings['music'] ?? true);
      _isSoundMuted = !(settings['sfx'] ?? true);
      _musicVolume = (settings['musicVolume'] as num?)?.toDouble() ?? 0.72;
      _soundVolume = (settings['sfxVolume'] as num?)?.toDouble() ?? 1.0;

      // Handle track completion for looping/playlist
      _bgmPlayer.onPlayerComplete.listen((_) {
        developer.log('BGM Complete: PlaylistActive=$_isPlaylistActive, Current=$_currentBgm', name: 'AudioService');
        if (_isPlaylistActive) {
          _handlePlaylistNext();
        } else if (!_isMusicMuted && _currentBgm != null) {
          _bgmPlayer.play(AssetSource(_currentBgm!));
        }
      });

      // LOG FOCUS CHANGES (Helpful for debugging -1 errors)
      _bgmPlayer.onLog.listen((msg) {
        if (msg.contains('AudioFocus')) {
          developer.log('Audio Focus Status: $msg', name: 'AudioService');
        }
      });

      // Apply initial volumes
      await _bgmPlayer.setVolume(_isMusicMuted ? 0 : _musicVolume);
      for (final player in _sfxPlayers) {
        await player.setVolume(_isSoundMuted ? 0 : _soundVolume);
      }

      // WARM UP: Pre-load and set sources for critical SFX to fix 3s delay
      await _warmUpSounds(['audio/click.ogg', 'audio/roulette.ogg']);

      developer.log(
        'AudioService initialized: MusicMuted=$_isMusicMuted, SFXMuted=$_isSoundMuted, MusicVol=$_musicVolume, SFXVol=$_soundVolume',
        name: 'AudioService',
      );
    } catch (e) {
      developer.log('Error initializing AudioService: $e', name: 'AudioService');
    }
  }

  /// Explicitly pre-load sounds into player instances to fix latency.
  Future<void> _warmUpSounds(List<String> assetPaths) async {
    for (final path in assetPaths) {
      try {
        await AudioCache.instance.load(path);
        // Pre-set the source on all players to ensure it is ready
        for (final player in _sfxPlayers) {
          await player.setSource(AssetSource(path));
        }
        developer.log('Warmed up sound: $path', name: 'AudioService');
      } catch (e) {
        developer.log('Error warming up sound: $path - $e', name: 'AudioService');
      }
    }
  }

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
    
    // Toggle between track1 and tract2
    final nextTrack = (_currentBgm == 'audio/track1.ogg') 
        ? 'audio/tract2.ogg' 
        : 'audio/track1.ogg';
    
    developer.log('Playlist rotating to next track: $nextTrack', name: 'AudioService');
    playBGM(nextTrack, isPlaylist: true);
  }

  Future<void> playBGM(String assetPath, {bool isPlaylist = false, double? volumeOverride}) async {
    _isPlaylistActive = isPlaylist;
    final targetVolume = _isMusicMuted ? 0.0 : (volumeOverride ?? _musicVolume);

    if (_currentBgm == assetPath && _bgmPlayer.state == PlayerState.playing) {
      await _bgmPlayer.setVolume(targetVolume);
      return;
    }

    try {
      _currentBgm = assetPath;
      developer.log('Starting BGM: $assetPath (Playlist: $isPlaylist, Vol: $targetVolume)', name: 'AudioService');
      
      await _bgmPlayer.stop();
      await _bgmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      // Use ReleaseMode.release to ensure completion events trigger correctly
      await _bgmPlayer.setReleaseMode(ReleaseMode.release);
      await _bgmPlayer.setVolume(targetVolume);
      await _bgmPlayer.play(AssetSource(assetPath));
    } catch (e) {
      developer.log('Error playing BGM: $e', name: 'AudioService', error: e);
    }
  }

  /// Plays the dashboard playlist (Track 1 & Track 2 alternating)
  Future<void> playDashboardMusic() async {
    await playBGM('audio/track1.ogg', isPlaylist: true);
  }

  /// Plays music specifically for the game, starting over with 15% more volume.
  Future<void> playInGameMusic() async {
    final gameVolume = (_musicVolume * 1.15).clamp(0.0, 1.0);
    final track = _currentBgm ?? 'audio/track1.ogg';
    _currentBgm = null; // Force restart
    await playBGM(track, isPlaylist: true, volumeOverride: gameVolume);
  }

  Future<void> playSFX(String assetPath) async {
    if (_isSoundMuted || _soundVolume <= 0.01) return;

    try {
      final player = _sfxPlayers[_nextSfxPlayerIndex];
      _nextSfxPlayerIndex = (_nextSfxPlayerIndex + 1) % _sfxPlayers.length;

      // Don't wait for the setVolume here if already set, but ensure it matches
      player.setVolume(_soundVolume); 
      
      // Use PlayerMode.lowLatency for snappy SFX (SoundPool on Android)
      // Since we 'warmed up' these players, this should be instant.
      player.play(AssetSource(assetPath), mode: PlayerMode.lowLatency);
    } catch (e) {
      developer.log('Error playing SFX: $assetPath - $e', name: 'AudioService');
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
    for (final player in _sfxPlayers) {
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
    // Apply immediately if not muted
    if (!_isMusicMuted) {
      await _bgmPlayer.setVolume(_musicVolume);
    }
  }

  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume;
    // Apply immediately if not muted
    if (!_isSoundMuted) {
      for (final player in _sfxPlayers) {
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
    _bgmPlayer.dispose();
    for (final player in _sfxPlayers) {
      player.dispose();
    }
  }
}
