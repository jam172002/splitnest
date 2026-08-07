import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum PeriodType { week, month }

/// Half-open date range: [start, end).
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange(this.start, this.end);

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);
}

/// Resolves the week/month range containing [now] (defaults to today) so
/// every screen that needs "this week" / "this month" — or an arbitrary
/// past/future week or month, by passing a different anchor — agrees on
/// the same boundaries.
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

bool _isSameWeek(DateTime a, DateTime b) =>
    rangeForPeriod(PeriodType.week, now: a).start ==
    rangeForPeriod(PeriodType.week, now: b).start;

/// Human-readable label for the period of [type] containing [anchor] —
/// "This Week"/"This Month" when it's the current one, otherwise the
/// actual date range/month so users can tell which past or future period
/// they've navigated to.
String periodLabel(PeriodType type, DateTime anchor) {
  final now = DateTime.now();
  if (type == PeriodType.month) {
    if (anchor.year == now.year && anchor.month == now.month) return 'This Month';
    return DateFormat('MMMM yyyy').format(anchor);
  }
  if (_isSameWeek(anchor, now)) return 'This Week';
  final range = rangeForPeriod(PeriodType.week, now: anchor);
  final start = range.start;
  final end = range.end.subtract(const Duration(days: 1));
  final startFmt = DateFormat(start.year == end.year ? 'MMM d' : 'MMM d, yyyy').format(start);
  final endFmt = DateFormat('MMM d, yyyy').format(end);
  return '$startFmt – $endFmt';
}

/// Week/Month period picker: "This Week"/"This Month" stay as one-tap
/// quick options, plus prev/next arrows and a tappable label (opens a date
/// picker) so any past or future week or month can be selected too.
/// Reports the resolved [DateRange] via [onChanged] (including once,
/// immediately after the first frame).
class PeriodSelector extends StatefulWidget {
  final PeriodType initial;
  final ValueChanged<DateRange> onChanged;

  /// Optional: fires alongside [onChanged] with the raw period type.
  final ValueChanged<PeriodType>? onTypeChanged;

  /// Optional: fires alongside [onChanged] with a ready-made label
  /// ("This Week", "Aug 3 – Aug 9, 2026", "This Month", "August 2026", …)
  /// so callers don't have to duplicate the current-period logic.
  final ValueChanged<String>? onLabelChanged;

  const PeriodSelector({
    super.key,
    this.initial = PeriodType.month,
    required this.onChanged,
    this.onTypeChanged,
    this.onLabelChanged,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  late PeriodType _type;
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    _type = widget.initial;
    _anchor = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fire();
    });
  }

  void _fire() {
    widget.onChanged(rangeForPeriod(_type, now: _anchor));
    widget.onTypeChanged?.call(_type);
    widget.onLabelChanged?.call(periodLabel(_type, _anchor));
  }

  // "This Week" / "This Month" quick options: always jump back to the
  // current period of that type.
  void _selectQuick(PeriodType t) {
    setState(() {
      _type = t;
      _anchor = DateTime.now();
    });
    _fire();
  }

  void _shift(int delta) {
    setState(() {
      _anchor = _type == PeriodType.week
          ? _anchor.add(Duration(days: 7 * delta))
          : DateTime(_anchor.year, _anchor.month + delta, 1);
    });
    _fire();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: _type == PeriodType.week ? 'Pick any day in the week' : 'Pick any day in the month',
    );
    if (picked == null) return;
    setState(() => _anchor = picked);
    _fire();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segment(context, 'This Week', PeriodType.week),
              _segment(context, 'This Month', PeriodType.month),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
              Flexible(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Text(
                      periodLabel(_type, _anchor),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, String label, PeriodType t) {
    final cs = Theme.of(context).colorScheme;
    final selected = _type == t;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _selectQuick(t),
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
