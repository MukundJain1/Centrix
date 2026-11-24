/// What the server tells us about the signed-in user (GET /v1/auth/me).
class MeModel {
  const MeModel({
    required this.id,
    required this.phone,
    required this.countryIso,
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
  final String currency;
  final double? monthlySurplus;
  final double? dailyLimit;
  final int? payday;

  /// Setup steps. Decide where to send the user after sign in:
  /// baseline not done -> Financial Baseline, then cycle, then Dashboard.
  final bool baselineDone;
  final bool cycleDone;

  factory MeModel.fromJson(Map<String, dynamic> json) {
    final onboarding = (json['onboarding'] as Map?) ?? const {};
    return MeModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      countryIso: (json['country_iso'] as String?) ?? 'IN',
      currency: (json['currency'] as String?) ?? '₹',
      monthlySurplus: (json['monthly_surplus'] as num?)?.toDouble(),
      dailyLimit: (json['daily_limit'] as num?)?.toDouble(),
      payday: (json['payday'] as num?)?.toInt(),
      baselineDone: onboarding['baseline_done'] == true,
      cycleDone: onboarding['cycle_done'] == true,
    );
  }
}
