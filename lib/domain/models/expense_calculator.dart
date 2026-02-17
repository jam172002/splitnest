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

  /// ✅ Single source of truth for balances
  /// Returns net balance for each member:
  /// +ve => credited, -ve => owes
  static Map<String, double> calculateNetByMember({
    required List<GroupTx> txs,
    required List<String> memberUids,
    bool onlyApproved = true,
  }) {
    final net = <String, double>{for (final uid in memberUids) uid: 0.0};

    void add(String uid, double delta) {
      if (uid.trim().isEmpty) return;
      if (!net.containsKey(uid)) return; // ignore unknown users
      net[uid] = (net[uid] ?? 0.0) + delta;
    }

    for (final tx in txs) {
      if (onlyApproved && tx.status.name != 'approved') continue;

      // EXPENSE / BILL
      if (tx.type == 'expense' || tx.type == 'bill_instance') {
        // ✅ payers (multi payer) else legacy paidBy
        if (tx.payers.isNotEmpty) {
          for (final p in tx.payers) {
            add(p.uid, p.amount);
          }
        } else if ((tx.paidBy ?? '').trim().isNotEmpty) {
          add(tx.paidBy!, tx.amount);
        }

        // ✅ participants (if empty, assume all members like dashboard usually does)
        final parts = tx.participants.isNotEmpty ? tx.participants : memberUids;
        if (parts.isNotEmpty) {
          final each = tx.amount / parts.length;
          for (final uid in parts) {
            add(uid, -each);
          }
        }
      }

      // SETTLEMENT
      else if (tx.type == 'settlement') {
        final from = tx.fromUid ?? '';
        final to = tx.toUid ?? '';
        add(from, tx.amount);
        add(to, -tx.amount);
      }

      // INCOME
      else if (tx.type == 'income') {
        if (tx.distributeTo.isNotEmpty) {
          tx.distributeTo.forEach((uid, amt) => add(uid, amt));
        } else if (tx.payers.isNotEmpty) {
          for (final p in tx.payers) {
            add(p.uid, p.amount);
          }
        } else if ((tx.paidBy ?? '').trim().isNotEmpty) {
          add(tx.paidBy!, tx.amount);
        }
      }
    }

    return net;
  }
}