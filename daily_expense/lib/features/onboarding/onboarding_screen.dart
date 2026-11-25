import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cycle_setup_screen.dart';
import 'data/baseline_repository.dart';
import '../dashboard/dashboard_screen.dart';
import '../settings/app_settings.dart';
import '../../core/theme/colors.dart';
import 'baseline_snapshot.dart';
import 'budget_storage.dart';
import 'widgets/budget_summary_bar.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/app_snackbar.dart';

// --- Data Models ---
class BudgetItem {
  final TextEditingController nameController;
  final TextEditingController amountController;

  BudgetItem({String name = '', String amount = ''})
    : nameController = TextEditingController(text: name),
      amountController = TextEditingController(text: amount);

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class BudgetCategory {
  BudgetCategory({
    required String title,
    this.isIncome = false,
    this.isCustom = false,
    List<BudgetItem>? items,
    this.suggestions = const [],
  }) : titleController = TextEditingController(text: title),
       items = items ?? [];

  /// Holds the title. Only custom categories let the user edit it.
  final TextEditingController titleController;
  final bool isIncome;
  final bool isCustom;
  final List<BudgetItem> items;
  final List<String> suggestions;

  String get title => titleController.text.trim();

  double get totalAmount {
    return items.fold<double>(0.0, (sum, item) {
      return sum + (double.tryParse(item.amountController.text) ?? 0);
    });
  }

  void dispose() {
    titleController.dispose();
    for (final item in items) {
      item.dispose();
    }
  }
}

// --- Screen ---

/// Financial Baseline. Used twice:
///  - right after registration (isEditing = false), and
///  - from Profile > Edit Baseline (isEditing = true), where it opens with
///    what the user saved and returns the new daily budget when they save.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedCurrency = '₹';
  final List<String> _currencies = ['₹', '\$', '€', '£'];

  List<BudgetCategory> _categories = [];

  String? _saveError;
  bool _saving = false;

  /// Edit mode: waiting for the saved data to load.
  bool _loadingSaved = false;

  /// What the form looked like when it opened. Used to detect unsaved edits.
  String _initialJson = '';

  String? _loadError;

  static const Map<String, List<String>> _suggestionMap = {
    'Monthly Income': ["Salary", "Freelance", "Business", "Rental Income"],
    'Housing': ["Rent", "Maintenance", "Property Tax"],
    'EMIs & Loans': ["Car Loan", "Bike Loan", "Home Loan", "Personal Loan"],
    'Utilities & Subscriptions': [
      "Electricity",
      "Water",
      "Netflix",
      "Prime",
      "Gym",
      "Mobile Recharge",
    ],
    'Fees & Others': ["School Fees", "Tuition", "Groceries", "Fuel"],
  };

  static List<String> _suggestionsFor(String title) =>
      _suggestionMap[title] ?? const [];

  List<BudgetCategory> _defaultCategories() => [
    BudgetCategory(
      title: "Monthly Income",
      isIncome: true,
      suggestions: _suggestionsFor("Monthly Income"),
    ),
    BudgetCategory(title: "Housing", suggestions: _suggestionsFor("Housing")),
    BudgetCategory(
      title: "EMIs & Loans",
      suggestions: _suggestionsFor("EMIs & Loans"),
    ),
    BudgetCategory(
      title: "Utilities & Subscriptions",
      suggestions: _suggestionsFor("Utilities & Subscriptions"),
    ),
    BudgetCategory(
      title: "Fees & Others",
      suggestions: _suggestionsFor("Fees & Others"),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _categories = _defaultCategories();
    // One default row in Income.
    _categories[0].items.add(_createItem("Salary"));

    if (widget.isEditing) {
      _loadingSaved = true;
      _loadSaved();
    } else {
      _initialJson = _snapshot().encode();
    }
  }

  @override
  void dispose() {
    for (final category in _categories) {
      category.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------- saved baseline

  BaselineSnapshot _snapshot() {
    return BaselineSnapshot(
      currency: _selectedCurrency,
      categories: [
        for (final c in _categories)
          CategorySnapshot(
            title: c.title,
            isIncome: c.isIncome,
            isCustom: c.isCustom,
            items: [
              for (final i in c.items)
                ItemSnapshot(
                  name: i.nameController.text.trim(),
                  amount: i.amountController.text.trim(),
                ),
            ],
          ),
      ],
    );
  }

  bool get _isDirty =>
      widget.isEditing &&
      !_loadingSaved &&
      _snapshot().encode() != _initialJson;

  BudgetCategory _fromSnapshot(CategorySnapshot c) {
    final category = BudgetCategory(
      title: c.title,
      isIncome: c.isIncome,
      isCustom: c.isCustom,
      suggestions: c.isCustom ? const [] : _suggestionsFor(c.title),
    );
    for (final i in c.items) {
      category.items.add(_createItem(i.name, amount: i.amount));
    }
    return category;
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.inputSurface,
        title: const Text(
          'Discard changes?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Your edits have not been saved.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Keep editing',
              style: TextStyle(color: AppColors.primaryAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Discard',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ live maths

  double get _totalIncome => _categories
      .where((c) => c.isIncome)
      .fold<double>(0.0, (sum, c) => sum + c.totalAmount);

  double get _totalExpenses => _categories
      .where((c) => !c.isIncome)
      .fold<double>(0.0, (sum, c) => sum + c.totalAmount);

  double get _surplus => _totalIncome - _totalExpenses;

  int get _daysInMonth {
    final now = DateTime.now();
    return DateUtils.getDaysInMonth(now.year, now.month);
  }

  double get _dailyBudget => _surplus <= 0 ? 0 : _surplus / _daysInMonth;

  // --------------------------------------------------------------- actions

  BudgetItem _createItem(String name, {String amount = ''}) {
    final item = BudgetItem(name: name, amount: amount);
    // Any change to an amount refreshes the totals and the summary bar.
    item.amountController.addListener(_onAmountChanged);
    return item;
  }

  void _onAmountChanged() {
    if (!mounted) return;
    setState(() => _saveError = null);
  }

  void _addItem(BudgetCategory category, String name) {
    setState(() => category.items.add(_createItem(name)));
  }

  void _removeItem(BudgetCategory category, BudgetItem item) {
    setState(() => category.items.remove(item));
    // Dispose after the frame, once the text fields are out of the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) => item.dispose());
  }

  void _removeCategory(BudgetCategory category) {
    setState(() => _categories.remove(category));
    WidgetsBinding.instance.addPostFrameCallback((_) => category.dispose());
  }

  void _addCustomCategory() {
    setState(() {
      _categories.add(BudgetCategory(title: '', isCustom: true));
    });
  }

  Future<void> _loadSaved() async {
    setState(() {
      _loadingSaved = true;
      _loadError = null;
    });

    try {
      final saved = await BaselineRepository.instance.load();
      if (!mounted) return;

      if (saved != null) {
        // Keep local cache updated for future offline support.
        await BudgetStorage.saveBaseline(saved);
        if (!mounted) return;
      }

      setState(() {
        if (saved != null && saved.categories.isNotEmpty) {
          final old = _categories;
          _categories = saved.categories.map(_fromSnapshot).toList();
          if (_currencies.contains(saved.currency)) {
            _selectedCurrency = saved.currency;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            for (final c in old) {
              c.dispose();
            }
          });
        }
        _loadingSaved = false;
        _initialJson = _snapshot().encode();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSaved = false;
        _loadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSaved = false;
        _loadError = 'Unable to fetch your saved baseline. Check your connection and try again.';
      });
    }
  }

  Future<void> _saveAndContinue() async {
    FocusScope.of(context).unfocus();

    if (_totalIncome <= 0) {
      setState(
        () => _saveError = 'Add at least one income amount to continue.',
      );
      return;
    }
    if (_surplus <= 0) {
      setState(() {
        _saveError = 'Reduce expenses or add income to get a daily budget.';
      });
      return;
    }

    setState(() {
      _saveError = null;
      _saving = true;
    });

    final dailyLimit = _dailyBudget;
    final snapshot = _snapshot();

    final BaselineResult result;
    try {
      result = await BaselineRepository.instance.save(snapshot);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.error(context, e.message);
      return;
    }

    final effectiveDailyLimit = result.dailyLimit ?? dailyLimit;

    await BudgetStorage.save(
      dailyLimit: effectiveDailyLimit,
      currency: _selectedCurrency,
      baseline: snapshot,
      monthlySurplus: result.monthlySurplus ?? _surplus,
    );
    AppSettings.instance.setCurrency(_selectedCurrency);

    if (!mounted) return;

    if (widget.isEditing) {
      // Back to the dashboard, which picks up the new daily budget.
      Navigator.pop(context, effectiveDailyLimit);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CycleSetupScreen(
            monthlySurplus: result.monthlySurplus ?? _surplus,
            currency: _selectedCurrency,
          ),
        ),
      );
    }
  }

  Widget _buildLoadErrorState(double hPad) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.inputSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Couldn't load baseline",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadSaved,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'Try again',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 24.0;

    return PopScope(
      // In edit mode, ask before leaving with unsaved changes.
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard == true && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // After registration the account already exists, so there is
          // nothing to go back to. In edit mode we show the back arrow.
          automaticallyImplyLeading: widget.isEditing,
          iconTheme: const IconThemeData(color: AppColors.primaryAccent),
          actions: [
            Container(
              margin: EdgeInsets.only(right: hPad),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.inputSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCurrency,
                  dropdownColor: AppColors.inputSurface,
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.primaryAccent,
                  ),
                  style: const TextStyle(
                    color: AppColors.primaryAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedCurrency = newValue);
                    }
                  },
                  items: _currencies
                      .map(
                        (c) =>
                            DropdownMenuItem<String>(value: c, child: Text(c)),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        body: _loadingSaved
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryAccent,
                ),
              )
            : _loadError != null
            ? _buildLoadErrorState(hPad)
            : SafeArea(
                bottom: false, // the summary bar handles the bottom inset
                child: Column(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.symmetric(
                              horizontal: hPad,
                              vertical: 16,
                            ),
                            children: [
                              Text(
                                widget.isEditing
                                    ? "Edit Baseline"
                                    : "Financial Baseline",
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.isEditing
                                    ? "Change, add or remove anything. Your daily budget is recalculated when you save."
                                    : "Add your income and fixed liabilities. Remove any sections that don't apply to you.",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 32),
                              for (final category in _categories)
                                _buildCategorySection(category),
                              TextButton.icon(
                                onPressed: _addCustomCategory,
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: AppColors.textMuted,
                                ),
                                label: const Text(
                                  "Add Custom Category",
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                    BudgetSummaryBar(
                      dailyBudget: _dailyBudget,
                      surplus: _surplus,
                      currency: _selectedCurrency,
                      message:
                          _saveError ??
                          (_surplus < 0
                              ? 'Your expenses are higher than your income.'
                              : null),
                      showButton: !keyboardOpen,
                      loading: _saving,
                      buttonLabel: widget.isEditing
                          ? 'Save changes'
                          : 'Save & continue',
                      onSave: _saveAndContinue,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCategorySection(BudgetCategory category) {
    // Hide suggestion chips that are already added.
    final used = category.items
        .map((i) => i.nameController.text.trim().toLowerCase())
        .toSet();
    final chips = category.suggestions
        .where((s) => !used.contains(s.toLowerCase()))
        .toList();

    return Container(
      key: ObjectKey(category),
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isCustom)
                      _buildTitleField(category)
                    else
                      Text(
                        category.title.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: category.isIncome
                              ? AppColors.primaryAccent
                              : Colors.orangeAccent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      "Total: $_selectedCurrency ${category.totalAmount.toStringAsFixed(0)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textMuted,
                ),
                onPressed: () => _removeCategory(category),
                tooltip: "Remove Section",
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),

          for (final item in category.items)
            Padding(
              key: ObjectKey(item),
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildItemTextField(
                      hint: "Name",
                      controller: item.nameController,
                      isNumber: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildItemTextField(
                      hint: "Amount",
                      controller: item.amountController,
                      isNumber: true,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => _removeItem(category, item),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 8),

          if (chips.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map((suggestion) {
                return ActionChip(
                  label: Text(
                    suggestion,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  backgroundColor: AppColors.background,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  onPressed: () => _addItem(category, suggestion),
                );
              }).toList(),
            ),

          const SizedBox(height: 12),

          InkWell(
            onTap: () => _addItem(category, ""),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.add,
                    color: AppColors.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.isCustom || category.title.isEmpty
                          ? "Add new item"
                          : "Add new ${category.title.toLowerCase()} item",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Editable title for custom categories.
  Widget _buildTitleField(BudgetCategory category) {
    return TextField(
      controller: category.titleController,
      textCapitalization: TextCapitalization.words,
      inputFormatters: [LengthLimitingTextInputFormatter(30)],
      cursorColor: AppColors.primaryAccent,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.orangeAccent,
        letterSpacing: 1.5,
      ),
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: 'CATEGORY NAME',
        hintStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.orangeAccent.withValues(alpha: 0.5),
          letterSpacing: 1.5,
        ),
        suffixIcon: const Icon(
          Icons.edit_outlined,
          size: 14,
          color: AppColors.textMuted,
        ),
        suffixIconConstraints: const BoxConstraints(minWidth: 24),
      ),
    );
  }

  Widget _buildItemTextField({
    required String hint,
    required TextEditingController controller,
    required bool isNumber,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textCapitalization: isNumber
            ? TextCapitalization.none
            : TextCapitalization.words,
        inputFormatters: isNumber
            ? [
                // Digits with at most 2 decimals, up to 12 characters.
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                LengthLimitingTextInputFormatter(12),
              ]
            : null,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        cursorColor: AppColors.primaryAccent,
        // Refresh the suggestion chips and the unsaved-changes check.
        onChanged: isNumber ? null : (_) => setState(() {}),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          prefixText: isNumber ? "$_selectedCurrency " : null,
          prefixStyle: const TextStyle(
            color: AppColors.primaryAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
