import 'dart:convert';
import 'package:crypto/crypto.dart';

class ApiAuthService {
  static const String _apiKey = 'Hshha8123+1JjasNMXOPS'; // TODO: 从配置文件或环境变量获取
  
  /// 生成 API 请求所需的认证头
  /// 
  /// [path] - API 请求路径，例如 '/api/calendars/123'
  /// 返回包含认证信息的请求头
  static Map<String, String> generateAuthHeaders(String path) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final signature = _generateSignature(path, timestamp);
    
    return {
      'X-Timestamp': timestamp,
      'X-Sign': signature,
      'Content-Type': 'application/json',
    };
  }
  
  /// 生成签名
  /// 
  /// [path] - API 请求路径
  /// [timestamp] - 时间戳
  static String _generateSignature(String path, String timestamp) {
    final data = path + timestamp + _apiKey;
    final bytes = utf8.encode(data);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
} 