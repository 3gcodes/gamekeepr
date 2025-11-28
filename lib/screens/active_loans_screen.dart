import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/game_with_loan_info.dart';
import '../providers/app_providers.dart';
import 'game_details_screen.dart';

class ActiveLoansScreen extends ConsumerWidget {
  const ActiveLoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loaned Games'),
      ),
      body: loansAsync.when(
        data: (loans) {
          if (loans.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.handshake_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No games currently loaned',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: loans.length,
            itemBuilder: (context, index) {
              final loanInfo = loans[index];
              return _LoanListItem(
                loanInfo: loanInfo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameDetailsScreen(game: loanInfo.game),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading loans: $error'),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoanListItem extends ConsumerWidget {
  final GameWithLoanInfo loanInfo;
  final VoidCallback onTap;

  const _LoanListItem({
    required this.loanInfo,
    required this.onTap,
  });

  Future<void> _returnGame(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Game'),
        content: Text(
          'Mark "${loanInfo.game.name}" as returned from ${loanInfo.activeLoan!.borrowerName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Return'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(loansProvider.notifier).returnGame(loanInfo.activeLoan!.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loanInfo.game.name} marked as returned'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error returning game: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loan = loanInfo.activeLoan!;
    final game = loanInfo.game;
    final dateFormat = DateFormat('MMM d, yyyy');
    final now = DateTime.now();
    final daysLoaned = now.difference(loan.loanDate).inDays;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: game.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: game.thumbnailUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.games),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.games),
                        ),
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[300],
                        child: const Icon(Icons.games),
                      ),
              ),
              const SizedBox(width: 12),
              // Game and loan info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          loan.borrowerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(loan.loanDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($daysLoaned ${daysLoaned == 1 ? 'day' : 'days'})',
                          style: TextStyle(
                            fontSize: 12,
                            color: daysLoaned > 30 ? Colors.orange : Colors.grey[600],
                            fontWeight: daysLoaned > 30 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Return button
              IconButton(
                icon: const Icon(Icons.assignment_return),
                color: Colors.green,
                tooltip: 'Mark as returned',
                onPressed: () => _returnGame(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
