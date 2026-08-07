import 'package:flutter/material.dart';

enum PeriodType { week, month }

/// Half-open date range: [start, end).
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

/// Resolves the current week/month range so every screen that needs
/// "this week" / "this month" agrees on the same boundaries.
DateRange rangeForPeriod(PeriodType type, {DateTime? now}) {
  final today = now ?? DateTime.now();
  if (type == PeriodType.week) {
    final startOfDay = DateTime(today.year, today.month, today.day);
    final start = startOfDay.subtract(Duration(days: today.weekday - 1));
    final end = start.add(const Duration(days: 7));
    return DateRange(start, end);
  }
  final start = DateTime(today.year, today.month, 1);
  final end = DateTime(today.year, today.month + 1, 1);
  return DateRange(start, end);
}

/// Segmented Week/Month control. Defaults to the current period and
/// reports the resolved [DateRange] via [onChanged] (including once,
/// immediately after the first frame).
class PeriodSelector extends StatefulWidget {
  final PeriodType initial;
  final ValueChanged<DateRange> onChanged;

  /// Optional: fires alongside [onChanged] with the raw period type,
  /// for callers that need to relabel UI (e.g. "This Week" vs "This Month")
  /// rather than just filter by the resolved date range.
  final ValueChanged<PeriodType>? onTypeChanged;

  const PeriodSelector({
    super.key,
    this.initial = PeriodType.month,
    required this.onChanged,
    this.onTypeChanged,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  late PeriodType _type;

  @override
  void initState() {
    super.initState();
    _type = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onChanged(rangeForPeriod(_type));
      widget.onTypeChanged?.call(_type);
    });
  }

  void _select(PeriodType t) {
    if (t == _type) return;
    setState(() => _type = t);
    widget.onChanged(rangeForPeriod(t));
    widget.onTypeChanged?.call(t);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, 'This Week', PeriodType.week),
          _segment(context, 'This Month', PeriodType.month),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, PeriodType t) {
    final cs = Theme.of(context).colorScheme;
    final selected = _type == t;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _select(t),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
