class MemberBalance {
  final String memberId;
  final String name;
  final double netBalance;        // positive = group owes this member, negative = member owes group

  MemberBalance({
    required this.memberId,
    required this.name,
    required this.netBalance,
  });

  // Helper to show nice text in UI
  String get balanceDisplay {
    if (netBalance == 0) return 'settled';
    if (netBalance > 0) return 'gets back ${netBalance.toStringAsFixed(2)}';
    return 'owes ${(-netBalance).toStringAsFixed(2)}';
  }

  // Optional: color suggestion for UI
  bool get isPositive => netBalance > 0;
  bool get isNegative => netBalance < 0;
  bool get isSettled => netBalance == 0;
}