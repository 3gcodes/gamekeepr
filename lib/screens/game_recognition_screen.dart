import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gamekeepr/services/text_recognition_service.dart';
import 'package:gamekeepr/services/game_matching_service.dart';
import 'package:gamekeepr/screens/game_recognition_results_screen.dart';

class GameRecognitionScreen extends StatefulWidget {
  const GameRecognitionScreen({super.key});

  @override
  State<GameRecognitionScreen> createState() => _GameRecognitionScreenState();
}

class _GameRecognitionScreenState extends State<GameRecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextRecognitionService _textRecognitionService = TextRecognitionService();
  final GameMatchingService _gameMatchingService = GameMatchingService();

  File? _selectedImage;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _textRecognitionService.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromCamera() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture image: $e';
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      setState(() {
        _errorMessage = null;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to select image: $e';
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Extract text from image using OCR
      final extractedTexts = await _textRecognitionService.recognizeTextFromImage(
        _selectedImage!.path,
      );

      if (extractedTexts.isEmpty) {
        setState(() {
          _errorMessage = 'No text found in the image. Please try a clearer photo.';
          _isProcessing = false;
        });
        return;
      }

      // Step 2: Match extracted text against game collection
      final matches = await _gameMatchingService.matchGames(
        extractedTexts: extractedTexts,
        minimumConfidence: 0.3,
      );

      // Step 3: Navigate to results screen
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameRecognitionResultsScreen(
              matches: matches,
              extractedTexts: extractedTexts,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to process image: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recognize Games'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Experimental disclaimer
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Experimental Feature: Recognition accuracy may vary',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Instructions
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 8),
                          const Text(
                            'How it works',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Take a photo of your game shelf showing the game spines\n'
                        '2. Make sure the text on the spines is clear and readable\n'
                        '3. The app will identify games from your collection',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Image preview or picker buttons
              Expanded(
                child: _selectedImage == null
                    ? _buildImagePickerButtons()
                    : _buildImagePreview(),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Process button
              if (_selectedImage != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processImage,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isProcessing ? 'Processing...' : 'Find Games'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePickerButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.photo_library,
          size: 80,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isProcessing ? null : _pickImageFromCamera,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Photo'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : _pickImageFromGallery,
          icon: const Icon(Icons.photo),
          label: const Text('Choose from Gallery'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _clearImage,
                icon: const Icon(Icons.close),
                label: const Text('Clear'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : _pickImageFromCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Retake'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
