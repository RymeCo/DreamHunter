class BackendConfig {
  static const String baseUrl = 'https://dreamhunter-api.onrender.com';
  static const String apiVersion = 'v1';
  
  // Shared keys for OfflineCache to prevent typos across apps
  static const String currencyKey = 'cached_currency';
  static const String transactionQueueKey = 'transaction_queue';
  static const String settingsKey = 'app_settings';
  static const String inventoryKey = 'cached_inventory';
  static const String progressKey = 'cached_progress';
  static const String dailyTasksKey = 'cached_daily_tasks';
  static const String lastSyncKey = 'last_sync_timestamp';
  static const String lastSyncStatusKey = 'last_sync_status';
  static const String statsSummaryKey = 'cached_stats_summary';
}
