import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextRecognitionService {
  final TextRecognizer _textRecognizer;

  TextRecognitionService()
      : _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts all text from an image file
  /// Returns a list of recognized text strings
  Future<List<String>> recognizeTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      // Extract all text blocks and lines
      final List<String> extractedTexts = [];

      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          final text = line.text.trim();
          if (text.isNotEmpty) {
            extractedTexts.add(text);
          }
        }
      }

      return extractedTexts;
    } catch (e) {
      throw Exception('Failed to recognize text: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    _textRecognizer.close();
  }
}
