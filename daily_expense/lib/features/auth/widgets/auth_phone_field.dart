import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';
import '../country.dart';
import 'auth_scale.dart';
import 'country_picker_sheet.dart';

/// Mobile number field with a tappable country-code selector on the left.
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final Country country;
  final ValueChanged<Country> onCountryChanged;
  final bool enabled;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  Future<void> _pickCountry(BuildContext context) async {
    final picked = await showCountryPicker(context, selected: country);
    if (picked == null) return;

    // Trim the number if the new country allows fewer digits.
    final max = picked.maxPhoneDigits;
    if (controller.text.length > max) {
      final text = controller.text.substring(0, max);
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    onCountryChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final sc = AuthScale.of(context);

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(country.maxPhoneDigits),
      ],
      style: TextStyle(
        fontSize: sc.size(18, min: 16),
        letterSpacing: 1.5,
        color: AppColors.textPrimary,
      ),
      cursorColor: AppColors.primaryAccent,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: country.iso == 'IN' ? '98765 43210' : 'Mobile number',
        hintStyle: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.5),
          letterSpacing: 1.5,
        ),
        filled: true,
        fillColor: AppColors.inputSurface,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: sc.size(18, min: 13),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: enabled ? () => _pickCountry(context) : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(country.flag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(
                        country.dialCode,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
        enabledBorder: border(Colors.white.withValues(alpha: 0.05)),
        disabledBorder: border(Colors.white.withValues(alpha: 0.05)),
        focusedBorder: border(AppColors.primaryAccent, 1.5),
      ),
    );
  }
}
