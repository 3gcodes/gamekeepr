import 'game.dart';
import 'game_loan.dart';

class GameWithLoanInfo {
  final Game game;
  final GameLoan? activeLoan;

  GameWithLoanInfo({
    required this.game,
    this.activeLoan,
  });

  bool get isLoaned => activeLoan != null;
}
