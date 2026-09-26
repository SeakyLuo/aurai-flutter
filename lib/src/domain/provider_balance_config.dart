class ProviderBalanceConfig {
  const ProviderBalanceConfig({
    required this.url,
    required this.totalPath,
    required this.toppedUpPath,
    required this.grantedPath,
    this.itemsPath = '',
    this.availablePath = '',
    this.successPath = '',
    this.successValue = 'true',
    this.currencyPath = '',
    this.currency = '',
    this.grantedLabel = '赠金',
    this.topUpUrl = '',
  });

  final String url;
  final String itemsPath;
  final String availablePath;
  final String successPath;
  final String successValue;
  final String currencyPath;
  final String currency;
  final String totalPath;
  final String toppedUpPath;
  final String grantedPath;
  final String grantedLabel;
  final String topUpUrl;

  Map<String, Object?> toJson() => {
    'url': url,
    'itemsPath': itemsPath,
    'availablePath': availablePath,
    'successPath': successPath,
    'successValue': successValue,
    'currencyPath': currencyPath,
    'currency': currency,
    'totalPath': totalPath,
    'toppedUpPath': toppedUpPath,
    'grantedPath': grantedPath,
    'grantedLabel': grantedLabel,
    'topUpUrl': topUpUrl,
  };

  factory ProviderBalanceConfig.fromJson(Map<String, dynamic> json) =>
      ProviderBalanceConfig(
        url: json['url'] as String,
        itemsPath: json['itemsPath'] as String? ?? '',
        availablePath: json['availablePath'] as String? ?? '',
        successPath: json['successPath'] as String? ?? '',
        successValue: json['successValue'] as String? ?? 'true',
        currencyPath: json['currencyPath'] as String? ?? '',
        currency: json['currency'] as String? ?? '',
        totalPath: json['totalPath'] as String,
        toppedUpPath: json['toppedUpPath'] as String,
        grantedPath: json['grantedPath'] as String,
        grantedLabel: json['grantedLabel'] as String? ?? '赠金',
        topUpUrl: json['topUpUrl'] as String? ?? '',
      );
}
