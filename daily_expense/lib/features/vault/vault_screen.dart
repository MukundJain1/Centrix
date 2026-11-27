import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../auth/data/auth_repository.dart';
import '../expenses/expense_repository.dart';
import '../settings/app_settings.dart';
import 'vault_calculator.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, required this.dailyLimit});

  final double dailyLimit;

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _cardController;
  late final AnimationController _receiptController;
  late final AnimationController _stampController;

  double _dragAngleY = 0.0;
  bool _vaultOpen = true;

  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  void initState() {
    super.initState();

    // 1. Entrance 3D metallic vault card rotation.
    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 2. Extruding thermal receipt animation (1.2s smooth paper feed).
    _receiptController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 3. Circular stamp impact animation after receipt finishes printing.
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _runVaultSequence();
  }

  Future<void> _runVaultSequence() async {
    _dragAngleY = 0.0;
    _cardController.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _receiptController.forward(from: 0);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    await _stampController.forward(from: 0);
  }

  void _toggleVaultDoor() {
    HapticFeedback.lightImpact();
    setState(() => _vaultOpen = !_vaultOpen);
    if (_vaultOpen) {
      _runVaultSequence();
    } else {
      _stampController.reverse();
      _receiptController.reverse();
    }
  }

  @override
  void dispose() {
    _cardController.dispose();
    _receiptController.dispose();
    _stampController.dispose();
    super.dispose();
  }

  String _signedMoney(AppSettings s, double amount) {
    final abs = amount.abs();
    final prefix = amount > 0.009
        ? '+'
        : amount < -0.009
            ? '-'
            : '';
    return '$prefix${s.money(abs)}';
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final repo = ExpenseRepository.instance;
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryAccent),
        title: const Text(
          'Savings Vault',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reprint Statement',
            onPressed: _runVaultSequence,
            icon: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primaryAccent,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([settings, repo]),
          builder: (context, _) {
            final user = AuthRepository.instance.currentUser.value;
            final memberSince = user?.createdAt ?? DateTime.now();
            final vault = VaultCalculator.compute(
              dailyLimit: widget.dailyLimit,
              memberSince: memberSince,
              repo: repo,
            );

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 36),
                  children: [
                    _build3dVaultCard(settings, vault, user?.displayName),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Drag card to tilt in 3D • Tap to ${_vaultOpen ? 'lock' : 'open'} statement',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildReceiptPrinter(settings, vault),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ------------------------------------------------------- 3D Vault Card

  Widget _build3dVaultCard(
    AppSettings settings,
    VaultSummary vault,
    String? holderName,
  ) {
    final isNegative = vault.totalSavedAllTime < 0;
    final accent = isNegative ? Colors.redAccent : AppColors.primaryAccent;

    return GestureDetector(
      onTap: _toggleVaultDoor,
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragAngleY = (_dragAngleY + details.delta.dx * 0.008)
              .clamp(-0.45, 0.45);
        });
      },
      onHorizontalDragEnd: (_) {
        setState(() => _dragAngleY = 0.0);
      },
      child: AnimatedBuilder(
        animation: _cardController,
        builder: (context, child) {
          final introT = Curves.easeOutBack.transform(_cardController.value);
          final introAngle = (1 - introT) * 0.35;
          final angleY = introAngle + _dragAngleY;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(angleY)
              ..rotateX(-0.04),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF232834),
                AppColors.inputSurface,
                Color(0xFF12151C),
              ],
            ),
            border: Border.all(
              color: accent.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _vaultOpen
                              ? Icons.lock_open_rounded
                              : Icons.lock_rounded,
                          color: accent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'PERSONAL VAULT',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      'Since ${vault.memberSince.day} ${_months[vault.memberSince.month - 1]} ${vault.memberSince.year}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Total Vault Balance',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  settings.money(vault.totalSavedAllTime),
                  style: TextStyle(
                    color: accent,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _vaultMetric(
                        label: 'Saved This Month',
                        value: _signedMoney(settings, vault.savedThisMonth),
                        color: vault.savedThisMonth < 0
                            ? Colors.redAccent
                            : AppColors.primaryAccent,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _vaultMetric(
                        label: vault.todayOverspendCut < 0
                            ? 'Cut Today (Over)'
                            : 'Pending Tonight',
                        value: vault.todayOverspendCut < 0
                            ? _signedMoney(settings, vault.todayOverspendCut)
                            : '+${settings.money(vault.todayPending)}',
                        color: vault.todayOverspendCut < 0
                            ? Colors.redAccent
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (holderName != null &&
                  holderName != 'Complete your profile') ...[
                const SizedBox(height: 16),
                Text(
                  holderName.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _vaultMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------- Extruding Vault Receipt

  Widget _buildReceiptPrinter(AppSettings settings, VaultSummary vault) {
    return Column(
      children: [
        // Metallic printer slot header
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.inputSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        // Paper extruding downward out of the slot
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: AnimatedBuilder(
            animation: _receiptController,
            builder: (context, child) {
              final factor = Curves.easeOutCubic.transform(
                _receiptController.value,
              );
              return ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: factor,
                  child: child,
                ),
              );
            },
            child: Stack(
              children: [
                CustomPaint(
                  painter: _SerratedReceiptPainter(
                    fillColor: const Color(0xFF1F2430),
                    borderColor: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            'VAULT LEDGER',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'AUTO-SAVED & OVERSPEND STATEMENT',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _dashedDivider(),
                        const SizedBox(height: 14),
                        const Text(
                          'MONTH-WISE BREAKDOWN',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final entry in vault.monthlyHistory)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${_months[entry.month - 1]} ${entry.year}',
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  _signedMoney(settings, entry.netSaved),
                                  style: TextStyle(
                                    color: entry.netSaved < 0
                                        ? Colors.redAccent
                                        : AppColors.primaryAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        _dashedDivider(),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ALL-TIME VAULT',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              settings.money(vault.totalSavedAllTime),
                              style: TextStyle(
                                color: vault.totalSavedAllTime < 0
                                    ? Colors.redAccent
                                    : AppColors.primaryAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        // Simulated barcode
                        SizedBox(
                          height: 34,
                          child: CustomPaint(painter: _BarcodePainter()),
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'Unspent daily budget adds automatically.\nDaily overspend deducts from Vault.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Circular impact stamp (inspired by reference video)
                Positioned(
                  right: 22,
                  bottom: 84,
                  child: AnimatedBuilder(
                    animation: _stampController,
                    builder: (context, child) {
                      if (_stampController.value == 0) {
                        return const SizedBox.shrink();
                      }
                      final t = Curves.elasticOut.transform(
                        _stampController.value,
                      );
                      final scale = 1.9 - (0.9 * t);
                      return Opacity(
                        opacity: _stampController.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: scale,
                          child: Transform.rotate(
                            angle: -0.22,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (vault.totalSavedAllTime < 0
                                  ? Colors.redAccent
                                  : AppColors.primaryAccent)
                              .withValues(alpha: 0.65),
                          width: 2.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: (vault.totalSavedAllTime < 0
                                    ? Colors.redAccent
                                    : AppColors.primaryAccent)
                                .withValues(alpha: 0.45),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          vault.totalSavedAllTime < 0 ? 'ACTIVE' : 'VAULTED',
                          style: TextStyle(
                            color: (vault.totalSavedAllTime < 0
                                    ? Colors.redAccent
                                    : AppColors.primaryAccent)
                                .withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => Container(
              width: 4,
              height: 1,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
        );
      },
    );
  }
}

class _SerratedReceiptPainter extends CustomPainter {
  _SerratedReceiptPainter({
    required this.fillColor,
    required this.borderColor,
  });

  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    const toothWidth = 10.0;
    const toothHeight = 6.0;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - toothHeight);

    double x = size.width;
    while (x > 0) {
      final nextX = math.max(0.0, x - toothWidth / 2);
      path.lineTo(nextX, size.height);
      final upX = math.max(0.0, x - toothWidth);
      path.lineTo(upX, size.height - toothHeight);
      x -= toothWidth;
    }

    path.close();

    canvas.drawPath(path, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarcodePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const pattern = [
      2, 1, 3, 1, 2, 2, 1, 3, 1, 1, 2, 3, 2, 1, 2, 1, 3, 2, 1, 2, 1, 3, 1, 2,
    ];
    final totalUnits = pattern.fold<int>(0, (s, v) => s + v + 1);
    final unitWidth = size.width / totalUnits;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.45);

    double x = 0;
    for (final bar in pattern) {
      final w = bar * unitWidth;
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + unitWidth;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}