import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Shows a custom-themed date picker dialog aligned with [AppColors].
Future<DateTime?> showThemedDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Select Date',
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _ThemedDatePickerDialog(
      initialDate: initialDate ?? DateTime(2000, 1, 1),
      firstDate: firstDate,
      lastDate: lastDate,
      title: title,
    ),
  );
}

/// Reusable tappable field that displays a formatted date and opens
/// [showThemedDatePicker].
class ThemedDatePickerField extends StatelessWidget {
  const ThemedDatePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.hintText = 'Select date of birth',
    this.dialogTitle = 'Date of Birth',
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final String hintText;
  final String dialogTitle;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        FocusScope.of(context).unfocus();
        final picked = await showThemedDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate,
          lastDate: lastDate,
          title: dialogTitle,
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.cake_outlined,
              color: AppColors.primaryAccent,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value != null ? _format(value!) : hintText,
                style: TextStyle(
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 15,
                ),
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                ),
              )
            else
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.textMuted,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemedDatePickerDialog extends StatefulWidget {
  const _ThemedDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.title,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;

  @override
  State<_ThemedDatePickerDialog> createState() =>
      _ThemedDatePickerDialogState();
}

class _ThemedDatePickerDialogState extends State<_ThemedDatePickerDialog> {
  late DateTime _selected;
  late DateTime _displayedMonth;
  bool _pickingYear = false;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  void initState() {
    super.initState();
    _selected = _clamp(widget.initialDate);
    _displayedMonth = DateTime(_selected.year, _selected.month);
  }

  DateTime _clamp(DateTime d) {
    if (d.isBefore(widget.firstDate)) return widget.firstDate;
    if (d.isAfter(widget.lastDate)) return widget.lastDate;
    return d;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isOutOfRange(DateTime d) {
    final dayOnly = DateTime(d.year, d.month, d.day);
    final minOnly = DateTime(
        widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final maxOnly = DateTime(
        widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return dayOnly.isBefore(minOnly) || dayOnly.isAfter(maxOnly);
  }

  void _stepMonth(int delta) {
    final candidate =
        DateTime(_displayedMonth.year, _displayedMonth.month + delta);
    final minMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final maxMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (candidate.isBefore(minMonth) || candidate.isAfter(maxMonth)) return;
    setState(() => _displayedMonth = candidate);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.inputSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primaryAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_selected.day} ${_monthNames[_selected.month - 1]} ${_selected.year}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _pickingYear = !_pickingYear),
                    icon: Icon(
                      _pickingYear
                          ? Icons.calendar_view_month_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.primaryAccent,
                      size: 18,
                    ),
                    label: Text(
                      _pickingYear ? 'Days' : '${_displayedMonth.year}',
                      style: const TextStyle(
                        color: AppColors.primaryAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white10, height: 20),
              if (_pickingYear) _buildYearGrid() else _buildCalendarGrid(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearGrid() {
    final years = [
      for (int y = widget.lastDate.year; y >= widget.firstDate.year; y--) y
    ];
    return SizedBox(
      height: 250,
      child: GridView.builder(
        itemCount: years.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.3,
        ),
        itemBuilder: (context, index) {
          final year = years[index];
          final active = year == _displayedMonth.year;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              final maxDay = DateUtils.getDaysInMonth(year, _selected.month);
              final next = _clamp(DateTime(
                year,
                _selected.month,
                _selected.day.clamp(1, maxDay),
              ));
              setState(() {
                _selected = next;
                _displayedMonth = DateTime(next.year, next.month);
                _pickingYear = false;
              });
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AppColors.primaryAccent : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$year',
                style: TextStyle(
                  color: active ? AppColors.background : AppColors.textPrimary,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    final firstWeekday =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final leadingBlanks = firstWeekday - 1;
    final totalCells = leadingBlanks + daysInMonth;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _stepMonth(-1),
              icon: const Icon(Icons.chevron_left, color: AppColors.textMuted),
            ),
            Text(
              '${_monthNames[_displayedMonth.month - 1]} ${_displayedMonth.year}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              onPressed: () => _stepMonth(1),
              icon: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: _weekdays
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemBuilder: (context, index) {
            if (index < leadingBlanks) return const SizedBox.shrink();
            final day = index - leadingBlanks + 1;
            final date =
                DateTime(_displayedMonth.year, _displayedMonth.month, day);
            final disabled = _isOutOfRange(date);
            final selected = _isSameDay(date, _selected);

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: disabled ? null : () => setState(() => _selected = date),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      selected ? AppColors.primaryAccent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    color: disabled
                        ? AppColors.textMuted.withValues(alpha: 0.3)
                        : selected
                            ? AppColors.background
                            : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}