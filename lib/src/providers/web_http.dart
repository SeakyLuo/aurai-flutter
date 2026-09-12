import 'dart:async';
import 'dart:io';

class WebRequestException implements Exception {
  const WebRequestException(this.message);
  final String message;
}

typedef WebResponse = ({Uri url, List<int> bytes, String mimeType});

Uri publicWebUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const WebRequestException('请提供完整的 HTTPS 网页链接');
  }
  return uri;
}

class WebHttp {
  HttpClient? _client;
  bool _cancelled = false;

  Future<WebResponse> get(Uri url) async {
    _cancelled = false;
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'Aurai/1.0';
    _client = client;
    try {
      return await _get(client, url).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const WebRequestException('网页请求超时，请稍后重试');
    } on HandshakeException {
      throw const WebRequestException('网站安全连接失败');
    } on SocketException {
      if (_cancelled) throw const WebRequestException('请求已取消');
      throw const WebRequestException('无法连接网站，请检查网络');
    } on HttpException {
      if (_cancelled) throw const WebRequestException('请求已取消');
      throw const WebRequestException('网页连接中断');
    } finally {
      client.close(force: true);
      _client = null;
    }
  }

  Future<WebResponse> _get(HttpClient client, Uri url) async {
    for (var redirects = 0; redirects <= 5; redirects++) {
      final request = await client.getUrl(url);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'text/html, text/plain');
      final response = await request.close();
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) {
          throw const WebRequestException('网站重定向缺少目标地址');
        }
        url = publicWebUri(url.resolve(location).toString());
        continue;
      }
      if (response.statusCode != 200) {
        throw WebRequestException(switch (response.statusCode) {
          401 || 403 => '网站要求登录或验证，无法直接读取',
          429 => '网站请求过于频繁，请稍后再试',
          _ => '网站返回错误（${response.statusCode}）',
        });
      }
      final mimeType = response.headers.contentType?.mimeType ?? '';
      if (!{
        'text/html',
        'application/xhtml+xml',
        'text/plain',
      }.contains(mimeType)) {
        throw const WebRequestException('目前只支持 HTML 网页和纯文本，不支持 PDF 或其他文件');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const WebRequestException('网页内容超过 2MB，请换用更具体的页面');
        }
        bytes.addAll(chunk);
      }
      return (url: url, bytes: bytes, mimeType: mimeType);
    }
    throw const WebRequestException('网站重定向次数过多');
  }

  bool get cancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
  }
}
