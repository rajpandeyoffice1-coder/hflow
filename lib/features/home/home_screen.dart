import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hflow/core/widgets/glass_bottom_nav.dart';
import 'package:hflow/core/widgets/glass_top_bar.dart';
import 'package:hflow/features/Portfolio/investment_portfolio_screen.dart';
import 'package:hflow/features/ProfileScreen/profile_screen.dart';
import 'package:hflow/features/SettingScreen/setting_screen.dart';
import 'package:hflow/features/ai_assistant/ai_assistant_screen.dart';
import 'package:hflow/features/budget/budget_tracking_screen.dart';
import 'package:hflow/features/business/business_analytics.dart';
import 'package:hflow/features/client_management/client_management_screen.dart';
import 'package:hflow/features/expenses/expense_screen.dart';
import 'package:hflow/features/invoice/create_invoice.dart';
import 'package:hflow/features/invoice/invoice_dashboard_screen.dart';
import 'package:hflow/features/invoice/invoice_detail.dart';
import 'package:hflow/features/notifications/notifications_screen.dart';
import 'package:hflow/features/tax/tax_calculator_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:hflow/features/invoice/InvoiceSupabaseService.dart' as invoice_service;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  static const double _topBarHeight = 120;

  final supabase = Supabase.instance.client;

  Map<String, dynamic> userSettings = {};
  Map<String, dynamic> balanceSummary = {
    'total_earnings': 0,
    'total_expenses': 0,
    'current_balance': 0,
  };
  List<dynamic> recentTransactions = [];
  List<dynamic> recentInvoices = [];
  List<dynamic> expenses = [];
  List<dynamic> allInvoices = [];
  List<dynamic> allExpenses = [];
  Map<String, double> analyticsData = {};
  Map<String, double> clientRevenue = {};
  Map<String, double> monthlyTrend = {};

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    if (hour < 21) return "Good Evening";
    return "Good Night";
  }

  bool isLoading = true;
  bool _isInitialized = false;
  String userName = "Hari";

  // Filter states for different sections
  String _transactionsFilter = "All Time";
  final List<String> _transactionsFilters = ["All Time", "Today", "This Week", "This Month"];

  String _analyticsFilter = "6 Months";
  final List<String> _analyticsFilters = ["3 Months", "6 Months", "Custom"];

  String _monthlyTrendFilter = "6 Months";
  final List<String> _monthlyTrendFilters = ["3 Months", "6 Months", "Custom"];

  String _incomeExpenseFilter = "6 Months";
  final List<String> _incomeExpenseFilters = ["3 Months", "6 Months", "Custom"];

  String _overviewFilter = "6 Months";
  final List<String> _overviewFilters = ["1 Month", "3 Months", "6 Months", "Custom"];

  // Custom range states
  DateTime? _analyticsCustomStart;
  DateTime? _analyticsCustomEnd;
  DateTime? _monthlyTrendCustomStart;
  DateTime? _monthlyTrendCustomEnd;
  DateTime? _incomeExpenseCustomStart;
  DateTime? _incomeExpenseCustomEnd;
  DateTime? _overviewCustomStart;
  DateTime? _overviewCustomEnd;

  // Chart data
  List<String> _analyticsMonths = [];
  List<double> _analyticsData = [];

  List<String> _monthlyTrendMonths = [];
  List<double> _monthlyTrendData = [];

  List<String> _incomeExpenseMonths = [];
  List<double> _incomeChartData = [];
  List<double> _expenseChartData = [];

  List<String> _overviewMonths = [];
  double _overviewIncome = 0;
  double _overviewExpenses = 0;

  final List<double> _incomeData = List.filled(12, 0);
  final List<double> _expenseData = List.filled(12, 0);

  int _selectedSegmentIndex = 0;
  late TabController _segmentTabController;

  Map<String, dynamic> _dashboardCache = {};
  DateTime? _lastCacheUpdate;

  @override
  void initState() {
    super.initState();
    _segmentTabController = TabController(length: 4, vsync: this);
    _segmentTabController.addListener(() {
      if (!_segmentTabController.indexIsChanging) {
        setState(() {
          _selectedSegmentIndex = _segmentTabController.index;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _refreshDashboard() async {
    setState(() => isLoading = true);
    _lastCacheUpdate = null;
    await loadDashboardData();
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _initializeData() async {
    try {
      await loadUserData();
      await loadDashboardData();
    } catch (e) {
      print("Init error: $e");
    }
    if (mounted) setState(() {
      _isInitialized = true;
      isLoading = false;
    });
  }

  @override
  void dispose() {
    _segmentTabController.dispose();
    super.dispose();
  }

  Future<void> loadUserData() async {
    try {
      final userId = supabase.auth.currentUser?.id ?? 'default_user';
      final settings = await supabase
          .from('settings')
          .select('profile_name, profile_email')
          .eq('user_id', userId)
          .maybeSingle();
      if (settings != null && mounted) {
        setState(() {
          userSettings = settings;
          userName = settings['profile_name'] ??
              settings['profile_email'] ??
              "hari@abcd.com";
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> loadDashboardData() async {
    if (_lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!).inMinutes < 5) {
      return;
    }

    try {
      final userId = supabase.auth.currentUser?.id ?? 'default_user';
      final now = DateTime.now();

      final results = await Future.wait([
        supabase
            .from('balance_summary')
            .select()
            .order('last_calculated_at', ascending: false)
            .limit(1)
            .maybeSingle(),
        supabase
            .from('invoices')
            .select('id, client_name, amount, date_issued, status')
            .order('date_issued', ascending: false)
            .limit(5),
        supabase
            .from('expenses')
            .select('id, amount, description, date_incurred, category_name, vendor_name')
            .order('date_incurred', ascending: false)
            .limit(10),
        supabase
            .from('clients')
            .select('name, total_amount')
            .order('total_amount', ascending: false)
            .limit(5),
        supabase
            .from('invoices')
            .select('amount, date_issued, status'),
        supabase
            .from('expenses')
            .select('amount, date_incurred'),
      ]);

      final summary = results[0] as Map<String, dynamic>? ?? {};
      final invoices = results[1] as List;
      final expensesData = results[2] as List;
      final clients = results[3] as List;
      final allInvoiceData = results[4] as List;
      final allExpenseData = results[5] as List;

      if (summary.isNotEmpty && mounted) {
        balanceSummary = summary;
      }

      for (int i = 0; i < 12; i++) {
        _incomeData[i] = 0;
        _expenseData[i] = 0;
      }

      for (var inv in allInvoiceData) {
        try {
          if (inv['status'] != 'Paid') continue;
          DateTime date = DateTime.parse(inv['date_issued']);
          int monthIndex = date.month - 1;
          double amount = (inv['amount'] as num?)?.toDouble() ?? 0;
          _incomeData[monthIndex] += amount;
        } catch (e) {
          continue;
        }
      }

      for (var exp in allExpenseData) {
        try {
          DateTime date = DateTime.parse(exp['date_incurred']);
          int monthIndex = date.month - 1;
          double amount = (exp['amount'] as num?)?.toDouble() ?? 0;
          _expenseData[monthIndex] += amount;
        } catch (e) {
          continue;
        }
      }

      final List<Map<String, dynamic>> transactions = [];
      for (var inv in invoices) {
        transactions.add({
          'id': inv['id'],
          'title': inv['client_name'] ?? 'Client',
          'subtitle': 'Invoice #${inv['id']}',
          'amount': '₹${NumberFormat('#,##0').format(inv['amount'] ?? 0)}',
          'isExpense': false,
          'date': DateTime.parse(inv['date_issued']),
        });
      }
      for (var exp in expensesData) {
        transactions.add({
          'id': exp['id'],
          'title': exp['description'] ?? exp['vendor_name'] ?? 'Expense',
          'subtitle': exp['category_name'] ?? 'Expense',
          'vendor': exp['vendor_name'],
          'amount': '-₹${NumberFormat('#,##0').format(exp['amount'] ?? 0)}',
          'isExpense': true,
          'date': DateTime.parse(exp['date_incurred']),
        });
      }
      transactions.sort((a, b) => b['date'].compareTo(a['date']));

      final Map<String, double> revenue = {};
      for (var client in clients) {
        revenue[client['name'] ?? 'Client'] = (client['total_amount'] as num?)?.toDouble() ?? 0;
      }

      recentInvoices = invoices.take(5).toList();
      expenses = expensesData;
      allInvoices = allInvoiceData;
      allExpenses = allExpenseData;
      recentTransactions = transactions.take(4).toList();
      clientRevenue = revenue;
      _lastCacheUpdate = DateTime.now();

      _applyAllFilters();

      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
  }

  void _applyAllFilters() {
    _applyAnalyticsFilter();
    _applyMonthlyTrendFilter();
    _applyIncomeExpenseFilter();
    _applyOverviewFilter();
  }

  void _applyAnalyticsFilter() {
    DateTime now = DateTime.now();
    DateTime startDate;
    int months = 6;

    if (_analyticsFilter == "Custom" && _analyticsCustomStart != null && _analyticsCustomEnd != null) {
      startDate = _analyticsCustomStart!;
    } else {
      switch (_analyticsFilter) {
        case "3 Months":
          months = 3;
          break;
        case "6 Months":
          months = 6;
          break;
        default:
          months = 6;
      }
      startDate = DateTime(now.year, now.month - months + 1, 1);
    }

    _analyticsMonths.clear();
    _analyticsData.clear();

    DateTime current = DateTime(startDate.year, startDate.month, 1);
    DateTime endDate = _analyticsFilter == "Custom" && _analyticsCustomEnd != null
        ? _analyticsCustomEnd!
        : now;

    while (!current.isAfter(endDate)) {
      _analyticsMonths.add(DateFormat('MMM yyyy').format(current));
      int index = current.month - 1;
      _analyticsData.add(_incomeData[index] - _expenseData[index]);
      current = DateTime(current.year, current.month + 1, 1);
    }
  }

  void _applyMonthlyTrendFilter() {
    DateTime now = DateTime.now();
    DateTime startDate;
    int months = 6;

    if (_monthlyTrendFilter == "Custom" && _monthlyTrendCustomStart != null && _monthlyTrendCustomEnd != null) {
      startDate = _monthlyTrendCustomStart!;
    } else {
      switch (_monthlyTrendFilter) {
        case "3 Months":
          months = 3;
          break;
        case "6 Months":
          months = 6;
          break;
        default:
          months = 6;
      }
      startDate = DateTime(now.year, now.month - months + 1, 1);
    }

    _monthlyTrendMonths.clear();
    _monthlyTrendData.clear();

    DateTime current = DateTime(startDate.year, startDate.month, 1);
    DateTime endDate = _monthlyTrendFilter == "Custom" && _monthlyTrendCustomEnd != null
        ? _monthlyTrendCustomEnd!
        : now;

    while (!current.isAfter(endDate)) {
      _monthlyTrendMonths.add(DateFormat('MMM').format(current));
      int index = current.month - 1;
      _monthlyTrendData.add(_incomeData[index]);
      current = DateTime(current.year, current.month + 1, 1);
    }
  }

  void _applyIncomeExpenseFilter() {
    DateTime now = DateTime.now();
    DateTime startDate;
    int months = 6;

    if (_incomeExpenseFilter == "Custom" && _incomeExpenseCustomStart != null && _incomeExpenseCustomEnd != null) {
      startDate = _incomeExpenseCustomStart!;
    } else {
      switch (_incomeExpenseFilter) {
        case "3 Months":
          months = 3;
          break;
        case "6 Months":
          months = 6;
          break;
        default:
          months = 6;
      }
      startDate = DateTime(now.year, now.month - months + 1, 1);
    }

    _incomeExpenseMonths.clear();
    _incomeChartData.clear();
    _expenseChartData.clear();

    DateTime current = DateTime(startDate.year, startDate.month, 1);
    DateTime endDate = _incomeExpenseFilter == "Custom" && _incomeExpenseCustomEnd != null
        ? _incomeExpenseCustomEnd!
        : now;

    while (!current.isAfter(endDate)) {
      _incomeExpenseMonths.add(DateFormat('MMM').format(current));
      int index = current.month - 1;
      _incomeChartData.add(_incomeData[index]);
      _expenseChartData.add(_expenseData[index]);
      current = DateTime(current.year, current.month + 1, 1);
    }
  }

  void _applyOverviewFilter() {
    DateTime now = DateTime.now();
    DateTime startDate;
    int months = 6;

    if (_overviewFilter == "Custom" && _overviewCustomStart != null && _overviewCustomEnd != null) {
      startDate = _overviewCustomStart!;
    } else {
      switch (_overviewFilter) {
        case "1 Month":
          months = 1;
          break;
        case "3 Months":
          months = 3;
          break;
        case "6 Months":
          months = 6;
          break;
        default:
          months = 6;
      }
      startDate = DateTime(now.year, now.month - months + 1, 1);
    }

    _overviewMonths.clear();
    double income = 0;
    double expenseTotal = 0;

    DateTime endDate = _overviewFilter == "Custom" && _overviewCustomEnd != null
        ? _overviewCustomEnd!
        : now;

    for (var inv in allInvoices) {
      try {
        DateTime date = DateTime.parse(inv['date_issued']);
        if (date.isAfter(startDate) && !date.isAfter(endDate)) {
          income += (inv['amount'] as num?)?.toDouble() ?? 0;
        }
      } catch (e) {}
    }

    for (var exp in allExpenses) {
      try {
        DateTime date = DateTime.parse(exp['date_incurred']);
        if (date.isAfter(startDate) && !date.isAfter(endDate)) {
          expenseTotal += (exp['amount'] as num?)?.toDouble() ?? 0;
        }
      } catch (e) {}
    }

    _overviewIncome = income;
    _overviewExpenses = expenseTotal;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: WillPopScope(
        onWillPop: () async {
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
            return false;
          }
          return true;
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF05060A),
          body: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
                  ),
                ),
              ),
              Positioned(
                top: -120,
                left: -100,
                child: _liquidBlob(
                  width: 320,
                  height: 420,
                  color: const Color(0xFF9333EA),
                  opacity: 0.28,
                ),
              ),
              Positioned(
                bottom: -160,
                right: -120,
                child: _liquidBlob(
                  width: 380,
                  height: 460,
                  color: const Color(0xFF3B82F6),
                  opacity: 0.26,
                ),
              ),
              if (_currentIndex == 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: _topBarHeight,
                    child: GlassTopBar(
                      leading: Image.asset(
                        'assets/images/logo_new.png',
                        height: 36,
                      ),
                      actions: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.notifications_none,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfileScreen(),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: const Color(0xFF5B8CFF),
                            child: Text(
                              userName.isNotEmpty ? userName[0].toUpperCase() : 'H',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  top: _currentIndex == 0 ? _topBarHeight - 40 : 0,
                ),
                child: SafeArea(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      _homeContent(),
                      ExpenseScreen(
                        onBack: () => setState(() => _currentIndex = 0),
                      ),
                      AiAssistantScreen(
                        onBack: () => setState(() => _currentIndex = 0),
                      ),
                      InvestmentPortfolioScreen(
                        onBack: () => setState(() => _currentIndex = 0),
                      ),
                      SettingsScreen(
                        onBack: () => setState(() => _currentIndex = 0),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: UltraGlassBottomNav(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
          ),
        ),
      ),
    );
  }

  Widget _homeContent() {
    if (isLoading || !_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6366F1)),
            const SizedBox(height: 16),
            Text(
              "Loading your dashboard...",
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF1A1C2A),
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              "${_getGreeting()}, ${userName.split('@')[0]}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Here's your financial overview",
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 20),
            _overviewSection(),
            const SizedBox(height: 22),
            const Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _quickActionsGrid(),
            const SizedBox(height: 22),
            _segmentTabs(),
            const SizedBox(height: 22),
            _buildSegmentContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentContent() {
    switch (_selectedSegmentIndex) {
      case 0:
        return _overviewContent();
      case 1:
        return _transactionsSection();
      case 2:
        return _recentInvoicesSection();
      case 3:
        return _analyticsContent();
      default:
        return _overviewContent();
    }
  }

  Widget _overviewContent() {
    return Column(
      children: [
        _summaryCards(),
        const SizedBox(height: 22),
        _monthlyTrendSection(),
        const SizedBox(height: 22),
        _incomeExpenseReport(),
        const SizedBox(height: 22),
        _clientRevenueSection(),
      ],
    );
  }

  Widget _analyticsContent() {
    return Column(
      children: [
        _analyticsSection(),
        const SizedBox(height: 22),
        _monthlyTrendSection(),
      ],
    );
  }

  Widget _transactionsSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Transactions",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              _buildFilterDropdown(
                value: _transactionsFilter,
                items: _transactionsFilters,
                onChanged: (value) {
                  setState(() => _transactionsFilter = value!);
                  _filterTransactions(value!);
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            DateFormat('EEE, MMMM d').format(DateTime.now()).toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white54,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          if (recentTransactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "No transactions yet",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ...recentTransactions.map(
                  (tx) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _transactionTile(
                  tx['title'],
                  tx['subtitle'],
                  tx['amount'],
                  vendor: tx['vendor'],
                  isExpense: tx['isExpense'],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1), width: 1.2),
        color: Colors.white.withOpacity(0.08),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF1A1C2A),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          style: const TextStyle(color: Colors.white, fontSize: 12),
          onChanged: onChanged,
          items: items.map((String item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _filterTransactions(String filter) async {
    try {
      DateTime now = DateTime.now();
      DateTime startDate;

      switch (filter) {
        case "Today":
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case "This Week":
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case "This Month":
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(2000, 1, 1);
      }

      final results = await Future.wait([
        supabase
            .from('invoices')
            .select('id, client_name, amount, date_issued, status')
            .gte('date_issued', startDate.toIso8601String())
            .order('date_issued', ascending: false)
            .limit(5),
        supabase
            .from('expenses')
            .select('id, amount, description, vendor_name, date_incurred, category_name')
            .gte('date_incurred', startDate.toIso8601String())
            .order('date_incurred', ascending: false)
            .limit(5),
      ]);

      final invoices = results[0] as List;
      final expensesData = results[1] as List;

      final List<Map<String, dynamic>> filtered = [];

      for (var inv in invoices) {
        filtered.add({
          'id': inv['id'],
          'title': inv['client_name'] ?? 'Client',
          'subtitle': 'Invoice #${inv['id']}',
          'amount': '₹${NumberFormat('#,##0').format(inv['amount'] ?? 0)}',
          'isExpense': false,
          'date': DateTime.parse(inv['date_issued']),
        });
      }

      for (var exp in expensesData) {
        filtered.add({
          'id': exp['id'],
          'title': exp['description'] ?? exp['vendor_name'] ?? 'Expense',
          'subtitle': exp['category_name'] ?? 'Expense',
          'vendor': exp['vendor_name'],
          'amount': '-₹${NumberFormat('#,##0').format(exp['amount'] ?? 0)}',
          'isExpense': true,
          'date': DateTime.parse(exp['date_incurred']),
        });
      }

      filtered.sort((a, b) => b['date'].compareTo(a['date']));

      if (mounted) {
        setState(() => recentTransactions = filtered.take(4).toList());
      }
    } catch (e) {
      print('Error filtering transactions: $e');
    }
  }

  Widget _transactionTile(
      String title,
      String subtitle,
      String amount, {
        String? vendor,
        bool isExpense = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isExpense
                ? Colors.red.withOpacity(0.15)
                : Colors.green.withOpacity(0.15),
          ),
          child: Icon(
            isExpense ? Icons.arrow_upward : Icons.arrow_downward,
            size: 18,
            color: isExpense ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
              if (vendor != null)
                Text(
                  vendor,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
            ],
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isExpense ? Colors.red : Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _analyticsSection() {
    double maxValue = _analyticsData.isEmpty ? 10000 : _analyticsData.reduce((a, b) => a > b ? a : b);
    double minValue = _analyticsData.isEmpty ? -10000 : _analyticsData.reduce((a, b) => a < b ? a : b);
    double range = maxValue - minValue;
    double safeMax = maxValue + range * 0.1;
    double safeMin = minValue - range * 0.1;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Profit/Loss Analytics",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              _buildFilterDropdown(
                value: _analyticsFilter,
                items: _analyticsFilters,
                onChanged: (value) async {
                  if (value == "Custom") {
                    await _showCustomRangeDialog(
                      title: "Select Date Range for Analytics",
                      onConfirm: (start, end) {
                        setState(() {
                          _analyticsFilter = "Custom";
                          _analyticsCustomStart = start;
                          _analyticsCustomEnd = end;
                          _applyAnalyticsFilter();
                        });
                      },
                    );
                  } else {
                    setState(() {
                      _analyticsFilter = value!;
                      _analyticsCustomStart = null;
                      _analyticsCustomEnd = null;
                      _applyAnalyticsFilter();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Net Profit/Loss",
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 6),
          Text(
            "₹${NumberFormat('#,##0').format(_analyticsData.fold(0.0, (a, b) => a + b))}",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: safeMin,
                maxY: safeMax,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: range / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.15),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "₹${(value / 1000).toStringAsFixed(0)}K",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _analyticsMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _analyticsMonths[index],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: const Color(0xFF1F2937),
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        return LineTooltipItem(
                          "₹${spot.y.toStringAsFixed(0)}",
                          TextStyle(
                            color: spot.y >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(_analyticsMonths.length, (index) {
                      return FlSpot(index.toDouble(), _analyticsData[index]);
                    }),
                    isCurved: true,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    gradient: const LinearGradient(
                      colors: [Color(0xffA78BFA), Color(0xff6366F1)],
                    ),
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xff6366F1).withOpacity(0.3),
                          const Color(0xffA78BFA).withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
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

  Widget _monthlyTrendSection() {
    double maxValue = _monthlyTrendData.isEmpty ? 10000 : _monthlyTrendData.reduce((a, b) => a > b ? a : b);
    double safeMax = maxValue * 1.2;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Monthly Earnings Trend",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              _buildFilterDropdown(
                value: _monthlyTrendFilter,
                items: _monthlyTrendFilters,
                onChanged: (value) async {
                  if (value == "Custom") {
                    await _showCustomRangeDialog(
                      title: "Select Date Range for Monthly Trend",
                      onConfirm: (start, end) {
                        setState(() {
                          _monthlyTrendFilter = "Custom";
                          _monthlyTrendCustomStart = start;
                          _monthlyTrendCustomEnd = end;
                          _applyMonthlyTrendFilter();
                        });
                      },
                    );
                  } else {
                    setState(() {
                      _monthlyTrendFilter = value!;
                      _monthlyTrendCustomStart = null;
                      _monthlyTrendCustomEnd = null;
                      _applyMonthlyTrendFilter();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceBetween,
                maxY: safeMax,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: const Color(0xFF1F2937),
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.all(10),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "₹${rod.toY.toStringAsFixed(0)}",
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: safeMax / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.15),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "₹${(value / 1000).toStringAsFixed(0)}K",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _monthlyTrendMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _monthlyTrendMonths[index],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barGroups: List.generate(_monthlyTrendMonths.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 6,
                    barRods: [
                      BarChartRodData(
                        toY: _monthlyTrendData[index],
                        width: 14,
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFA78BFA), Color(0xFF6366F1)],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientRevenueSection() {
    List<Map<String, dynamic>> data = _getClientRevenueData();
    double total = data.fold<double>(0, (sum, item) => sum + item['value']);

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Client Revenue Distribution",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                centerSpaceRadius: 60,
                sectionsSpace: 4,
                sections: data.map((item) {
                  return PieChartSectionData(
                    value: item['value'],
                    color: item['color'],
                    showTitle: false,
                    radius: 60,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: data.map((item) {
              double percentage = total == 0 ? 0 : (item['value'] / total) * 100;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: item['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "${item['name']} (${percentage.toStringAsFixed(1)}%)",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getClientRevenueData() {
    List<Map<String, dynamic>> result = [];
    List<Color> colors = const [
      Color(0xff6C63FF),
      Color(0xff2DD4BF),
      Color(0xffF59E0B),
      Color(0xffEF4444),
    ];

    int index = 0;
    clientRevenue.forEach((name, value) {
      if (index < colors.length && value > 0) {
        result.add({"name": name, "value": value, "color": colors[index]});
      }
      index++;
    });

    if (result.isEmpty) {
      result = [
        {"name": "Sample Client", "value": 7500.0, "color": const Color(0xff6C63FF)},
        {"name": "Another Client", "value": 2500.0, "color": const Color(0xff2DD4BF)},
      ];
    }

    return result;
  }

  Widget _incomeExpenseReport() {
    double maxValue = 0;
    for (int i = 0; i < _incomeExpenseMonths.length; i++) {
      if (_incomeChartData[i] > maxValue) maxValue = _incomeChartData[i];
      if (_expenseChartData[i] > maxValue) maxValue = _expenseChartData[i];
    }
    double safeMax = maxValue == 0 ? 10000 : maxValue * 1.3;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Income vs Expenses",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              _buildFilterDropdown(
                value: _incomeExpenseFilter,
                items: _incomeExpenseFilters,
                onChanged: (value) async {
                  if (value == "Custom") {
                    await _showCustomRangeDialog(
                      title: "Select Date Range for Income vs Expenses",
                      onConfirm: (start, end) {
                        setState(() {
                          _incomeExpenseFilter = "Custom";
                          _incomeExpenseCustomStart = start;
                          _incomeExpenseCustomEnd = end;
                          _applyIncomeExpenseFilter();
                        });
                      },
                    );
                  } else {
                    setState(() {
                      _incomeExpenseFilter = value!;
                      _incomeExpenseCustomStart = null;
                      _incomeExpenseCustomEnd = null;
                      _applyIncomeExpenseFilter();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Legend(color: Colors.greenAccent, text: "Income"),
              SizedBox(width: 24),
              _Legend(color: Colors.redAccent, text: "Expenses"),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                backgroundColor: Colors.transparent,
                maxY: safeMax,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: safeMax / 5,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.08),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: const Color(0xFF1F2937),
                    tooltipRoundedRadius: 12,
                    tooltipPadding: const EdgeInsets.all(10),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        "₹${rod.toY.toStringAsFixed(0)}",
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      interval: safeMax / 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "₹${value.toInt()}",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < _incomeExpenseMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _incomeExpenseMonths[index],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barGroups: List.generate(_incomeExpenseMonths.length, (index) {
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 6,
                    barRods: [
                      BarChartRodData(
                        toY: _incomeChartData[index],
                        width: 10,
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [Colors.greenAccent, Colors.green],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      BarChartRodData(
                        toY: _expenseChartData[index],
                        width: 10,
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [Colors.redAccent, Colors.red],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomRangeDialog({
    required String title,
    required Function(DateTime start, DateTime end) onConfirm,
  }) async {

    DateTime? startDate;
    DateTime? endDate;
    DateTime now = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {

        return StatefulBuilder(
          builder: (context, setModalState) {

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// drag handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),

                        /// title
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// start date
                        _dateField(
                          label: "Start Date",
                          value: startDate,
                          onTap: () async {

                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ??
                                  now.subtract(const Duration(days: 30)),
                              firstDate: DateTime(now.year - 2),
                              lastDate: now,
                            );

                            if (picked != null) {
                              setModalState(() {
                                startDate = picked;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        /// end date
                        _dateField(
                          label: "End Date",
                          value: endDate,
                          onTap: () async {

                            DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? now,
                              firstDate: startDate ?? DateTime(now.year - 2),
                              lastDate: now,
                            );

                            if (picked != null) {
                              setModalState(() {
                                endDate = picked;
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 26),

                        /// buttons
                        Row(
                          children: [

                            /// cancel
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                            ),

                            const SizedBox(width: 12),

                            /// apply
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: const Color(0xFF6366F1),
                                ),
                                onPressed: () {

                                  if (startDate == null || endDate == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Select both dates"),
                                      ),
                                    );
                                    return;
                                  }

                                  if (endDate!.isBefore(startDate!)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "End date must be after start date"),
                                      ),
                                    );
                                    return;
                                  }

                                  onConfirm(startDate!, endDate!);
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  "Apply",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 6),

        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 14,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.06),
              border: Border.all(
                color: Colors.white.withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                Text(
                  value != null
                      ? DateFormat('dd MMM yyyy').format(value)
                      : "Select date",
                  style: TextStyle(
                    color: value != null
                        ? Colors.white
                        : Colors.white54,
                  ),
                ),

                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.white70,
                ),

              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCards() {
    double income = _overviewIncome;
    double expenses = _overviewExpenses;
    double profit = income - expenses;
    double margin = income > 0 ? (profit / income) * 100 : 0;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Overview",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              _buildFilterDropdown(
                value: _overviewFilter,
                items: _overviewFilters,
                onChanged: (value) async {
                  if (value == "Custom") {
                    await _showCustomRangeDialog(
                      title: "Select Date Range for Overview",
                      onConfirm: (start, end) {
                        setState(() {
                          _overviewFilter = "Custom";
                          _overviewCustomStart = start;
                          _overviewCustomEnd = end;
                          _applyOverviewFilter();
                        });
                      },
                    );
                  } else {
                    setState(() {
                      _overviewFilter = value!;
                      _overviewCustomStart = null;
                      _overviewCustomEnd = null;
                      _applyOverviewFilter();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _squareStatCard(
                  value: "₹${NumberFormat('#,##0').format(income)}",
                  label: "Income",
                  color: Colors.greenAccent,
                  icon: Icons.trending_up,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _squareStatCard(
                  value: "₹${NumberFormat('#,##0').format(expenses)}",
                  label: "Expenses",
                  color: Colors.redAccent,
                  icon: Icons.trending_down,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _squareStatCard(
                  value: "₹${NumberFormat('#,##0').format(profit)}",
                  label: "Profit",
                  color: Colors.blueAccent,
                  icon: Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _squareStatCard(
                  value: "${margin.toStringAsFixed(1)}%",
                  label: "Margin",
                  color: Colors.purpleAccent,
                  icon: Icons.percent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _squareStatCard({
    required String value,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      height: 140, // FIXED HEIGHT
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.14),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 25,
                  spreadRadius: 1,
                  offset: const Offset(0, 12),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.9),
                        color.withOpacity(0.5),
                      ],
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: Colors.white,
                  ),
                ),

                const Spacer(),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _recentInvoicesSection() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Invoices",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoiceDashboardScreen()),
                  ).then((_) {
                    if (mounted) _loadRecentInvoices();
                  });
                },
                child: const Text(
                  "View All →",
                  style: TextStyle(color: Colors.blueAccent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (recentInvoices.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "No invoices yet",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            )
          else
            ...recentInvoices.take(3).map((inv) => _invoiceTile(inv)).toList(),
        ],
      ),
    );
  }

  Widget _invoiceTile(dynamic inv) {
    final status = inv['status']?.toString().toUpperCase() ?? 'DRAFT';

    Color getStatusColor() {
      switch (status) {
        case 'PAID':
          return const Color(0xFF22C55E);
        case 'OVERDUE':
          return const Color(0xFFEF4444);
        case 'DRAFT':
          return const Color(0xFF6B7280);
        default:
          return const Color(0xFFF59E0B);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv['client_name'] ?? 'Client',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invoice #${inv['id']}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₹${NumberFormat('#,##0').format(inv['amount'] ?? 0)}",
                style: const TextStyle(
                  color: Color(0xFF5B8CFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getStatusColor().withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: getStatusColor(),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadRecentInvoices() async {
    try {
      final service = invoice_service.SupabaseService();
      final invoices = await service.getRecentInvoices(limit: 5);
      if (mounted) {
        setState(() => recentInvoices = invoices);
      }
    } catch (e) {
      print('Error loading recent invoices: $e');
    }
  }

  Widget _overviewSection() {
    double balance = balanceSummary['current_balance']?.toDouble() ?? 800000;
    double income = balanceSummary['total_earnings']?.toDouble() ?? 1250000;
    double expenses = balanceSummary['total_expenses']?.toDouble() ?? 450000;
    double netProfit = income - expenses;

    return _netBalanceCard(balance, income, expenses, netProfit);
  }

  Widget _netBalanceCard(
      double balance,
      double income,
      double expenses,
      double netProfit,
      ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              colors: [
                const Color(0xff312E81).withOpacity(0.85),
                const Color(0xff0F172A).withOpacity(0.85),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "NET BALANCE",
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w500,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "₹${NumberFormat('#,##0').format(balance)}",
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _miniStatCard(
                      title: "INCOME",
                      value: "₹${NumberFormat.compact().format(income)}",
                      icon: Icons.trending_up,
                      color: const Color(0xff22c55e),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _miniStatCard(
                      title: "EXPENSES",
                      value: "₹${NumberFormat.compact().format(expenses)}",
                      icon: Icons.trending_down,
                      color: const Color(0xffef4444),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _miniStatCard(
                      title: "NET PROFIT",
                      value: "₹${NumberFormat.compact().format(netProfit)}",
                      icon: Icons.account_balance_wallet,
                      color: const Color(0xff3b82f6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentTabs() {
    final tabs = ["Overview", "Transactions", "Invoices", "Analytics"];

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        borderRadius: BorderRadius.circular(40),
        color: const Color(0xFF1E293B).withOpacity(0.6),
      ),
      child: TabBar(
        controller: _segmentTabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          ),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        tabs: tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _quickActionsGrid() {
    return GridView.count(
      crossAxisCount: 4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.85,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _GlassAction(
          icon: Icons.add,
          label: "Expense",
          gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
          onTap: () => setState(() => _currentIndex = 1),
        ),
        _GlassAction(
          icon: Icons.receipt_long,
          label: "Invoice",
          gradient: const [Color(0xFF43CEA2), Color(0xFF185A9D)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceDashboardScreen()),
            );
          },
        ),
        _GlassAction(
          icon: Icons.mic,
          label: "Voice AI",
          gradient: const [Color(0xFFFF512F), Color(0xFFDD2476)],
          onTap: () => setState(() => _currentIndex = 2),
        ),
        _GlassAction(
          icon: Icons.pie_chart_outline,
          label: "Budget",
          gradient: const [Color(0xFF11998E), Color(0xFF38EF7D)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BudgetTrackingScreen()),
            );
          },
        ),
        _GlassAction(
          icon: Icons.people_outline,
          label: "Clients",
          gradient: const [Color(0xFFFF9966), Color(0xFFFF5E62)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientManagementScreen()),
            );
          },
        ),
        _GlassAction(
          icon: Icons.trending_up,
          label: "Invest",
          gradient: const [Color(0xFF00C6FF), Color(0xFF0072FF)],
          onTap: () => setState(() => _currentIndex = 3),
        ),
        _GlassAction(
          icon: Icons.analytics_outlined,
          label: "Business",
          gradient: const [Color(0xFFFC4A1A), Color(0xFFF7B733)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const BusinessAnalyticsScreen(),
              ),
            );
          },
        ),
        _GlassAction(
          icon: Icons.calculate_outlined,
          label: "Tax",
          gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TaxCalculatorScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: child,
    );
  }

  Widget _liquidBlob({
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

class _GlassAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final List<Color> gradient;

  const _GlassAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: gradient),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}