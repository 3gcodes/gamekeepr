import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/location_constants.dart';
import '../providers/app_providers.dart';

/// Screen for writing shelf tags to NFC
class WriteShelfTagScreen extends ConsumerStatefulWidget {
  const WriteShelfTagScreen({super.key});

  @override
  ConsumerState<WriteShelfTagScreen> createState() => _WriteShelfTagScreenState();
}

class _WriteShelfTagScreenState extends ConsumerState<WriteShelfTagScreen> {
  String? _selectedShelf;

  Future<void> _writeShelfTag() async {
    if (_selectedShelf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a shelf first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final nfcService = ref.read(nfcServiceProvider);

    // Show dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Write Shelf Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Hold your device near the NFC tag for Shelf $_selectedShelf'),
            ],
          ),
        ),
      );
    }

    // Small delay to ensure dialog is visible
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final success = await nfcService.writeShelfTag(_selectedShelf!);

      if (mounted) {
        Navigator.pop(context); // Close dialog

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shelf $_selectedShelf tag written successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to write shelf tag'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Shelf Tag'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Create an NFC tag for a shelf',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Select a shelf and scan an NFC tag to write the shelf identifier. '
                      'When you scan this tag later, you\'ll see all games on that shelf.',
                      style: TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Select Shelf',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedShelf,
              decoration: InputDecoration(
                labelText: 'Shelf',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.shelves),
              ),
              items: LocationConstants.shelves.map((shelf) {
                return DropdownMenuItem(
                  value: shelf,
                  child: Text('Shelf $shelf'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedShelf = value;
                });
              },
            ),
            const SizedBox(height: 24),
            if (_selectedShelf != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.shelves, size: 48, color: Colors.green[700]),
                    const SizedBox(height: 12),
                    Text(
                      'Shelf $_selectedShelf',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tag will be written with: SHELF:$_selectedShelf',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _selectedShelf != null ? _writeShelfTag : null,
              icon: const Icon(Icons.nfc),
              label: const Text('Write to NFC Tag'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
