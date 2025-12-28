import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of a barcode lookup
class BarcodeLookupResult {
  final String? productName;
  final bool found;
  final String? errorMessage;

  BarcodeLookupResult({
    this.productName,
    required this.found,
    this.errorMessage,
  });
}

/// Service for looking up product information from barcodes using UPCitemdb.com
class BarcodeService {
  static const String _baseUrl = 'https://api.upcitemdb.com/prod/trial/lookup';

  /// Look up product information by barcode (UPC/EAN)
  /// Returns a BarcodeLookupResult with the product name if found, or error information
  Future<BarcodeLookupResult> lookupBarcode(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl?upc=$barcode');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if we got items back
        if (data['items'] != null && data['items'] is List && (data['items'] as List).isNotEmpty) {
          final item = data['items'][0];
          final title = item['title'] as String?;

          if (title != null && title.isNotEmpty) {
            return BarcodeLookupResult(
              productName: title,
              found: true,
            );
          }
        }

        // 200 but no items - not found
        return BarcodeLookupResult(
          found: false,
          errorMessage: 'Barcode not found in database',
        );
      } else if (response.statusCode == 404) {
        // Product not found
        return BarcodeLookupResult(
          found: false,
          errorMessage: 'Barcode not found in database',
        );
      } else if (response.statusCode == 429) {
        // Rate limited
        return BarcodeLookupResult(
          found: false,
          errorMessage: 'Rate limit exceeded. Please wait a moment and try again.',
        );
      } else {
        print('Barcode lookup failed with status ${response.statusCode}');
        print('Response: ${response.body}');
        return BarcodeLookupResult(
          found: false,
          errorMessage: 'Barcode lookup failed. Please try again.',
        );
      }
    } catch (e) {
      print('Error looking up barcode: $e');
      return BarcodeLookupResult(
        found: false,
        errorMessage: 'Network error. Please check your connection.',
      );
    }
  }
}
