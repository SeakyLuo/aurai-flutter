enum VoiceListAuthentication { header, hmacSha256 }

/// An HTTP catalog, including its response mapping and authentication scheme.
class SpeechVoiceListConfig {
  const SpeechVoiceListConfig({
    required this.url,
    this.method = 'GET',
    this.authentication = VoiceListAuthentication.header,
    this.authHeader = 'Authorization',
    this.authPrefix = 'Bearer ',
    this.apiKey = '',
    this.accessKey = '',
    this.secretKey = '',
    this.region = '',
    this.service = '',
    this.headers = const {},
    this.body = const {},
    this.listPath = 'data',
    this.idPath = 'id',
    this.namePath = 'name',
    this.avatarPath,
    this.previewTextPath,
    this.previewUrlPath,
    this.genderPath,
    this.genderValues = const {},
    this.descriptionPath,
    this.tagPaths = const [],
    this.pagePath = '',
    this.totalPath = '',
    this.pageSize = 100,
    this.maxPages = 20,
  });
  final String url, method, authHeader, authPrefix, apiKey;
  final String accessKey, secretKey, region, service;
  final String listPath, idPath, namePath;
  final String? avatarPath;
  final String? previewTextPath, previewUrlPath;
  final String? genderPath, descriptionPath;
  final Map<String, String> genderValues;
  final List<String> tagPaths;
  final String pagePath, totalPath;
  final int pageSize, maxPages;
  final VoiceListAuthentication authentication;
  final Map<String, String> headers;
  final Map<String, Object?> body;

  void validate() {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment) {
      throw ArgumentError('请填写有效的 HTTPS 音色列表接口地址');
    }
    if (!['GET', 'POST'].contains(method) ||
        idPath.isEmpty ||
        namePath.isEmpty) {
      throw ArgumentError('请完整配置音色列表请求与响应字段');
    }
    if (totalPath.isNotEmpty &&
        (pagePath.isEmpty ||
            pageSize < 1 ||
            pageSize > 1000 ||
            maxPages < 1 ||
            maxPages > 20)) {
      throw ArgumentError('请配置分页字段、每页数量与最多页数（不超过 20 页）');
    }
    if (authentication == VoiceListAuthentication.header &&
        authHeader.isEmpty) {
      throw ArgumentError('请填写鉴权请求头');
    }
    if (authentication == VoiceListAuthentication.hmacSha256 &&
        (accessKey.isEmpty ||
            secretKey.isEmpty ||
            region.isEmpty ||
            service.isEmpty)) {
      throw ArgumentError('请完整配置签名密钥、区域和服务');
    }
  }

  Map<String, Object?> toJson() => {
    'url': url,
    'method': method,
    'authentication': authentication.name,
    'authHeader': authHeader,
    'authPrefix': authPrefix,
    'apiKey': apiKey,
    'accessKey': accessKey,
    'secretKey': secretKey,
    'region': region,
    'service': service,
    'headers': headers,
    'body': body,
    'listPath': listPath,
    'idPath': idPath,
    'namePath': namePath,
    'avatarPath': avatarPath,
    'previewTextPath': previewTextPath,
    'previewUrlPath': previewUrlPath,
    'genderPath': genderPath,
    'genderValues': genderValues,
    'descriptionPath': descriptionPath,
    'tagPaths': tagPaths,
    'pagePath': pagePath,
    'totalPath': totalPath,
    'pageSize': pageSize,
    'maxPages': maxPages,
  };

  factory SpeechVoiceListConfig.fromJson(Map<String, dynamic> json) =>
      SpeechVoiceListConfig(
        url: json['url'] as String,
        method: json['method'] as String,
        authentication: VoiceListAuthentication.values.byName(
          json['authentication'] as String,
        ),
        authHeader: json['authHeader'] as String,
        authPrefix: json['authPrefix'] as String,
        apiKey: json['apiKey'] as String,
        accessKey: json['accessKey'] as String,
        secretKey: json['secretKey'] as String,
        region: json['region'] as String,
        service: json['service'] as String,
        headers: Map<String, String>.from(json['headers'] as Map),
        body: Map<String, Object?>.from(json['body'] as Map),
        listPath: json['listPath'] as String,
        idPath: json['idPath'] as String,
        namePath: json['namePath'] as String,
        avatarPath: json['avatarPath'] as String?,
        previewTextPath: json['previewTextPath'] as String?,
        previewUrlPath: json['previewUrlPath'] as String?,
        genderPath: json['genderPath'] as String?,
        genderValues: Map<String, String>.from(json['genderValues'] as Map),
        descriptionPath: json['descriptionPath'] as String?,
        tagPaths: List<String>.from(json['tagPaths'] as List),
        pagePath: json['pagePath'] as String,
        totalPath: json['totalPath'] as String,
        pageSize: json['pageSize'] as int,
        maxPages: json['maxPages'] as int,
      );
}
