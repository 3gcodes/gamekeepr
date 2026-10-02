import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

// Reset all collection filters to their defaults
void resetCollectionFilters(WidgetRef ref) {
  ref.read(maxPlayersFilterProvider.notifier).state = null;
  ref.read(categoryFilterProvider.notifier).state = const {};
  ref.read(mechanicFilterProvider.notifier).state = const {};
}

class FilterBottomSheet extends ConsumerWidget {
  const FilterBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxPlayersFilter = ref.watch(maxPlayersFilterProvider);
    final categoryFilter = ref.watch(categoryFilterProvider);
    final mechanicFilter = ref.watch(mechanicFilterProvider);
    final categories = ref.watch(collectionCategoriesProvider);
    final mechanics = ref.watch(collectionMechanicsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () {
                    // Reset all filters to default
                    resetCollectionFilters(ref);
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Max Players Filter Section
            Text(
              'Max Players',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: maxPlayersFilter == null,
                  onSelected: (_) {
                    ref.read(maxPlayersFilterProvider.notifier).state = null;
                  },
                ),
                for (final count in maxPlayersFilterOptions)
                  ChoiceChip(
                    label: Text(
                      count == maxPlayersFilterOptions.last ? '$count+' : '$count',
                    ),
                    selected: maxPlayersFilter == count,
                    onSelected: (_) {
                      ref.read(maxPlayersFilterProvider.notifier).state = count;
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Category and Mechanic Filter Section (games match any selection)
            _FilterPickerField(
              label: 'Categories',
              selected: categoryFilter,
              options: categories,
              onChanged: (value) {
                ref.read(categoryFilterProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 12),

            _FilterPickerField(
              label: 'Mechanics',
              selected: mechanicFilter,
              options: mechanics,
              onChanged: (value) {
                ref.read(mechanicFilterProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 24),

            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Apply Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPickerField extends StatelessWidget {
  final String label;
  final Set<String> selected;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;

  const _FilterPickerField({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sortedSelection = selected.toList()..sort();

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _FilterPickerSheet(
            label: label,
            selected: selected,
            options: options,
            onChanged: onChanged,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          selected.isEmpty ? 'Any' : sortedSelection.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _FilterPickerSheet extends StatefulWidget {
  final String label;
  final Set<String> selected;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;

  const _FilterPickerSheet({
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_FilterPickerSheet> createState() => _FilterPickerSheetState();
}

class _FilterPickerSheetState extends State<_FilterPickerSheet> {
  late Set<String> _selected = widget.selected;
  String _query = '';

  void _updateSelection(Set<String> selection) {
    setState(() {
      _selected = selection;
    });
    widget.onChanged(selection);
  }

  @override
  Widget build(BuildContext context) {
    final lowerQuery = _query.toLowerCase();
    final matches = widget.options
        .where((option) => option.toLowerCase().contains(lowerQuery))
        .toList();

    return SafeArea(
      child: Padding(
        // Keep the list above the keyboard
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    if (_selected.isNotEmpty)
                      TextButton(
                        onPressed: () => _updateSelection(const {}),
                        child: const Text('Clear'),
                      ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: TextField(
                  textInputAction: TextInputAction.done,
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final option = matches[index];
                    return CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      title: Text(option),
                      value: _selected.contains(option),
                      onChanged: (checked) {
                        _updateSelection(
                          checked == true
                              ? {..._selected, option}
                              : _selected.difference({option}),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
