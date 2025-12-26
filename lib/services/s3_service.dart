import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class S3Service {
  final String bucketName;
  final String region;
  final String accessKey;
  final String secretKey;

  S3Service({
    required this.bucketName,
    required this.region,
    required this.accessKey,
    required this.secretKey,
  });

  /// Upload a file to S3 and return the S3 key
  Future<String> uploadFile(File file, String s3Key) async {
    final bytes = await file.readAsBytes();
    final timestamp = DateTime.now().toUtc();
    final dateStamp = _formatDateStamp(timestamp);
    final amzDate = _formatAmzDate(timestamp);

    final host = '$bucketName.s3.$region.amazonaws.com';
    final url = Uri.parse('https://$host/$s3Key');

    // Determine content type based on file extension
    final contentType = _getContentType(file.path);

    final headers = {
      'Host': host,
      'Content-Type': contentType,
      'x-amz-content-sha256': _hashPayload(bytes),
      'x-amz-date': amzDate,
    };

    // Create canonical request
    final canonicalRequest = _createCanonicalRequest(
      'PUT',
      '/$s3Key',
      '',
      headers,
      bytes,
    );

    // Create string to sign
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final stringToSign = _createStringToSign(
      amzDate,
      credentialScope,
      canonicalRequest,
    );

    // Calculate signature
    final signature = _calculateSignature(
      secretKey,
      dateStamp,
      region,
      stringToSign,
    );

    // Create authorization header
    final authorization = 'AWS4-HMAC-SHA256 Credential=$accessKey/$credentialScope, '
        'SignedHeaders=${_getSignedHeaders(headers)}, '
        'Signature=$signature';

    headers['Authorization'] = authorization;

    // Make the request
    final response = await http.put(
      url,
      headers: headers,
      body: bytes,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to upload to S3: ${response.statusCode} - ${response.body}');
    }

    return s3Key;
  }

  /// Generate a signed URL for accessing a private S3 object
  /// The URL will be valid for the specified duration (default: 7 days)
  String generateSignedUrl(String s3Key, {Duration validity = const Duration(days: 7)}) {
    final timestamp = DateTime.now().toUtc();
    final dateStamp = _formatDateStamp(timestamp);
    final amzDate = _formatAmzDate(timestamp);
    final expiresIn = validity.inSeconds;

    final host = '$bucketName.s3.$region.amazonaws.com';
    final credentialScope = '$dateStamp/$region/s3/aws4_request';
    final credential = '$accessKey/$credentialScope';

    // Build canonical query string
    final queryParams = {
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': credential,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expiresIn.toString(),
      'X-Amz-SignedHeaders': 'host',
    };

    final sortedKeys = queryParams.keys.toList()..sort();
    final canonicalQueryString = sortedKeys
        .map((key) => '${Uri.encodeComponent(key)}=${Uri.encodeComponent(queryParams[key]!)}')
        .join('&');

    // Create canonical request for presigned URL
    final canonicalRequest = [
      'GET',
      '/$s3Key',
      canonicalQueryString,
      'host:$host',
      '',
      'host',
      'UNSIGNED-PAYLOAD',
    ].join('\n');

    // Create string to sign
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hashString(canonicalRequest),
    ].join('\n');

    // Calculate signature
    final signature = _calculateSignature(
      secretKey,
      dateStamp,
      region,
      stringToSign,
    );

    // Build final URL
    return 'https://$host/$s3Key?$canonicalQueryString&X-Amz-Signature=$signature';
  }

  // Helper methods for AWS Signature V4 signing

  String _formatDateStamp(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatAmzDate(DateTime dt) {
    final date = _formatDateStamp(dt);
    final time = '${dt.hour.toString().padLeft(2, '0')}'
        '${dt.minute.toString().padLeft(2, '0')}'
        '${dt.second.toString().padLeft(2, '0')}';
    return '${date}T${time}Z';
  }

  String _hashPayload(List<int> payload) {
    return sha256.convert(payload).toString();
  }

  String _hashString(String str) {
    return sha256.convert(utf8.encode(str)).toString();
  }

  String _createCanonicalRequest(
    String method,
    String uri,
    String queryString,
    Map<String, String> headers,
    List<int> payload,
  ) {
    final sortedHeaders = headers.keys.toList()..sort();
    final canonicalHeaders = sortedHeaders
        .map((key) => '${key.toLowerCase()}:${headers[key]!.trim()}')
        .join('\n');
    final signedHeaders = sortedHeaders.map((key) => key.toLowerCase()).join(';');

    return [
      method,
      uri,
      queryString,
      canonicalHeaders,
      '',
      signedHeaders,
      _hashPayload(payload),
    ].join('\n');
  }

  String _createStringToSign(String amzDate, String credentialScope, String canonicalRequest) {
    return [
      'AWS4-HMAC-SHA256',
      amzDate,
      credentialScope,
      _hashString(canonicalRequest),
    ].join('\n');
  }

  String _calculateSignature(
    String secretKey,
    String dateStamp,
    String region,
    String stringToSign,
  ) {
    final kDate = _hmacSha256(utf8.encode('AWS4$secretKey'), utf8.encode(dateStamp));
    final kRegion = _hmacSha256(kDate, utf8.encode(region));
    final kService = _hmacSha256(kRegion, utf8.encode('s3'));
    final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
    final signature = _hmacSha256(kSigning, utf8.encode(stringToSign));

    return signature.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

  String _getSignedHeaders(Map<String, String> headers) {
    final sortedKeys = headers.keys.toList()..sort();
    return sortedKeys.map((key) => key.toLowerCase()).join(';');
  }

  String _getContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  /// Check if a path is an S3 key (starts with s3://)
  static bool isS3Path(String path) {
    return path.startsWith('s3://');
  }

  /// Extract S3 key from s3:// path
  static String extractS3Key(String s3Path) {
    if (!isS3Path(s3Path)) {
      throw ArgumentError('Not an S3 path: $s3Path');
    }
    return s3Path.substring(5); // Remove "s3://"
  }

  /// Create an S3 path from a key
  static String createS3Path(String key) {
    return 's3://$key';
  }
}
