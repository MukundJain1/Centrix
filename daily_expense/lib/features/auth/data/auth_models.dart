/// What the server tells us about the signed-in user (GET / PUT /v1/auth/me).
class MeModel {
  const MeModel({
    required this.id,
    required this.phone,
    required this.countryIso,
    this.fullName,
    this.age,
    this.dateOfBirth,
    this.gender,
    this.occupation,
    required this.currency,
    required this.monthlySurplus,
    required this.dailyLimit,
    required this.payday,
    required this.baselineDone,
    required this.cycleDone,
  });

  final String id;
  final String phone;
  final String countryIso;
  final String? fullName;
  final int? age;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? occupation;
  final String currency;
  final double? monthlySurplus;
  final double? dailyLimit;
  final int? payday;

  /// Setup steps. Decide where to send the user after sign in:
  /// baseline not done -> Financial Baseline, then cycle, then Dashboard.
  final bool baselineDone;
  final bool cycleDone;

  String get displayName {
    final name = fullName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Complete your profile';
  }

  String get initials {
    final name = fullName?.trim() ?? '';
    if (name.isEmpty) return 'U';
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String get maskedPhone {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return phone;
    return '******${digits.substring(digits.length - 4)}';
  }

  factory MeModel.fromJson(Map<String, dynamic> json) {
    final onboarding = (json['onboarding'] as Map?) ?? const {};
    final rawDob = json['date_of_birth'] as String?;
    return MeModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      countryIso: (json['country_iso'] as String?) ?? 'IN',
      fullName: json['full_name'] as String?,
      age: (json['age'] as num?)?.toInt(),
      dateOfBirth: rawDob != null && rawDob.isNotEmpty
          ? DateTime.tryParse(rawDob)
          : null,
      gender: json['gender'] as String?,
      occupation: json['occupation'] as String?,
      currency: (json['currency'] as String?) ?? '₹',
      monthlySurplus: (json['monthly_surplus'] as num?)?.toDouble(),
      dailyLimit: (json['daily_limit'] as num?)?.toDouble(),
      payday: (json['payday'] as num?)?.toInt(),
      baselineDone: onboarding['baseline_done'] == true,
      cycleDone: onboarding['cycle_done'] == true,
    );
  }
}