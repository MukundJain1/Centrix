import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../country.dart';

/// Opens a searchable country list. Returns the chosen country, or null.
Future<Country?> showCountryPicker(
  BuildContext context, {
  required Country selected,
}) {
  FocusScope.of(context).unfocus();
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.inputSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CountrySheet(selected: selected),
  );
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected});

  final Country selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  final _search = TextEditingController();
  List<Country> _results = Country.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String input) {
    final q = input.trim().toLowerCase().replaceAll('+', '');
    setState(() {
      _results = q.isEmpty
          ? Country.all
          : Country.all.where((c) {
              return c.name.toLowerCase().contains(q) ||
                  c.iso.toLowerCase() == q ||
                  c.dialCode.replaceAll('+', '').startsWith(q);
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Shrink the sheet when the keyboard is open so the list stays visible.
    final available = mq.size.height - mq.viewInsets.bottom;
    final height = math.min(mq.size.height * 0.75, available * 0.9);

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Select country',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: _filter,
                cursorColor: AppColors.primaryAccent,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primaryAccent,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? const Center(
                      child: Text(
                        'No country found',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _results.length,
                      itemBuilder: (context, i) {
                        final c = _results[i];
                        final isSelected = c.iso == widget.selected.iso;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor:
                              AppColors.primaryAccent.withValues(alpha: 0.12),
                          leading: Text(
                            c.flag,
                            style: const TextStyle(fontSize: 24),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          trailing: Text(
                            c.dialCode,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primaryAccent
                                  : AppColors.textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
