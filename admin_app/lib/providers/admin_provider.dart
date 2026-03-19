import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/offline_cache.dart';

class AdminProvider with ChangeNotifier {
  final AdminService _adminService = AdminService();

  Map<String, dynamic>? _statsSummary;
  bool _isLoadingStats = false;
  String? _statsErrorMessage;

  Map<String, dynamic>? _currentUserProfile;
  bool _isLoadingProfile = false;

  Map<String, dynamic>? get statsSummary => _statsSummary;
  bool get isLoadingStats => _isLoadingStats;
  String? get statsErrorMessage => _statsErrorMessage;

  Map<String, dynamic>? get currentUserProfile => _currentUserProfile;
  bool get isAdmin => _currentUserProfile?['isAdmin'] == true;
  bool get isModerator => _currentUserProfile?['isModerator'] == true;

  AdminProvider() {
    _loadFromCache();
    _fetchCurrentUserProfile();
  }

  Future<void> _fetchCurrentUserProfile() async {
    _isLoadingProfile = true;
    notifyListeners();
    try {
      final user = _adminService.currentUser;
      if (user != null) {
        final profile = await _adminService.getUserProfile(user.uid);
        _currentUserProfile = profile;
      }
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromCache() async {
    final cached = await OfflineCache.getStatsSummary();
    if (cached != null) {
      _statsSummary = cached;
      notifyListeners();
    }
  }

  Future<void> fetchStats({bool forceRefresh = false}) async {
    if (_statsSummary == null || forceRefresh) {
      _isLoadingStats = _statsSummary == null;
      _statsErrorMessage = null;
      notifyListeners();
    }

    try {
      final stats = await _adminService.getStatsSummary();
      _statsSummary = stats;
      if (stats != null) {
        await OfflineCache.saveStatsSummary(stats);
      }
      _statsErrorMessage = null;
    } catch (e) {
      _statsErrorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  Future<void> updateMaintenance(bool? chat, bool? shop) async {
    final success = await _adminService.updateMaintenance(chat, shop);
    if (success) {
      // Logic for refreshing local system config could be added here if needed
      notifyListeners();
    }
  }
}
