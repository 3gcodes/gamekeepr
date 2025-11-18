import 'package:flutter/material.dart';
import '../constants/location_constants.dart';

/// A widget for picking a game location with shelf and bay dropdowns
class LocationPicker extends StatefulWidget {
  final String? initialLocation;
  final Function(String?) onLocationChanged;

  const LocationPicker({
    super.key,
    this.initialLocation,
    required this.onLocationChanged,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  String? _selectedShelf;
  int? _selectedBay;

  @override
  void initState() {
    super.initState();
    _parseInitialLocation();
  }

  void _parseInitialLocation() {
    if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      final parts = LocationConstants.parseLocation(widget.initialLocation!);
      if (parts != null) {
        _selectedShelf = parts.shelf;
        _selectedBay = parts.bay;
      }
    }
  }

  void _updateLocation() {
    if (_selectedShelf != null && _selectedBay != null) {
      widget.onLocationChanged(
        LocationConstants.formatLocation(_selectedShelf!, _selectedBay!),
      );
    } else {
      widget.onLocationChanged(null);
    }
  }

  void _clearLocation() {
    setState(() {
      _selectedShelf = null;
      _selectedBay = null;
    });
    widget.onLocationChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (_selectedShelf != null || _selectedBay != null)
                  TextButton.icon(
                    onPressed: _clearLocation,
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Shelf dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedShelf,
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
                      _updateLocation();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Bay dropdown
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedBay,
                    decoration: InputDecoration(
                      labelText: 'Bay',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.grid_view),
                    ),
                    items: LocationConstants.bays.map((bay) {
                      return DropdownMenuItem(
                        value: bay,
                        child: Text('Bay $bay'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBay = value;
                      });
                      _updateLocation();
                    },
                  ),
                ),
              ],
            ),
            if (_selectedShelf != null && _selectedBay != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Location: $_selectedShelf$_selectedBay',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
