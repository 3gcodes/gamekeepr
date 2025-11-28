import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/game.dart';
import '../providers/app_providers.dart';

class LoanGameDialog extends ConsumerStatefulWidget {
  final Game game;

  const LoanGameDialog({
    super.key,
    required this.game,
  });

  @override
  ConsumerState<LoanGameDialog> createState() => _LoanGameDialogState();
}

class _LoanGameDialogState extends ConsumerState<LoanGameDialog> {
  final TextEditingController _borrowerController = TextEditingController();
  DateTime _loanDate = DateTime.now();
  List<String> _allBorrowerNames = [];
  List<String> _filteredBorrowerNames = [];
  bool _showSuggestions = false;
  bool _isLoadingNames = true;

  @override
  void initState() {
    super.initState();
    _loadBorrowerNames();
  }

  Future<void> _loadBorrowerNames() async {
    try {
      final db = ref.read(databaseServiceProvider);
      final names = await db.getAllBorrowerNames();
      if (mounted) {
        setState(() {
          _allBorrowerNames = names;
          _isLoadingNames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingNames = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _borrowerController.dispose();
    super.dispose();
  }

  void _filterBorrowerNames(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredBorrowerNames = [];
        _showSuggestions = false;
      });
    } else {
      setState(() {
        _filteredBorrowerNames = _allBorrowerNames
            .where((name) => name.toLowerCase().contains(query.toLowerCase()))
            .take(5)
            .toList();
        _showSuggestions = _filteredBorrowerNames.isNotEmpty;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _loanDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _loanDate) {
      setState(() {
        _loanDate = picked;
      });
    }
  }

  Future<void> _submitLoan() async {
    final borrowerName = _borrowerController.text.trim();

    if (borrowerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a borrower name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ref.read(loansProvider.notifier).loanGame(
        gameId: widget.game.id!,
        borrowerName: borrowerName,
        loanDate: _loanDate,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.game.name} loaned to $borrowerName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loaning game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return AlertDialog(
      title: Text('Loan ${widget.game.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _borrowerController,
              decoration: InputDecoration(
                labelText: 'Borrower Name',
                hintText: 'Enter borrower name',
                border: const OutlineInputBorder(),
                suffixIcon: _isLoadingNames
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              onChanged: _filterBorrowerNames,
            ),
            if (_showSuggestions && _filteredBorrowerNames.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _filteredBorrowerNames.map((name) {
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      onTap: () {
                        setState(() {
                          _borrowerController.text = name;
                          _showSuggestions = false;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Loan Date',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateFormat.format(_loanDate)),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitLoan,
          child: const Text('Loan Game'),
        ),
      ],
    );
  }
}
