import 'package:splitnest/domain/models/tx.dart';

class ExpenseSummary {
  final double totalPaid; // Total money the user physically paid out
  final double totalShare; // Total money the user "consumed" (their share)
  final double netBalance; // TotalPaid - TotalShare

  ExpenseSummary({
    required this.totalPaid,
    required this.totalShare,
    required this.netBalance,
  });
}

class ExpenseCalculator {
  /// Processes a list of group transactions to find a specific member's standing.
  static ExpenseSummary calculateMemberSummary(List<GroupTx> txs, String memberId) {
    double totalPaid = 0;
    double totalShare = 0;

    for (final tx in txs) {
      // 1. Check if the member was the one who paid
      if (tx.paidBy == memberId) {
        totalPaid += tx.amount;
      }

      // 2. Check if the member participated in this expense
      if (tx.participants.contains(memberId)) {
        // Calculate the per-person share (Total / Number of Participants)
        final participantCount = tx.participants.length;
        if (participantCount > 0) {
          totalShare += (tx.amount / participantCount);
        }
      }
    }

    return ExpenseSummary(
      totalPaid: totalPaid,
      totalShare: totalShare,
      netBalance: totalPaid - totalShare,
    );
  }
}