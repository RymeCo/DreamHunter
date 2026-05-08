import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String latestVersion;
  final String changelog;
  final String downloadUrl;
  final bool isUpdateAvailable;

  UpdateInfo({
    required this.latestVersion,
    required this.changelog,
    required this.downloadUrl,
    required this.isUpdateAvailable,
  });
}

class UpdateService {
  static const String repoOwner = 'rymeco';
  static const String repoName = 'DreamHunter';
  static const String githubApiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Fetches the latest release info from GitHub and compares it with the local version.
  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      // 1. Get Local Version
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;

      // 2. Fetch Latest Release from GitHub
      final response = await http.get(Uri.parse(githubApiUrl));
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body);
      final String latestTag = data['tag_name'] ?? '';
      // Remove 'v' prefix if present for comparison
      final String latestVersion = latestTag.startsWith('v')
          ? latestTag.substring(1)
          : latestTag;
      final String changelog = data['body'] ?? 'No release notes provided.';
      final String htmlUrl =
          data['html_url'] ??
          'https://github.com/$repoOwner/$repoName/releases';

      // 3. Compare Versions
      final isAvailable = _isVersionNewer(localVersion, latestVersion);

      return UpdateInfo(
        latestVersion: latestVersion,
        changelog: changelog,
        downloadUrl: htmlUrl,
        isUpdateAvailable: isAvailable,
      );
    } catch (e) {
      return null;
    }
  }

  /// Simple version comparison (e.g., 0.1.0 vs 0.1.1)
  static bool _isVersionNewer(String local, String latest) {
    if (local == latest) return false;

    final localParts = local.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (var i = 0; i < localParts.length && i < latestParts.length; i++) {
      if (latestParts[i] > localParts[i]) return true;
      if (latestParts[i] < localParts[i]) return false;
    }

    return latestParts.length > localParts.length;
  }

  /// Opens the release page in the default browser.
  static Future<void> downloadUpdate(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
