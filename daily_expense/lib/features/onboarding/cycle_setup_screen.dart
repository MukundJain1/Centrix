import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dashboard/dashboard_screen.dart';
import '../../core/theme/colors.dart';
import 'budget_storage.dart';

class CycleSetupScreen extends StatefulWidget {
  final double monthlySurplus;
  final String currency;

  const CycleSetupScreen({
    super.key,
    required this.monthlySurplus,
    required this.currency,
  });

  @override
  State<CycleSetupScreen> createState() => _CycleSetupScreenState();
}

class _CycleSetupScreenState extends State<CycleSetupScreen> {
  int _paydayDate = 1;
  final TextEditingController _balanceController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  // --- Core Logic ---
  int get _daysUntilPayday {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime nextPayday;

    if (today.day < _paydayDate) {
      int daysInCurrentMonth = DateTime(today.year, today.month + 1, 0).day;
      int actualPayday = _paydayDate > daysInCurrentMonth ? daysInCurrentMonth : _paydayDate;
      nextPayday = DateTime(today.year, today.month, actualPayday);
    } else {
      int daysInNextMonth = DateTime(today.year, today.month + 2, 0).day;
      int actualPayday = _paydayDate > daysInNextMonth ? daysInNextMonth : _paydayDate;
      nextPayday = DateTime(today.year, today.month + 1, actualPayday);
    }

    int days = nextPayday.difference(today).inDays;
    if (days == 0) {
       days = DateTime(today.year, today.month + 1, 0).day;
    }
    return days;
  }

  Future<void> _finishSetup() async {
    FocusScope.of(context).unfocus();
    
    double currentBalance = double.tryParse(_balanceController.text) ?? 0;
    
    if (currentBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your current balance")),
      );
      return;
    }

    setState(() => _saving = true);

    double initialDailyLimit = currentBalance / _daysUntilPayday;

    // Now securely saves the payday and surplus to your updated storage
    await BudgetStorage.save(
      dailyLimit: initialDailyLimit,
      currency: widget.currency,
      payday: _paydayDate,
      monthlySurplus: widget.monthlySurplus,
    );

    if (!mounted) return;
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(dailyBudgetLimit: initialDailyLimit),
      ),
      (route) => false,
    );
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 24.0;
    int daysLeft = _daysUntilPayday;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content Area prevents overflow
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "When do you get paid?",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "We use this to reset your cycle automatically.",
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 32),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.inputSurface.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Salary Date", style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _paydayDate,
                              dropdownColor: AppColors.inputSurface,
                              style: const TextStyle(color: AppColors.primaryAccent, fontSize: 18, fontWeight: FontWeight.bold),
                              items: List.generate(31, (index) {
                                return DropdownMenuItem(
                                  value: index + 1,
                                  child: Text("${index + 1}"),
                                );
                              }),
                              onChanged: (val) => setState(() => _paydayDate = val!),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    const Text(
                      "Current Balance",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "You have $daysLeft days until your next payday. How much money do you have left in your accounts to spend until then?",
                      style: const TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.inputSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: _balanceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        cursorColor: AppColors.primaryAccent,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          prefixText: "${widget.currency} ",
                          prefixStyle: const TextStyle(color: AppColors.primaryAccent, fontSize: 18, fontWeight: FontWeight.bold),
                          hintText: "0.00",
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24), // Extra bottom padding for scroll space
                  ],
                ),
              ),
            ),
            
            // Fixed Button at the bottom (moves up naturally when keyboard opens)
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _finishSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : const Text(
                          "Start Budgeting",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}