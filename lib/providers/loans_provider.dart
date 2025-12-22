import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/game_loan.dart';
import '../models/game_with_loan_info.dart';
import 'service_providers.dart';

// Game Loans Provider
final loansProvider = StateNotifierProvider<LoansNotifier, AsyncValue<List<GameWithLoanInfo>>>((ref) {
  return LoansNotifier(ref);
});

class LoansNotifier extends StateNotifier<AsyncValue<List<GameWithLoanInfo>>> {
  final Ref ref;

  LoansNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadActiveLoans();
  }

  Future<void> loadActiveLoans() async {
    state = const AsyncValue.loading();
    try {
      final db = ref.read(databaseServiceProvider);
      final loans = await db.getActiveLoansWithGameInfo();
      state = AsyncValue.data(loans);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<List<GameLoan>> getLoansForGame(int gameId) async {
    final db = ref.read(databaseServiceProvider);
    return await db.getLoansForGame(gameId);
  }

  Future<GameLoan?> getActiveLoanForGame(int gameId) async {
    final db = ref.read(databaseServiceProvider);
    return await db.getActiveLoanForGame(gameId);
  }

  Future<GameLoan> loanGame({
    required int gameId,
    required String borrowerName,
    required DateTime loanDate,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final loan = GameLoan(
      gameId: gameId,
      borrowerName: borrowerName,
      loanDate: loanDate,
    );
    final saved = await db.insertGameLoan(loan);
    await loadActiveLoans();
    return saved;
  }

  Future<void> returnGame(int loanId) async {
    final db = ref.read(databaseServiceProvider);
    await db.returnGame(loanId);
    await loadActiveLoans();
  }

  Future<void> updateLoan(GameLoan loan) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateGameLoan(loan);
    await loadActiveLoans();
  }

  Future<void> deleteLoan(int loanId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteGameLoan(loanId);
    await loadActiveLoans();
  }
}

// Borrower Names Provider (for autocomplete)
final borrowerNamesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(databaseServiceProvider);
  return await db.getAllBorrowerNames();
});
