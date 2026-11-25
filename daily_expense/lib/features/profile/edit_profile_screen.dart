import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/app_snackbar.dart';
import '../../core/widgets/themed_date_picker.dart';
import '../auth/data/auth_models.dart';
import '../auth/data/auth_repository.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _occupationController = TextEditingController();

  DateTime? _dob;
  String? _selectedGender;
  String? _ageError;
  bool _loading = false;
  bool _saving = false;

  static const _genders = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  static const _occupations = [
    'Student',
    'Salaried',
    'Freelancer',
    'Business',
    'Homemaker',
  ];

  @override
  void initState() {
    super.initState();
    final cached = AuthRepository.instance.currentUser.value;
    if (cached != null) {
      _applyUser(cached);
    } else {
      _fetchProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  void _applyUser(MeModel user) {
    _nameController.text = user.fullName ?? '';
    _ageController.text = user.age != null ? '${user.age}' : '';
    _dob = user.dateOfBirth;
    _selectedGender = user.gender;
    _occupationController.text = user.occupation ?? '';
  }

  Future<void> _fetchProfile() async {
    setState(() => _loading = true);
    try {
      final user = await AuthRepository.instance.me();
      if (!mounted) return;
      setState(() {
        _applyUser(user);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.error(context, 'Could not load profile details.');
    }
  }

  String? _validateAge(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 3) return 'Please enter a valid age';
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 1 || parsed > 999) {
      return 'Please enter a valid age';
    }
    return null;
  }

  void _onAgeChanged(String value) {
    setState(() => _ageError = _validateAge(value));
  }

  void _onDobChanged(DateTime? picked) {
    setState(() {
      _dob = picked;
      if (picked != null && _ageController.text.trim().isEmpty) {
        final now = DateTime.now();
        int years = now.year - picked.year;
        if (now.month < picked.month ||
            (now.month == picked.month && now.day < picked.day)) {
          years--;
        }
        if (years >= 1 && years <= 999) {
          _ageController.text = '$years';
          _ageError = null;
        }
      }
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final ageValidation = _validateAge(_ageController.text);
    if (ageValidation != null) {
      setState(() => _ageError = ageValidation);
      return;
    }

    setState(() => _saving = true);
    final rawAge = _ageController.text.trim();
    final parsedAge = rawAge.isEmpty ? null : int.parse(rawAge);

    try {
      await AuthRepository.instance.updateProfile(
        fullName: _nameController.text.trim(),
        age: parsedAge,
        dateOfBirth: _dob,
        gender: _selectedGender,
        occupation: _occupationController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, 'Could not save profile. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryAccent),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            )
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: ListView(
                          padding: EdgeInsets.symmetric(
                            horizontal: hPad,
                            vertical: 12,
                          ),
                          children: [
                            const Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Personalize your account details. All fields are optional.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _buildLabel('FULL NAME'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _nameController,
                              hint: 'Enter your name',
                              icon: Icons.person_outline_rounded,
                              capitalization: TextCapitalization.words,
                              maxLength: 80,
                            ),
                            const SizedBox(height: 20),
                            _buildLabel('AGE'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _ageController,
                              hint: 'Enter your age',
                              icon: Icons.tag_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: _onAgeChanged,
                              hasError: _ageError != null,
                            ),
                            if (_ageError != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _ageError!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 20),
                            _buildLabel('DATE OF BIRTH'),
                            const SizedBox(height: 8),
                            ThemedDatePickerField(
                              value: _dob,
                              onChanged: _onDobChanged,
                              firstDate: DateTime(1920, 1, 1),
                              lastDate: DateTime.now(),
                            ),
                            const SizedBox(height: 20),
                            _buildLabel('GENDER'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _genders.map((g) {
                                final selected = _selectedGender == g;
                                return ChoiceChip(
                                  label: Text(g),
                                  selected: selected,
                                  onSelected: (val) => setState(
                                    () => _selectedGender = val ? g : null,
                                  ),
                                  backgroundColor: AppColors.inputSurface,
                                  selectedColor: AppColors.primaryAccent,
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? AppColors.background
                                        : AppColors.textPrimary,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  side: BorderSide(
                                    color: selected
                                        ? AppColors.primaryAccent
                                        : Colors.white.withValues(alpha: 0.08),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            _buildLabel('OCCUPATION'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _occupationController,
                              hint: 'e.g. Software Engineer, Student',
                              icon: Icons.work_outline_rounded,
                              capitalization: TextCapitalization.words,
                              maxLength: 60,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _occupations.map((occ) {
                                final selected = _occupationController.text
                                        .trim()
                                        .toLowerCase() ==
                                    occ.toLowerCase();
                                return ActionChip(
                                  label: Text(
                                    occ,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selected
                                          ? AppColors.background
                                          : AppColors.textMuted,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  backgroundColor: selected
                                      ? AppColors.primaryAccent
                                      : AppColors.inputSurface,
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                  onPressed: () => setState(
                                    () => _occupationController.text = occ,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 28),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed:
                              (_saving || _ageError != null) ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            foregroundColor: AppColors.background,
                            disabledBackgroundColor:
                                AppColors.primaryAccent.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.background,
                                  ),
                                )
                              : const Text(
                                  'Save Profile',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    ValueChanged<String>? onChanged,
    bool hasError = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.inputSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasError
              ? Colors.redAccent
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        onChanged: onChanged,
        cursorColor: AppColors.primaryAccent,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          counterText: '',
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: Icon(
            icon,
            color: hasError ? Colors.redAccent : AppColors.primaryAccent,
            size: 20,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
      ),
    );
  }
}