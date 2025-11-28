class GameLoan {
  final int? id;
  final int gameId;
  final String borrowerName;
  final DateTime loanDate;
  final DateTime? returnDate;
  final DateTime createdAt;

  GameLoan({
    this.id,
    required this.gameId,
    required this.borrowerName,
    required this.loanDate,
    this.returnDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isActive => returnDate == null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'game_id': gameId,
      'borrower_name': borrowerName,
      'loan_date': loanDate.toIso8601String(),
      'return_date': returnDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory GameLoan.fromMap(Map<String, dynamic> map) {
    return GameLoan(
      id: map['id'] as int?,
      gameId: map['game_id'] as int,
      borrowerName: map['borrower_name'] as String,
      loanDate: DateTime.parse(map['loan_date'] as String),
      returnDate: map['return_date'] != null
          ? DateTime.parse(map['return_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  GameLoan copyWith({
    int? id,
    int? gameId,
    String? borrowerName,
    DateTime? loanDate,
    DateTime? returnDate,
    DateTime? createdAt,
    bool clearReturnDate = false,
  }) {
    return GameLoan(
      id: id ?? this.id,
      gameId: gameId ?? this.gameId,
      borrowerName: borrowerName ?? this.borrowerName,
      loanDate: loanDate ?? this.loanDate,
      returnDate: clearReturnDate ? null : (returnDate ?? this.returnDate),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
