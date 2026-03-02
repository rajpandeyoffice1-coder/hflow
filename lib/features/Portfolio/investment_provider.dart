// lib/providers/investment_provider.dart
import 'package:flutter/material.dart';
import '../../models/investment_models.dart';
import 'inv_supabase_service.dart';
import 'package:intl/intl.dart';

class InvestmentProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  List<Investment> _investments = [];
  List<Category> _categories = [];
  List<SubCategory> _subCategories = [];
  List<FinancialGoal> _financialGoals = [];

  bool _isLoading = false;
  bool _isRefreshing = false;
  String _errorMessage = '';

  // Getters
  List<Investment> get investments => _investments;
  List<Category> get categories => _categories;
  List<SubCategory> get subCategories => _subCategories;
  List<FinancialGoal> get financialGoals => _financialGoals;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String get errorMessage => _errorMessage;

  Future<void> loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        loadCategories(),
        loadInvestments(),
        loadFinancialGoals(),
      ]);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error loading initial data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshData() async {
    _isRefreshing = true;
    notifyListeners();

    try {
      await Future.wait([
        loadCategories(),
        loadInvestments(),
        loadFinancialGoals(),
      ]);
      _errorMessage = '';
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error refreshing data: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      final response = await _supabaseService.getCategories();
      _categories = response.map((json) => Category.fromJson(json)).toList();

      final subResponse = await _supabaseService.getSubCategories();
      _subCategories = subResponse
          .map((json) => SubCategory.fromJson(json))
          .toList();

      // Attach subcategories to categories
      for (var category in _categories) {
        category.subCategories = _subCategories
            .where((sub) => sub.categoryId == category.id)
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      _initializeLocalCategories();
    }
  }

  void _initializeLocalCategories() {
    _categories = [
      Category(
        id: 1,
        name: 'Mutual Funds',
        icon: '📈',
        color: '#10B981',
        subCategories: [
          SubCategory(id: 101, name: 'Large Cap', categoryId: 1),
          SubCategory(id: 102, name: 'Mid Cap', categoryId: 1),
          SubCategory(id: 103, name: 'Small Cap', categoryId: 1),
          SubCategory(id: 104, name: 'ELSS', categoryId: 1),
        ],
      ),
      Category(
        id: 2,
        name: 'Stocks',
        icon: '📊',
        color: '#6366F1',
        subCategories: [
          SubCategory(id: 201, name: 'Tech', categoryId: 2),
          SubCategory(id: 202, name: 'Finance', categoryId: 2),
          SubCategory(id: 203, name: 'Healthcare', categoryId: 2),
        ],
      ),
      Category(id: 3, name: 'Fixed Deposit', icon: '🏦', color: '#F59E0B'),
      Category(id: 4, name: 'PPF', icon: '🇮🇳', color: '#8B5CF6'),
      Category(id: 5, name: 'Gold / Jewelry', icon: '🥇', color: '#EAB308'),
      Category(id: 6, name: 'Real Estate', icon: '🏠', color: '#64748B'),
      Category(id: 7, name: 'SIP', icon: '🔄', color: '#EC4899'),
      Category(id: 8, name: 'Chit Fund', icon: '🤝', color: '#14B8A6'),
      Category(id: 9, name: 'Life Insurance', icon: '🛡️', color: '#06B6D4'),
      Category(id: 10, name: 'NPS', icon: '👴', color: '#9333EA'),
      Category(id: 11, name: 'Crypto', icon: '₿', color: '#EF4444'),
      Category(id: 12, name: 'Recurring Deposit', icon: '📅', color: '#F97316'),
      Category(
        id: 13,
        name: 'Sovereign Gold Bond',
        icon: '📜',
        color: '#84CC16',
      ),
      Category(id: 14, name: 'EPF', icon: '🏢', color: '#0EA5E9'),
    ];
  }

  Future<void> loadInvestments() async {
    try {
      final response = await _supabaseService.getInvestments();
      _investments = response.map((json) => Investment.fromJson(json)).toList();

      // Load redemptions for each investment
      for (var investment in _investments) {
        final redemptions = await _supabaseService.getRedemptions(
          investment.id,
        );
        investment.redemptions = redemptions;
        investment.redeemedAmount = redemptions.fold(
          0,
          (sum, r) => sum + r.amount,
        );
      }
    } catch (e) {
      debugPrint('Error loading investments: $e');
      _initializeSampleData();
    }
  }

  void _initializeSampleData() {
    _investments = [
      Investment(
        id: '1',
        date: '2026-01-15',
        category: 'Mutual Funds',
        subCategory: 'Large Cap',
        amount: 50000,
        owner: 'Hari',
        paymentMethod: 'Bank Transfer',
        comments: 'Monthly SIP',
      ),
      Investment(
        id: '2',
        date: '2026-02-01',
        category: 'Stocks',
        subCategory: 'Tech',
        amount: 25000,
        owner: 'Sangeetha',
        paymentMethod: 'UPI',
        comments: 'Tech stocks',
      ),
      Investment(
        id: '3',
        date: '2026-01-10',
        category: 'Fixed Deposit',
        amount: 100000,
        owner: 'Hari',
        paymentMethod: 'Bank Transfer',
        comments: '1 year FD',
      ),
      Investment(
        id: '4',
        date: '2026-02-20',
        category: 'Gold / Jewelry',
        amount: 75000,
        owner: 'Sangeetha',
        paymentMethod: 'Cash',
        comments: 'Gold purchase',
      ),
    ];
  }

  Future<void> loadFinancialGoals() async {
    try {
      final response = await _supabaseService.getFinancialGoals();
      _financialGoals = response
          .map((json) => FinancialGoal.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error loading financial goals: $e');
      _financialGoals = [];
    }
  }

  Future<void> addInvestment(Investment investment) async {
    try {
      await _supabaseService.addInvestment(investment);
      await loadInvestments();
    } catch (e) {
      debugPrint('Error adding investment: $e');
      rethrow;
    }
  }

  Future<void> updateInvestment(Investment investment) async {
    try {
      await _supabaseService.updateInvestment(investment);
      await loadInvestments();
    } catch (e) {
      debugPrint('Error updating investment: $e');
      rethrow;
    }
  }

  Future<void> deleteInvestment(String id) async {
    try {
      await _supabaseService.deleteInvestment(id);
      await loadInvestments();
    } catch (e) {
      debugPrint('Error deleting investment: $e');
      rethrow;
    }
  }

  Future<void> redeemInvestment(
    String investmentId,
    double amount,
    String notes,
  ) async {
    try {
      await _supabaseService.addRedemption(investmentId, amount, notes);
      await loadInvestments();
    } catch (e) {
      debugPrint('Error redeeming investment: $e');
      rethrow;
    }
  }

  // Analytics Methods
  double getTotalInvested({String owner = 'all'}) {
    return _investments
        .where((inv) => owner == 'all' || inv.owner == owner)
        .fold(0, (sum, inv) => sum + inv.amount);
  }

  double getTotalCurrentValue({String owner = 'all'}) {
    return _investments
        .where((inv) => owner == 'all' || inv.owner == owner)
        .fold(0, (sum, inv) => sum + inv.currentValue);
  }

  double getTotalRedeemed({String owner = 'all'}) {
    return _investments
        .where((inv) => owner == 'all' || inv.owner == owner)
        .fold(0, (sum, inv) => sum + inv.redeemedAmount);
  }

  double getTotalProjected({String owner = 'all'}) {
    return _investments
        .where((inv) => owner == 'all' || inv.owner == owner)
        .fold(0, (sum, inv) => sum + inv.projected5Y);
  }

  double getTotalByOwner(String owner) {
    return _investments
        .where((inv) => inv.owner == owner)
        .fold(0, (sum, inv) => sum + inv.currentValue);
  }

  Map<String, double> getCategoryDistribution({String owner = 'all'}) {
    Map<String, double> distribution = {};
    for (var inv in _investments) {
      if (owner != 'all' && inv.owner != owner) continue;
      distribution[inv.category] =
          (distribution[inv.category] ?? 0) + inv.currentValue;
    }
    return distribution;
  }

  Map<String, double> getMonthlyTrend({String owner = 'all'}) {
    Map<String, double> monthlyData = {};
    for (var inv in _investments) {
      if (owner != 'all' && inv.owner != owner) continue;

      try {
        final date = DateTime.parse(inv.date);
        final monthKey = DateFormat('MMM yyyy').format(date);
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + inv.amount;
      } catch (e) {
        // Skip invalid dates
      }
    }

    // Sort by date
    final sortedKeys = monthlyData.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('MMM yyyy').parse(a);
        final dateB = DateFormat('MMM yyyy').parse(b);
        return dateA.compareTo(dateB);
      });

    final sortedData = <String, double>{};
    for (var key in sortedKeys) {
      sortedData[key] = monthlyData[key]!;
    }

    return sortedData;
  }

  Map<String, double> getHeatmapData() {
    Map<String, double> heatmap = {};
    final now = DateTime.now();
    final startDate = DateTime(now.year - 1, now.month, now.day);

    for (var inv in _investments) {
      try {
        final date = DateTime.parse(inv.date);
        if (date.isAfter(startDate) &&
            date.isBefore(now.add(const Duration(days: 1)))) {
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          heatmap[dateKey] = (heatmap[dateKey] ?? 0) + inv.amount;
        }
      } catch (e) {
        // Skip invalid dates
      }
    }

    return heatmap;
  }

  double getMaxCategoryValue({String owner = 'all'}) {
    final distribution = getCategoryDistribution(owner: owner);
    if (distribution.isEmpty) return 0;
    return distribution.values.reduce((a, b) => a > b ? a : b);
  }

  Color getCategoryColor(String category) {
    if (category.contains('Mutual')) return const Color(0xFF5B8CFF);
    if (category.contains('Stock')) return const Color(0xFF10B981);
    if (category.contains('FD') || category.contains('Fixed')) {
      return const Color(0xFFF97316);
    }
    if (category.contains('Gold')) return const Color(0xFFEAB308);
    if (category.contains('Real Estate')) return const Color(0xFF9333EA);
    if (category.contains('Crypto')) return const Color(0xFFEF4444);
    if (category.contains('PPF') || category.contains('EPF')) {
      return const Color(0xFF8B5CF6);
    }
    return const Color(0xFF64748B);
  }

  String getCategoryIcon(String category) {
    if (category.contains('Mutual')) return '📈';
    if (category.contains('Stock')) return '📊';
    if (category.contains('FD') || category.contains('Fixed')) return '🏦';
    if (category.contains('PPF')) return '🇮🇳';
    if (category.contains('Gold')) return '🥇';
    if (category.contains('Real Estate')) return '🏠';
    if (category.contains('SIP')) return '🔄';
    if (category.contains('Chit')) return '🤝';
    if (category.contains('Insurance')) return '🛡️';
    if (category.contains('NPS')) return '👴';
    if (category.contains('Crypto')) return '₿';
    if (category.contains('RD')) return '📅';
    if (category.contains('SGB')) return '📜';
    if (category.contains('EPF')) return '🏢';
    return '💰';
  }
}
