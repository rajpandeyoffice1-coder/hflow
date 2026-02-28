import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================================
// TAX CALCULATION MODELS
// ============================================================================

class TaxCalculationModel {
  String fiscalYear;
  double businessIncome;
  double otherIncome;
  double grossIncome;

  // Tax Settings
  String taxRegime;
  String ageCategory;

  // Deductions
  double section80C;
  double section80D;
  double nps;
  double homeLoanInterest;
  double educationLoan;
  double donations;
  double savingsInterest;

  // Business Expenses
  List<BusinessExpense> businessExpenses;
  List<Asset> assets;

  // Results
  double newRegimeTax;
  double oldRegimeTax;
  double recommendedTax;
  String recommendedRegime;
  double potentialSavings;
  DateTime calculationDate;

  TaxCalculationModel({
    required this.fiscalYear,
    this.businessIncome = 0,
    this.otherIncome = 0,
    this.grossIncome = 0,
    this.taxRegime = 'new',
    this.ageCategory = 'below_60',
    this.section80C = 0,
    this.section80D = 0,
    this.nps = 0,
    this.homeLoanInterest = 0,
    this.educationLoan = 0,
    this.donations = 0,
    this.savingsInterest = 0,
    this.businessExpenses = const [],
    this.assets = const [],
    this.newRegimeTax = 0,
    this.oldRegimeTax = 0,
    this.recommendedTax = 0,
    this.recommendedRegime = 'new',
    this.potentialSavings = 0,
    DateTime? calculationDate,
  }) : calculationDate = calculationDate ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'fiscal_year': fiscalYear,
      'gross_income': grossIncome,
      'business_income': businessIncome,
      'other_income': otherIncome,
      'total_deductions':
          section80C +
          section80D +
          nps +
          homeLoanInterest +
          educationLoan +
          donations +
          savingsInterest,
      'standard_deduction': 0,
      'taxable_income':
          grossIncome -
          (section80C +
              section80D +
              nps +
              homeLoanInterest +
              educationLoan +
              donations +
              savingsInterest),
      'regime_used': recommendedRegime,
      'tax_before_rebate': recommendedTax,
      'rebate_under_87a': 0,
      'tax_after_rebate': recommendedTax,
      'health_education_cess': recommendedTax * 0.04,
      'surcharge': 0,
      'total_tax_liability': recommendedTax * 1.04,
      'effective_tax_rate': grossIncome > 0
          ? (recommendedTax / grossIncome)
          : 0,
      'new_regime_tax': newRegimeTax,
      'old_regime_tax': oldRegimeTax,
      'recommended_regime': recommendedRegime,
      'potential_savings': (newRegimeTax - oldRegimeTax).abs(),
      'calculation_data': {
        'section_80c': section80C,
        'section_80d': section80D,
        'nps': nps,
        'home_loan_interest': homeLoanInterest,
        'education_loan': educationLoan,
        'donations': donations,
        'savings_interest': savingsInterest,
        'business_expenses': businessExpenses.map((e) => e.toJson()).toList(),
        'assets': assets.map((a) => a.toJson()).toList(),
      },
    };
  }

  factory TaxCalculationModel.fromJson(Map<String, dynamic> json) {
    return TaxCalculationModel(
      fiscalYear: json['fiscal_year'] ?? '2025-26',
      businessIncome: (json['business_income'] ?? 0).toDouble(),
      otherIncome: (json['other_income'] ?? 0).toDouble(),
      grossIncome: (json['gross_income'] ?? 0).toDouble(),
      taxRegime: json['regime_used'] ?? 'new',
      newRegimeTax: (json['new_regime_tax'] ?? 0).toDouble(),
      oldRegimeTax: (json['old_regime_tax'] ?? 0).toDouble(),
      recommendedTax: (json['tax_after_rebate'] ?? 0).toDouble(),
      recommendedRegime: json['recommended_regime'] ?? 'new',
      potentialSavings: (json['potential_savings'] ?? 0).toDouble(),
      calculationDate: DateTime.parse(
        json['calculation_date'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class BusinessExpense {
  String name;
  double amount;
  DateTime expenseDate;
  bool isAsset;
  String? category;

  BusinessExpense({
    required this.name,
    required this.amount,
    required this.expenseDate,
    this.isAsset = false,
    this.category,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'expense_date': expenseDate.toIso8601String(),
      'is_asset': isAsset,
      'category': category,
    };
  }

  factory BusinessExpense.fromJson(Map<String, dynamic> json) {
    return BusinessExpense(
      name: json['name'],
      amount: (json['amount'] ?? 0).toDouble(),
      expenseDate: DateTime.parse(json['expense_date']),
      isAsset: json['is_asset'] ?? false,
      category: json['category'],
    );
  }
}

class Asset {
  String name;
  String type;
  double value;
  double rate;
  DateTime purchaseDate;

  Asset({
    required this.name,
    required this.type,
    required this.value,
    required this.rate,
    required this.purchaseDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'value': value,
      'rate': rate,
      'purchase_date': purchaseDate.toIso8601String(),
    };
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      name: json['name'],
      type: json['type'],
      value: (json['value'] ?? 0).toDouble(),
      rate: (json['rate'] ?? 0).toDouble(),
      purchaseDate: DateTime.parse(json['purchase_date']),
    );
  }
}

// ============================================================================
// SUPABASE SERVICE
// ============================================================================

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;
  final String userId = 'default_user';

  Future<Map<String, dynamic>?> getTaxProfile(String fiscalYear) async {
    try {
      final response = await client
          .from('tax_profiles')
          .select()
          .eq('user_id', userId)
          .eq('fiscal_year', fiscalYear)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting tax profile: $e');
      return null;
    }
  }

  Future<void> saveTaxProfile(Map<String, dynamic> profile) async {
    try {
      await client.from('tax_profiles').upsert({
        'user_id': userId,
        ...profile,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving tax profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getTaxIncome(String fiscalYear) async {
    try {
      final response = await client
          .from('tax_income')
          .select()
          .eq('user_id', userId)
          .eq('fiscal_year', fiscalYear)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting tax income: $e');
      return null;
    }
  }

  Future<void> saveTaxIncome(Map<String, dynamic> income) async {
    try {
      await client.from('tax_income').upsert({
        'user_id': userId,
        ...income,
        'gross_total_income':
            (income['business_income'] ?? 0) + (income['other_income'] ?? 0),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving tax income: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTaxDeductions(
    String fiscalYear,
    String section,
  ) async {
    try {
      final response = await client
          .from('tax_deductions')
          .select()
          .eq('user_id', userId)
          .eq('fiscal_year', fiscalYear)
          .eq('deduction_section', section);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting tax deductions: $e');
      return [];
    }
  }

  Future<void> saveTaxDeduction(Map<String, dynamic> deduction) async {
    try {
      await client.from('tax_deductions').insert({
        'user_id': userId,
        ...deduction,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving tax deduction: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getBusinessExpenses(
    String fiscalYear,
  ) async {
    try {
      final response = await client
          .from('tax_business_expenses')
          .select()
          .eq('user_id', userId)
          .eq('fiscal_year', fiscalYear)
          .order('expense_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting business expenses: $e');
      return [];
    }
  }

  Future<void> saveBusinessExpense(Map<String, dynamic> expense) async {
    try {
      await client.from('tax_business_expenses').insert({
        'user_id': userId,
        ...expense,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving business expense: $e');
    }
  }

  Future<void> saveTaxCalculation(Map<String, dynamic> calculation) async {
    try {
      await client.from('tax_calculations').insert({
        'user_id': userId,
        ...calculation,
        'calculation_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving tax calculation: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTaxHistory(String fiscalYear) async {
    try {
      final response = await client
          .from('tax_calculations')
          .select()
          .eq('user_id', userId)
          .eq('fiscal_year', fiscalYear)
          .order('calculation_date', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting tax history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getFiscalYearSummary(String fiscalYear) async {
    try {
      final income = await getTaxIncome(fiscalYear);
      final deductions80C = await getTaxDeductions(fiscalYear, '80C');
      final deductions80D = await getTaxDeductions(fiscalYear, '80D');
      final expenses = await getBusinessExpenses(fiscalYear);

      double total80C = deductions80C.fold(
        0,
        (sum, item) => sum + (item['amount'] ?? 0),
      );
      double total80D = deductions80D.fold(
        0,
        (sum, item) => sum + (item['amount'] ?? 0),
      );
      double totalExpenses = expenses.fold(
        0,
        (sum, item) => sum + (item['amount'] ?? 0),
      );

      return {
        'income': income ?? {},
        'total_80c': total80C,
        'total_80d': total80D,
        'total_expenses': totalExpenses,
      };
    } catch (e) {
      print('Error getting fiscal year summary: $e');
      return {};
    }
  }
}

// ============================================================================
// TOAST SERVICE
// ============================================================================

Widget _premiumLoader(String message) {
  return Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: 260,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.18),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 30,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(const Color(0xFF5B8CFF)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  decoration: TextDecoration.none, // ✅ removes underline
                  color: const Color(0xFFE0E7FF),
                  shadows: [
                    Shadow(
                      color: const Color(0xFF5B8CFF).withOpacity(0.6),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ToastService {
  static void showSuccess(BuildContext context, String message) {
    _showToast(context, message, Colors.green);
  }

  static void showError(BuildContext context, String message) {
    _showToast(context, message, Colors.red);
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(context, message, Colors.blue);
  }

  static void _showToast(BuildContext context, String message, Color color) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  color == Colors.green
                      ? Icons.check_circle
                      : color == Colors.red
                      ? Icons.error
                      : Icons.info,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }
}

// ============================================================================
// LOADING OVERLAY WIDGET - FIXED
// ============================================================================

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? loadingMessage;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.loadingMessage,
  });

  @override
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.45), // softer dim
              child: _premiumLoader(loadingMessage ?? "Saving data..."),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// MAIN TAX CALCULATOR SCREEN - FIXED UI
// ============================================================================

class TaxCalculatorScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const TaxCalculatorScreen({super.key, this.onBack});

  @override
  State<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends State<TaxCalculatorScreen> {
  static const double _headerHeight = 60;
  final SupabaseService _supabaseService = SupabaseService();
  final String fiscalYear = "2025-26";

  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;
  String _loadingMessage = 'Refreshing data...';

  // Controllers for Income Details
  final TextEditingController businessIncomeController =
      TextEditingController();
  final TextEditingController otherIncomeController = TextEditingController();

  // Tax Settings
  String selectedRegime = 'new';
  String selectedAgeGroup = 'below_60';
  String selectedAssessmentYear = '2025-26';

  // Deduction Controllers
  final TextEditingController ppfController = TextEditingController();
  final TextEditingController elssController = TextEditingController();
  final TextEditingController licController = TextEditingController();
  final TextEditingController epfController = TextEditingController();
  final TextEditingController nscController = TextEditingController();
  final TextEditingController fdController = TextEditingController();
  final TextEditingController homeLoanPrincipalController =
      TextEditingController();
  final TextEditingController tuitionController = TextEditingController();

  final TextEditingController healthSelfController = TextEditingController();
  final TextEditingController healthParentsController = TextEditingController();
  final TextEditingController healthCheckupController = TextEditingController();

  final TextEditingController npsController = TextEditingController();
  final TextEditingController homeLoanInterestController =
      TextEditingController();
  final TextEditingController educationLoanController = TextEditingController();
  final TextEditingController donationsController = TextEditingController();
  final TextEditingController savingsInterestController =
      TextEditingController();

  bool isPresumptiveMode = true;
  List<BusinessExpense> businessExpenses = [];
  List<Asset> assets = [];

  double newRegimeTax = 0;
  double oldRegimeTax = 0;
  bool showResults = false;

  String totalEarnings = "₹0";
  String paidInvoices = "₹0";
  String pendingInvoices = "₹0";

  @override
  void initState() {
    super.initState();
    _loadSavedData();

    businessExpenses.add(
      BusinessExpense(name: 'Rent', amount: 5000, expenseDate: DateTime.now()),
    );
    businessExpenses.add(
      BusinessExpense(
        name: 'Internet',
        amount: 1000,
        expenseDate: DateTime.now(),
      ),
    );

    assets.add(
      Asset(
        name: 'Laptop',
        type: 'Computer',
        value: 80000,
        rate: 40,
        purchaseDate: DateTime.now().subtract(const Duration(days: 30)),
      ),
    );
    assets.add(
      Asset(
        name: 'Office Desk',
        type: 'Furniture',
        value: 20000,
        rate: 10,
        purchaseDate: DateTime.now().subtract(const Duration(days: 60)),
      ),
    );
  }

  Future<void> _loadSavedData() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Refreshing data...';
    });

    try {
      final profile = await _supabaseService.getTaxProfile(fiscalYear);
      if (profile != null) {
        setState(() {
          selectedRegime = profile['tax_regime'] ?? 'new';
          selectedAgeGroup = profile['age_category'] ?? 'below_60';
        });
      }

      final income = await _supabaseService.getTaxIncome(fiscalYear);
      if (income != null) {
        businessIncomeController.text =
            income['business_income']?.toString() ?? '';
        otherIncomeController.text = income['other_income']?.toString() ?? '';
      }

      final deductions80C = await _supabaseService.getTaxDeductions(
        fiscalYear,
        '80C',
      );
      for (var deduction in deductions80C) {
        switch (deduction['category']) {
          case 'PPF':
            ppfController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'ELSS':
            elssController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'LIC':
            licController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'EPF':
            epfController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'NSC':
            nscController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'FD':
            fdController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'Home Loan Principal':
            homeLoanPrincipalController.text =
                deduction['amount']?.toString() ?? '';
            break;
          case 'Tuition':
            tuitionController.text = deduction['amount']?.toString() ?? '';
            break;
        }
      }

      final deductions80D = await _supabaseService.getTaxDeductions(
        fiscalYear,
        '80D',
      );
      for (var deduction in deductions80D) {
        switch (deduction['category']) {
          case 'Self/Family':
            healthSelfController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'Parents':
            healthParentsController.text =
                deduction['amount']?.toString() ?? '';
            break;
          case 'Checkup':
            healthCheckupController.text =
                deduction['amount']?.toString() ?? '';
            break;
        }
      }

      final otherDeductions = await _supabaseService.getTaxDeductions(
        fiscalYear,
        'Other',
      );
      for (var deduction in otherDeductions) {
        switch (deduction['category']) {
          case 'NPS':
            npsController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'Home Loan Interest':
            homeLoanInterestController.text =
                deduction['amount']?.toString() ?? '';
            break;
          case 'Education Loan':
            educationLoanController.text =
                deduction['amount']?.toString() ?? '';
            break;
          case 'Donations':
            donationsController.text = deduction['amount']?.toString() ?? '';
            break;
          case 'Savings Interest':
            savingsInterestController.text =
                deduction['amount']?.toString() ?? '';
            break;
        }
      }

      final expenses = await _supabaseService.getBusinessExpenses(fiscalYear);
      if (expenses.isNotEmpty) {
        businessExpenses = expenses
            .map(
              (e) => BusinessExpense(
                name: e['description'] ?? '',
                amount: (e['amount'] ?? 0).toDouble(),
                expenseDate: DateTime.parse(
                  e['expense_date'] ?? DateTime.now().toIso8601String(),
                ),
                isAsset: e['is_asset'] ?? false,
                category: e['expense_type'],
              ),
            )
            .toList();
      }

      ToastService.showSuccess(context, 'Data loaded successfully!');
    } catch (e) {
      ToastService.showError(context, 'Error loading data');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAllData() async {
    setState(() => _isSaving = true);

    try {
      await _supabaseService.saveTaxProfile({
        'fiscal_year': fiscalYear,
        'tax_regime': selectedRegime,
        'age_category': selectedAgeGroup,
        'residential_status': 'resident',
        'has_business_income': businessIncomeController.text.isNotEmpty,
      });

      await _supabaseService.saveTaxIncome({
        'fiscal_year': fiscalYear,
        'business_income': parseDouble(businessIncomeController.text),
        'other_income': parseDouble(otherIncomeController.text),
        'interest_income': parseDouble(otherIncomeController.text),
      });

      await _saveDeduction('80C', 'PPF', ppfController);
      await _saveDeduction('80C', 'ELSS', elssController);
      await _saveDeduction('80C', 'LIC', licController);
      await _saveDeduction('80C', 'EPF', epfController);
      await _saveDeduction('80C', 'NSC', nscController);
      await _saveDeduction('80C', 'FD', fdController);
      await _saveDeduction(
        '80C',
        'Home Loan Principal',
        homeLoanPrincipalController,
      );
      await _saveDeduction('80C', 'Tuition', tuitionController);

      await _saveDeduction('80D', 'Self/Family', healthSelfController);
      await _saveDeduction('80D', 'Parents', healthParentsController);
      await _saveDeduction('80D', 'Checkup', healthCheckupController);

      await _saveDeduction('Other', 'NPS', npsController);
      await _saveDeduction(
        'Other',
        'Home Loan Interest',
        homeLoanInterestController,
      );
      await _saveDeduction('Other', 'Education Loan', educationLoanController);
      await _saveDeduction('Other', 'Donations', donationsController);
      await _saveDeduction(
        'Other',
        'Savings Interest',
        savingsInterestController,
      );

      for (var expense in businessExpenses) {
        await _supabaseService.saveBusinessExpense({
          'fiscal_year': fiscalYear,
          'expense_type': expense.category ?? 'business',
          'description': expense.name,
          'amount': expense.amount,
          'expense_date': expense.expenseDate.toIso8601String(),
          'is_asset': expense.isAsset,
          'is_deductible': true,
        });
      }

      ToastService.showSuccess(context, 'All data saved successfully!');
    } catch (e) {
      ToastService.showError(context, 'Error saving data');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveDeduction(
    String section,
    String category,
    TextEditingController controller,
  ) async {
    double amount = parseDouble(controller.text);
    if (amount > 0) {
      await _supabaseService.saveTaxDeduction({
        'fiscal_year': fiscalYear,
        'deduction_section': section,
        'category': category,
        'description': '$category investment',
        'amount': amount,
        'payment_date': DateTime.now().toIso8601String(),
      });
    }
  }

  double parseDouble(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    return double.tryParse(value) ?? 0.0;
  }

  double getTotal80C() {
    double total =
        parseDouble(ppfController.text) +
        parseDouble(elssController.text) +
        parseDouble(licController.text) +
        parseDouble(epfController.text) +
        parseDouble(nscController.text) +
        parseDouble(fdController.text) +
        parseDouble(homeLoanPrincipalController.text) +
        parseDouble(tuitionController.text);
    return total > 150000 ? 150000.0 : total;
  }

  double getTotal80D() {
    double self = parseDouble(healthSelfController.text);
    double parents = parseDouble(healthParentsController.text);
    double checkup = parseDouble(healthCheckupController.text);

    self = self > 25000 ? 25000.0 : self;
    parents = parents > 50000 ? 50000.0 : parents;
    checkup = checkup > 5000 ? 5000.0 : checkup;

    double total = self + parents + checkup;
    return total > 100000 ? 100000.0 : total;
  }

  double getTotalOtherDeductions() {
    double nps = parseDouble(npsController.text);
    nps = nps > 50000 ? 50000.0 : nps;

    double homeInterest = parseDouble(homeLoanInterestController.text);
    homeInterest = homeInterest > 200000 ? 200000.0 : homeInterest;

    double savings = parseDouble(savingsInterestController.text);
    savings = savings > 10000 ? 10000.0 : savings;

    return nps +
        homeInterest +
        savings +
        parseDouble(educationLoanController.text) +
        parseDouble(donationsController.text);
  }

  double getTotalBusinessExpenses() {
    if (isPresumptiveMode) {
      double grossIncome = getGrossIncome();
      return grossIncome * 0.5;
    } else {
      double total = 0.0;
      for (var expense in businessExpenses) {
        total += expense.amount;
      }
      return total;
    }
  }

  double getTotalDepreciation() {
    double total = 0.0;
    for (var asset in assets) {
      total += (asset.value) * ((asset.rate) / 100.0);
    }
    return total;
  }

  double getGrossIncome() {
    return parseDouble(businessIncomeController.text) +
        parseDouble(otherIncomeController.text);
  }

  double getTaxableIncomeOld() {
    double gross = getGrossIncome();
    double businessDeduction = getTotalBusinessExpenses();
    double depreciation = getTotalDepreciation();
    double deductions80C = getTotal80C();
    double deductions80D = getTotal80D();
    double otherDeductions = getTotalOtherDeductions();

    return gross -
        businessDeduction -
        depreciation -
        deductions80C -
        deductions80D -
        otherDeductions;
  }

  double getTaxableIncomeNew() {
    double gross = getGrossIncome();
    double businessDeduction = getTotalBusinessExpenses();
    double depreciation = getTotalDepreciation();

    return gross - businessDeduction - depreciation;
  }

  double calculateNewRegimeTax() {
    double income = getTaxableIncomeNew();
    double tax = 0.0;

    if (income <= 300000) {
      tax = 0.0;
    } else if (income <= 600000) {
      tax = (income - 300000) * 0.05;
    } else if (income <= 900000) {
      tax = 15000.0 + (income - 600000) * 0.10;
    } else if (income <= 1200000) {
      tax = 45000.0 + (income - 900000) * 0.15;
    } else if (income <= 1500000) {
      tax = 90000.0 + (income - 1200000) * 0.20;
    } else {
      tax = 150000.0 + (income - 1500000) * 0.30;
    }

    return tax + (tax * 0.04);
  }

  double calculateOldRegimeTax() {
    double income = getTaxableIncomeOld();
    double tax = 0.0;

    double exemptionLimit = 250000.0;
    if (selectedAgeGroup == 'senior_citizen') {
      exemptionLimit = 300000.0;
    } else if (selectedAgeGroup == 'super_senior') {
      exemptionLimit = 500000.0;
    }

    if (income <= exemptionLimit) {
      tax = 0.0;
    } else if (income <= 500000) {
      tax = (income - exemptionLimit) * 0.05;
    } else if (income <= 1000000) {
      tax = (500000.0 - exemptionLimit) * 0.05 + (income - 500000) * 0.20;
    } else {
      tax =
          (500000.0 - exemptionLimit) * 0.05 +
          500000.0 * 0.20 +
          (income - 1000000) * 0.30;
    }

    if (income <= 500000) {
      tax = tax > 12500 ? tax - 12500 : 0.0;
    }

    return tax + (tax * 0.04);
  }

  void calculateTax() {
    setState(() {
      newRegimeTax = calculateNewRegimeTax();
      oldRegimeTax = calculateOldRegimeTax();
      showResults = true;
    });
  }

  void resetAll() {
    setState(() {
      businessIncomeController.clear();
      otherIncomeController.clear();
      ppfController.clear();
      elssController.clear();
      licController.clear();
      epfController.clear();
      nscController.clear();
      fdController.clear();
      homeLoanPrincipalController.clear();
      tuitionController.clear();
      healthSelfController.clear();
      healthParentsController.clear();
      healthCheckupController.clear();
      npsController.clear();
      homeLoanInterestController.clear();
      educationLoanController.clear();
      donationsController.clear();
      savingsInterestController.clear();
      selectedRegime = 'new';
      selectedAgeGroup = 'below_60';
      isPresumptiveMode = true;
      showResults = false;
      newRegimeTax = 0.0;
      oldRegimeTax = 0.0;
    });
  }

  Future<void> _saveCalculationToHistory() async {
    if (!showResults) return;

    try {
      TaxCalculationModel calculation = TaxCalculationModel(
        fiscalYear: fiscalYear,
        businessIncome: parseDouble(businessIncomeController.text),
        otherIncome: parseDouble(otherIncomeController.text),
        grossIncome: getGrossIncome(),
        taxRegime: selectedRegime,
        ageCategory: selectedAgeGroup,
        section80C: getTotal80C(),
        section80D: getTotal80D(),
        nps: parseDouble(npsController.text),
        homeLoanInterest: parseDouble(homeLoanInterestController.text),
        educationLoan: parseDouble(educationLoanController.text),
        donations: parseDouble(donationsController.text),
        savingsInterest: parseDouble(savingsInterestController.text),
        businessExpenses: businessExpenses,
        assets: assets,
        newRegimeTax: newRegimeTax,
        oldRegimeTax: oldRegimeTax,
        recommendedRegime: newRegimeTax <= oldRegimeTax ? 'new' : 'old',
        recommendedTax: newRegimeTax <= oldRegimeTax
            ? newRegimeTax
            : oldRegimeTax,
        potentialSavings: (newRegimeTax - oldRegimeTax).abs(),
      );

      await _supabaseService.saveTaxCalculation(calculation.toJson());
      ToastService.showSuccess(context, 'Calculation saved to history!');
    } catch (e) {
      ToastService.showError(context, 'Error saving calculation');
    }
  }

  void _showAddExpenseDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Add Business Expense',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Expense Name',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixText: '₹ ',
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  amountController.text.isNotEmpty) {
                double amount = double.parse(amountController.text);
                BusinessExpense expense = BusinessExpense(
                  name: nameController.text,
                  amount: amount,
                  expenseDate: DateTime.now(),
                );

                setState(() {
                  businessExpenses.add(expense);
                });

                ToastService.showSuccess(
                  context,
                  'Expense added successfully!',
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8CFF),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddAssetDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController valueController = TextEditingController();
    String selectedType = 'Computer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text(
          'Add Asset',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Asset Name',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                dropdownColor: const Color(0xFF1E1E2E),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Asset Type',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Computer',
                    child: Text('Computer (40%)'),
                  ),
                  DropdownMenuItem(
                    value: 'Furniture',
                    child: Text('Furniture (10%)'),
                  ),
                  DropdownMenuItem(
                    value: 'Machinery',
                    child: Text('Machinery (15%)'),
                  ),
                ],
                onChanged: (value) => setState(() => selectedType = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Asset Value (₹)',
                  labelStyle: const TextStyle(color: Colors.white70),
                  prefixText: '₹ ',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  valueController.text.isNotEmpty) {
                double rate = selectedType == 'Computer'
                    ? 40.0
                    : (selectedType == 'Furniture' ? 10.0 : 15.0);
                double value = double.parse(valueController.text);

                Asset asset = Asset(
                  name: nameController.text,
                  type: selectedType,
                  value: value,
                  rate: rate,
                  purchaseDate: DateTime.now(),
                );

                setState(() {
                  assets.add(asset);
                });

                ToastService.showSuccess(context, 'Asset added successfully!');
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8CFF),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth > 600 ? 24.0 : 16.0;

    return LoadingOverlay(
      isLoading: _isLoading || _isSaving,
      loadingMessage: _isLoading
          ? _loadingMessage
          : (_isSaving ? 'Saving your data...' : null),
      child: Scaffold(
        backgroundColor: const Color(0xFF05060A),
        body: Stack(
          children: [
            Positioned(
              top: -120,
              left: -100,
              child: _liquidBlob(
                width: 320.0,
                height: 420.0,
                color: const Color(0xFF9333EA),
                opacity: 0.28,
              ),
            ),
            Positioned(
              bottom: -160,
              right: -120,
              child: _liquidBlob(
                width: 380.0,
                height: 460.0,
                color: const Color(0xFF3B82F6),
                opacity: 0.26,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        padding,
                        padding,
                        padding,
                        120,
                      ),
                      child: Column(
                        children: [
                          _glassCard(child: _buildFiscalYearHeader()),
                          const SizedBox(height: 16),
                          _glassCard(child: _buildTaxCalculatorSection()),
                          const SizedBox(height: 16),
                          _glassCard(child: _buildDeductionsSection()),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiscalYearHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Fiscal Year Earnings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'FY $fiscalYear (Current)',
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFFFBBF24),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GST Status: Zero-Rated [Export Services]',
                      style: TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'As a self-employed professional earning in USD from foreign clients, your export of services is zero-rated under GST (Section 28(1) GST Act). No GST payable on foreign earnings.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _statCard(
                label: 'Total Earnings',
                value: totalEarnings,
                color: Colors.white,
              ),
            ),
            Expanded(
              child: _statCard(
                label: 'Paid Invoices',
                value: paidInvoices,
                color: const Color(0xFF22C55E),
              ),
            ),
            Expanded(
              child: _statCard(
                label: 'Pending',
                value: pendingInvoices,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Monthly Earnings Trend',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            itemBuilder: (context, index) {
              return Container(
                width: 28,
                margin: const EdgeInsets.only(right: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: (index + 1) * 3.0,
                      width: 20,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'M${index + 1}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaxCalculatorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🧮', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Text(
                  'Tax Calculator',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.save, color: Colors.white70, size: 20),
                  onPressed: _saveAllData,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: resetAll,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildIncomeColumn(),
        const SizedBox(height: 20),
        _buildTaxSettings(),
        const SizedBox(height: 20),
        if (selectedRegime == 'old') _buildDeductionsColumn(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B8CFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  calculateTax();
                  _saveCalculationToHistory();
                },
                child: const Text(
                  'Calculate Tax',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: resetAll,
                child: const Text(
                  'Reset',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (showResults) _buildResults(),
      ],
    );
  }

  Widget _buildDeductionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('💎', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Text(
                  'Deductions & Tax Savings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTaxModeToggle(),
        const SizedBox(height: 20),
        if (!isPresumptiveMode) _buildBusinessExpenses(),
        const SizedBox(height: 20),
        _buildDepreciation(),
        const SizedBox(height: 20),
        _buildSection80C(),
        const SizedBox(height: 20),
        _buildSection80D(),
        const SizedBox(height: 20),
        _buildOtherDeductions(),
        const SizedBox(height: 20),
        _buildDeductionsSummary(),
      ],
    );
  }

  Widget _buildIncomeColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📊', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text(
              'Income Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInputField(
          label: 'Business/Professional Income',
          controller: businessIncomeController,
          hint: 'Pre-filled from your invoice earnings',
        ),
        const SizedBox(height: 12),
        _buildInputField(
          label: 'Other Income (Interest, etc.)',
          controller: otherIncomeController,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gross Income:',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '₹${getGrossIncome().toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaxSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('⚙️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text(
              'Tax Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildDropdown(
                label: 'Tax Regime',
                value: selectedRegime,
                items: const [
                  DropdownMenuItem(
                    value: 'new',
                    child: Text('New Regime (Recommended)'),
                  ),
                  DropdownMenuItem(
                    value: 'old',
                    child: Text('Old Regime (With Deductions)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => selectedRegime = value!);
                },
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                label: 'Age Category',
                value: selectedAgeGroup,
                items: const [
                  DropdownMenuItem(
                    value: 'below_60',
                    child: Text('Below 60 years'),
                  ),
                  DropdownMenuItem(
                    value: 'senior_citizen',
                    child: Text('Senior Citizen (60-80)'),
                  ),
                  DropdownMenuItem(
                    value: 'super_senior',
                    child: Text('Super Senior (80+)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => selectedAgeGroup = value!);
                },
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                label: 'Assessment Year',
                value: selectedAssessmentYear,
                items: const [
                  DropdownMenuItem(
                    value: '2025-26',
                    child: Text('AY 2026-27 (FY 2025-26)'),
                  ),
                  DropdownMenuItem(
                    value: '2024-25',
                    child: Text('AY 2025-26 (FY 2024-25)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() => selectedAssessmentYear = value!);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeductionsColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('💎', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text(
              'Deductions (Old Regime)',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInputField(
          label: 'Section 80C (Max ₹1.5L)',
          controller: ppfController,
          hint: 'PPF, ELSS, LIC, etc.',
          maxLimit: 150000,
        ),
        const SizedBox(height: 12),
        _buildInputField(
          label: 'Section 80D (Health Insurance)',
          controller: healthSelfController,
          hint: 'Max ₹25,000',
          maxLimit: 100000,
        ),
        const SizedBox(height: 12),
        _buildInputField(label: 'Other Deductions', controller: npsController),
      ],
    );
  }

  Widget _buildTaxModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('⚙️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(
              'Expense Calculation Mode:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildModeButton(
                label: '44ADA Presumptive (50%)',
                isActive: isPresumptiveMode,
                onTap: () => setState(() => isPresumptiveMode = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModeButton(
                label: 'Actual Expenses',
                isActive: !isPresumptiveMode,
                onTap: () => setState(() => isPresumptiveMode = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBBF24).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFFFBBF24),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPresumptiveMode
                      ? 'Section 44ADA: 50% of your gross receipts is automatically considered as business expenses. No need to maintain detailed books.'
                      : 'Enter your actual business expenses below for more accurate tax calculation.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
                )
              : null,
          color: isActive ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? Colors.transparent
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessExpenses() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('📋', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Text(
                  'Business Expenses',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            _buildAddButton(
              label: '+ Add Expense',
              onTap: _showAddExpenseDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...businessExpenses
            .map(
              (expense) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      expense.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      '₹${expense.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        const Divider(color: Colors.white10, height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total Business Expenses:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '₹${getTotalBusinessExpenses().toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDepreciation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🖥️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Text(
                  'Depreciation on Assets',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            _buildAddButton(label: '+ Add Asset', onTap: _showAddAssetDialog),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF3B82F6),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Depreciation is calculated using Written Down Value (WDV) method. Rates: Computers 40%, Furniture 10%, Machinery 15%',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...assets
            .map(
              (asset) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          asset.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${asset.rate.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Value: ₹${asset.value.toStringAsFixed(0)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Dep: ₹${(asset.value * asset.rate / 100).toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Color(0xFF22C55E),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        const Divider(color: Colors.white10, height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Annual Depreciation:',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '₹${getTotalDepreciation().toStringAsFixed(0)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection80C() {
    double total80C = getTotal80C();
    double progress = total80C / 150000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Text(
                  'Section 80C \nInvestments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '₹${total80C.toStringAsFixed(0)} / ₹1,50,000',
                style: TextStyle(
                  color: total80C >= 150000
                      ? const Color(0xFF22C55E)
                      : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress > 1 ? 1.0 : progress,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              total80C >= 150000
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF5B8CFF),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: [
            _buildDeductionInput('PPF', ppfController),
            _buildDeductionInput('ELSS', elssController),
            _buildDeductionInput('LIC', licController),
            _buildDeductionInput('EPF/VPF', epfController),
            _buildDeductionInput('NSC', nscController),
            _buildDeductionInput('Tax Saver FD', fdController),
            _buildDeductionInput(
              'Home Loan Principal',
              homeLoanPrincipalController,
            ),
            _buildDeductionInput('Children Tuition', tuitionController),
          ],
        ),
      ],
    );
  }

  Widget _buildSection80D() {
    double total80D = getTotal80D();
    double progress = total80D / 100000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🏥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Text(
                  'Section 80D \nHealth Insurance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '₹${total80D.toStringAsFixed(0)} / ₹1,00,000',
                style: TextStyle(
                  color: total80D >= 100000
                      ? const Color(0xFF22C55E)
                      : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress > 1 ? 1.0 : progress,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              total80D >= 100000
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF5B8CFF),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 16),
        _buildDeductionInput(
          'Self/Family Premium',
          healthSelfController,
          hint: 'Max ₹25,000',
        ),
        const SizedBox(height: 12),
        _buildDeductionInput(
          'Parents Premium',
          healthParentsController,
          hint: 'Max ₹25,000 (₹50,000 if senior)',
        ),
        const SizedBox(height: 12),
        _buildDeductionInput(
          'Preventive Health Checkup',
          healthCheckupController,
          hint: 'Max ₹5,000',
        ),
      ],
    );
  }

  Widget _buildOtherDeductions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📑', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            const Text(
              'Other Deductions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildDeductionInput(
          'NPS - 80CCD(1B)',
          npsController,
          hint: 'Additional ₹50,000 over 80C',
        ),
        const SizedBox(height: 12),
        _buildDeductionInput(
          'Home Loan Interest - 24(b)',
          homeLoanInterestController,
          hint: 'Max ₹2,00,000 for self-occupied',
        ),
        const SizedBox(height: 12),
        _buildDeductionInput(
          'Education Loan Interest - 80E',
          educationLoanController,
          hint: 'No limit (up to 8 years)',
        ),
        const SizedBox(height: 12),
        _buildDeductionInput(
          'Donations - 80G',
          donationsController,
          hint: '50-100% based on fund',
        ),
        const SizedBox(height: 12),
        _buildDeductionInput(
          'Savings Interest - 80TTA',
          savingsInterestController,
          hint: 'Max ₹10,000',
        ),
      ],
    );
  }

  Widget _buildDeductionsSummary() {
    double businessExpense = getTotalBusinessExpenses();
    double depreciation = getTotalDepreciation();
    double chapterVia =
        getTotal80C() + getTotal80D() + getTotalOtherDeductions();
    double total = businessExpense + depreciation + chapterVia;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Business Expenses / Presumptive (50%):',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                '₹${businessExpense.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Depreciation:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                '₹${depreciation.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chapter VI-A Deductions:',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                '₹${chapterVia.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Tax Savings \nDeductions:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Color(0xFF22C55E),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '⚠️ Most deductions only apply under Old Tax Regime. The calculator will compare both regimes.',
              style: TextStyle(
                color: Color(0xFFFBBF24),
                fontSize: 10,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    String recommendedRegime = newRegimeTax <= oldRegimeTax ? 'New' : 'Old';
    Color recommendedColor = recommendedRegime == 'New'
        ? const Color(0xFF5B8CFF)
        : const Color(0xFF9333EA);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📋', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text(
                'Tax Calculation Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B8CFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: recommendedRegime == 'New'
                          ? const Color(0xFF5B8CFF)
                          : Colors.white.withOpacity(0.1),
                      width: recommendedRegime == 'New' ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'New Regime',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${newRegimeTax.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: recommendedRegime == 'New'
                              ? const Color(0xFF5B8CFF)
                              : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9333EA).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: recommendedRegime == 'Old'
                          ? const Color(0xFF9333EA)
                          : Colors.white.withOpacity(0.1),
                      width: recommendedRegime == 'Old' ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Old Regime',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${oldRegimeTax.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: recommendedRegime == 'Old'
                              ? const Color(0xFF9333EA)
                              : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  recommendedColor.withOpacity(0.2),
                  recommendedColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: recommendedColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: recommendedColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended: $recommendedRegime Regime',
                        style: TextStyle(
                          color: recommendedColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can save ₹${(newRegimeTax - oldRegimeTax).abs().toStringAsFixed(0)} by choosing the $recommendedRegime regime',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _saveCalculationToHistory,
                icon: const Icon(Icons.history, size: 16),
                label: const Text(
                  'Save to History',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    double? maxLimit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            inputFormatters: maxLimit != null
                ? [FilteringTextInputFormatter.digitsOnly]
                : null,
            onChanged: (value) {
              if (maxLimit != null && value.isNotEmpty) {
                double val = parseDouble(value);
                if (val > maxLimit) {
                  controller.text = maxLimit.toStringAsFixed(0);
                }
              }
              setState(() {});
            },
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: const TextStyle(color: Colors.white70, fontSize: 14),
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeductionInput(
    String label,
    TextEditingController controller, {
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            onChanged: (value) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 9,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1A1F2E),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white70,
                size: 20,
              ),
              isExpanded: true,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildAddButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          const Expanded(
            child: Text(
              "Tax Calculator & Deductions",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, size: 18, color: Colors.white70),
            onPressed: () =>
                ToastService.showInfo(context, 'History feature coming soon!'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
            onPressed: _loadSavedData,
          ),
        ],
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // 🔥 Outer Shadow (3D depth)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 25,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
            ),

            // 🔥 Glass Blur
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),

                  // Premium gradient glass effect
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),

                  // Light border highlight
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1.2,
                  ),
                ),

                child: Stack(
                  children: [
                    // ✨ Inner Shine (top light reflection)
                    Positioned(
                      top: -40,
                      left: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actual Content
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _liquidBlob({
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}
