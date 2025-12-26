import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/collectible.dart';
import '../providers/collectibles_provider.dart';
import '../providers/games_provider.dart';
import '../providers/settings_providers.dart';
import '../services/s3_service.dart';

class AddCollectibleScreen extends ConsumerStatefulWidget {
  final Collectible? collectible; // If provided, we're editing
  final int? preselectedGameId; // If provided, pre-select this game

  const AddCollectibleScreen({
    super.key,
    this.collectible,
    this.preselectedGameId,
  });

  @override
  ConsumerState<AddCollectibleScreen> createState() => _AddCollectibleScreenState();
}

class _AddCollectibleScreenState extends ConsumerState<AddCollectibleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  CollectibleType _selectedType = CollectibleType.MINIATURE;
  int? _selectedGameId;
  bool _painted = false;
  bool _isLoading = false;
  final List<File?> _selectedImages = [null, null, null]; // Max 3 images
  final List<String?> _imageUrls = [null, null, null]; // Existing image URLs
  int _coverImageIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.collectible != null) {
      // Editing mode
      final c = widget.collectible!;
      _nameController.text = c.name;
      _manufacturerController.text = c.manufacturer ?? '';
      _descriptionController.text = c.description ?? '';
      _quantityController.text = c.quantity.toString();
      _selectedType = c.type;
      _selectedGameId = c.gameId;
      _painted = c.painted;
      _coverImageIndex = c.coverImageIndex;
      // Load existing images
      for (int i = 0; i < c.images.length && i < 3; i++) {
        _imageUrls[i] = c.images[i];
      }
    } else {
      // Adding mode
      _quantityController.text = '1';
      if (widget.preselectedGameId != null) {
        _selectedGameId = widget.preselectedGameId;
      }
    }
  }

  Future<void> _pickImage(ImageSource source, int index) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _selectedImages[index] = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<String?> _saveImage(File imageFile) async {
    try {
      // Check if S3 is enabled
      final s3Service = await ref.read(s3ServiceProvider.future);

      if (s3Service != null) {
        // Upload to S3
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'collectible_$timestamp${path.extension(imageFile.path)}';
        final s3Key = 'collectibles/$fileName';

        await s3Service.uploadFile(imageFile, s3Key);
        return S3Service.createS3Path(s3Key);
      } else {
        // Save locally (default behavior)
        final appDir = await getApplicationDocumentsDirectory();
        final collectiblesDir = Directory('${appDir.path}/collectibles');
        if (!await collectiblesDir.exists()) {
          await collectiblesDir.create(recursive: true);
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'collectible_$timestamp${path.extension(imageFile.path)}';
        final savedImage = await imageFile.copy('${collectiblesDir.path}/$fileName');

        return savedImage.path;
      }
    } catch (e) {
      print('Error saving image: $e');
      return null;
    }
  }

  void _showImageSourceDialog(int index) {
    final hasImage = _selectedImages[index] != null || _imageUrls[index] != null;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, index);
              },
            ),
            if (hasImage)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImages[index] = null;
                    _imageUrls[index] = null;
                    // If we removed the cover image, set cover to first available image
                    if (_coverImageIndex == index) {
                      _coverImageIndex = _findFirstImageIndex();
                    }
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  int _findFirstImageIndex() {
    for (int i = 0; i < 3; i++) {
      if (_selectedImages[i] != null || _imageUrls[i] != null) {
        return i;
      }
    }
    return 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _manufacturerController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Save all images
      final List<String> finalImages = [];
      for (int i = 0; i < 3; i++) {
        if (_selectedImages[i] != null) {
          // New image selected, save it (to S3 or locally depending on settings)
          final savedPath = await _saveImage(_selectedImages[i]!);
          if (savedPath != null) {
            finalImages.add(savedPath);
          }
        } else if (_imageUrls[i] != null) {
          // Existing image, keep it
          finalImages.add(_imageUrls[i]!);
        }
      }

      // Adjust cover image index if necessary
      int adjustedCoverIndex = _coverImageIndex;
      if (adjustedCoverIndex >= finalImages.length) {
        adjustedCoverIndex = finalImages.isNotEmpty ? 0 : 0;
      }

      final collectible = Collectible(
        id: widget.collectible?.id,
        type: _selectedType,
        name: _nameController.text.trim(),
        manufacturer: _manufacturerController.text.trim().isEmpty ? null : _manufacturerController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        quantity: int.tryParse(_quantityController.text) ?? 1,
        painted: _painted,
        gameId: _selectedGameId,
        location: widget.collectible?.location,
        hasNfcTag: widget.collectible?.hasNfcTag ?? false,
        images: finalImages,
        coverImageIndex: adjustedCoverIndex,
        createdAt: widget.collectible?.createdAt,
      );

      if (widget.collectible == null) {
        // Adding new collectible
        await ref.read(collectiblesProvider.notifier).addCollectible(collectible);
      } else {
        // Updating existing collectible
        await ref.read(collectiblesProvider.notifier).updateCollectible(collectible);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.collectible == null
                ? 'Collectible added successfully'
                : 'Collectible updated successfully'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gamesAsync = ref.watch(gamesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collectible == null ? 'Add Collectible' : 'Edit Collectible'),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Multiple Image Picker (max 3)
            const Text(
              'Photos (max 3)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap star to set cover photo',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (index) {
                final hasImage = _selectedImages[index] != null || _imageUrls[index] != null;
                final isCover = _coverImageIndex == index && hasImage;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => _showImageSourceDialog(index),
                          child: Stack(
                            children: [
                              Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isCover ? Colors.amber : Colors.grey[400]!,
                                    width: isCover ? 3 : 1,
                                  ),
                                ),
                                child: _selectedImages[index] != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          _selectedImages[index]!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      )
                                    : _imageUrls[index] != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.file(
                                              File(_imageUrls[index]!),
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Center(
                                                  child: Icon(
                                                    Icons.add_photo_alternate,
                                                    size: 32,
                                                    color: Colors.grey[600],
                                                  ),
                                                );
                                              },
                                            ),
                                          )
                                        : Center(
                                            child: Icon(
                                              Icons.add_photo_alternate,
                                              size: 32,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                              ),
                              if (isCover)
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.star,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hasImage)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _coverImageIndex = index;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isCover ? Icons.star : Icons.star_border,
                                  size: 16,
                                  color: isCover ? Colors.amber : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isCover ? 'Cover' : 'Set cover',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isCover ? Colors.amber : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Type Selector
            DropdownButtonFormField<CollectibleType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type *',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: CollectibleType.MINIATURE,
                  child: Text(CollectibleType.MINIATURE.displayName),
                ),
                // Future types can be added here
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Manufacturer
            TextFormField(
              controller: _manufacturerController,
              decoration: const InputDecoration(
                labelText: 'Manufacturer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Quantity
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Quantity is required';
                }
                final qty = int.tryParse(value);
                if (qty == null || qty < 1) {
                  return 'Quantity must be at least 1';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Painted (for miniatures only)
            if (_selectedType == CollectibleType.MINIATURE)
              SwitchListTile(
                value: _painted,
                onChanged: (value) {
                  setState(() {
                    _painted = value;
                  });
                },
                title: const Text('Painted'),
                contentPadding: EdgeInsets.zero,
              ),

            const SizedBox(height: 16),

            // Associated Game
            gamesAsync.when(
              data: (games) {
                final ownedGames = games.where((g) => g.owned).toList();
                return DropdownButtonFormField<int?>(
                  value: _selectedGameId,
                  decoration: const InputDecoration(
                    labelText: 'Associated Game (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ...ownedGames.map((game) {
                      return DropdownMenuItem<int?>(
                        value: game.id,
                        child: Text(
                          game.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGameId = value;
                    });
                  },
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error loading games: $error'),
            ),

            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(widget.collectible == null ? 'Add Collectible' : 'Update Collectible'),
            ),
          ],
        ),
      ),
    );
  }
}
