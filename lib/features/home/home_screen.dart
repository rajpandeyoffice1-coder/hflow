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
  static const double _topBarHeight = 84;

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
  Map<String, double> analyticsData = {};
  Map<String, double> clientRevenue = {};
  Map<String, double> monthlyTrend = {};
  Map<String, double> previousPeriodSummary = {
    'balance': 0,
    'income': 0,
    'expenses': 0,
  };
  double expectedIncome = 0;
  List<String> _lastSixMonthLabels = [];

  bool isLoading = true;
  String userName = "Raj";

  String _selectedFilter = "All Time";
  String _selectedFilterAnalytic = "6 months";
  final List<String> _filters = ["Week", "Month", "6 months", "Year"];
  String _selectedTrend = "Monthly";
  final List<String> _trendOptions = ["Daily", "Monthly", "Yearly"];

  List<String> _months = [];

  List<double> _incomeData = List.filled(12, 0);
  List<double> _expenseData = List.filled(12, 0);

  int _selectedSegmentIndex = 0;
  late TabController _segmentTabController;

  @override
  void initState() {
    super.initState();
    _segmentTabController = TabController(length: 4, vsync: this);
    _segmentTabController.addListener(() {
      if (_segmentTabController.indexIsChanging) {
        setState(() {
          _selectedSegmentIndex = _segmentTabController.index;
        });
      }
    });
    loadUserData();
    loadDashboardData();
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
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (settings != null) {
        setState(() {
          userSettings = settings;
          userName =
              settings['profile_name'] ??
              settings['profile_email'] ??
              "Raj.p@urbanites.in";
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> loadDashboardData() async {
    setState(() => isLoading = true);
    try {
      final userId = supabase.auth.currentUser?.id ?? 'default_user';

      final summary = await supabase
          .from('balance_summary')
          .select()
          .order('last_calculated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (summary != null) {
        setState(() {
          balanceSummary = summary;
        });
      }

      final invoices = await supabase
          .from('invoices')
          .select('id, client_name, amount, date_issued, status, client_id')
          .order('date_issued', ascending: false)
          .limit(10);

      final expensesData = await supabase
          .from('expenses')
          .select(
            'id, amount, description, date_incurred, category_name, vendor_name',
          )
          .order('date_incurred', ascending: false)
          .limit(10);

      final clients = await supabase
          .from('clients')
          .select('id, name, total_invoices, total_amount')
          .order('total_amount', ascending: false)
          .limit(5);

      final investments = await supabase
          .from('investments')
          .select('id, amount, date, category_id, sub_category_id')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(5);

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final firstDayOfPreviousMonth = DateTime(now.year, now.month - 1, 1);

      final monthlyIncome = await supabase
          .from('invoices')
          .select('amount')
          .gte('date_issued', firstDayOfMonth.toIso8601String())
          .eq('status', 'Paid');

      final monthlyExpenses = await supabase
          .from('expenses')
          .select('amount')
          .gte('date_incurred', firstDayOfMonth.toIso8601String());

      final previousMonthIncome = await supabase
          .from('invoices')
          .select('amount')
          .gte('date_issued', firstDayOfPreviousMonth.toIso8601String())
          .lt('date_issued', firstDayOfMonth.toIso8601String())
          .eq('status', 'Paid');

      final previousMonthExpenses = await supabase
          .from('expenses')
          .select('amount')
          .gte('date_incurred', firstDayOfPreviousMonth.toIso8601String())
          .lt('date_incurred', firstDayOfMonth.toIso8601String());

      final expectedIncomeInvoices = await supabase
          .from('invoices')
          .select('amount, status')
          .inFilter('status', ['Pending', 'Draft']);

      final chartStartMonth = DateTime(now.year, now.month - 5, 1);
      final paidInvoicesForCharts = await supabase
          .from('invoices')
          .select('amount, date_issued, status')
          .gte('date_issued', chartStartMonth.toIso8601String())
          .eq('status', 'Paid');

      final expensesForCharts = await supabase
          .from('expenses')
          .select('amount, date_incurred')
          .gte('date_incurred', chartStartMonth.toIso8601String());

      double incomeSum = 0;
      for (var inv in monthlyIncome) {
        incomeSum += (inv['amount'] as num).toDouble();
      }

      double expenseSum = 0;
      for (var exp in monthlyExpenses) {
        expenseSum += (exp['amount'] as num).toDouble();
      }

      double previousIncomeSum = 0;
      for (var inv in previousMonthIncome) {
        previousIncomeSum += (inv['amount'] as num).toDouble();
      }

      double previousExpenseSum = 0;
      for (var exp in previousMonthExpenses) {
        previousExpenseSum += (exp['amount'] as num).toDouble();
      }

      double expectedIncomeAmount = 0;
      for (var inv in expectedIncomeInvoices) {
        expectedIncomeAmount += (inv['amount'] as num).toDouble();
      }

      final monthLabels = List<String>.generate(6, (index) {
        final month = DateTime(chartStartMonth.year, chartStartMonth.month + index, 1);
        return DateFormat('MMM').format(month);
      });
      final monthlyIncomeSeries = List<double>.filled(6, 0);
      final monthlyExpenseSeries = List<double>.filled(6, 0);

      for (var invoice in paidInvoicesForCharts) {
        final issuedDate = DateTime.parse(invoice['date_issued']);
        final monthIndex = (issuedDate.year - chartStartMonth.year) * 12 +
            issuedDate.month -
            chartStartMonth.month;
        if (monthIndex >= 0 && monthIndex < 6) {
          monthlyIncomeSeries[monthIndex] +=
              (invoice['amount'] as num).toDouble();
        }
      }

      for (var expense in expensesForCharts) {
        final incurredDate = DateTime.parse(expense['date_incurred']);
        final monthIndex = (incurredDate.year - chartStartMonth.year) * 12 +
            incurredDate.month -
            chartStartMonth.month;
        if (monthIndex >= 0 && monthIndex < 6) {
          monthlyExpenseSeries[monthIndex] +=
              (expense['amount'] as num).toDouble();
        }
      }

      _incomeData = List<double>.filled(12, 0);
      _expenseData = List<double>.filled(12, 0);
      for (int i = 0; i < 6; i++) {
        _incomeData[i] = monthlyIncomeSeries[i];
        _expenseData[i] = monthlyExpenseSeries[i];
      }

      final List<Map<String, dynamic>> transactions = [];

      for (var inv in invoices) {
        transactions.add({
          'id': inv['id'],
          'title': inv['client_name'],
          'subtitle': 'Invoice #${inv['id']}',
          'amount': '₹${NumberFormat('#,##0').format(inv['amount'])}',
          'isExpense': false,
          'date': DateTime.parse(inv['date_issued']),
        });
      }

      for (var exp in expensesData) {
        transactions.add({
          'id': exp['id'],
          'title': exp['vendor_name'] ?? exp['description'],
          'subtitle': exp['category_name'] ?? 'Expense',
          'amount': '-₹${NumberFormat('#,##0').format(exp['amount'])}',
          'isExpense': true,
          'date': DateTime.parse(exp['date_incurred']),
        });
      }

      transactions.sort((a, b) => b['date'].compareTo(a['date']));

      setState(() {
        recentInvoices = invoices;
        expenses = expensesData;
        recentTransactions = transactions.take(10).toList();
        clientRevenue = {
          for (var client in clients)
            client['name']: (client['total_amount'] as num).toDouble(),
        };
        expectedIncome = expectedIncomeAmount;
        previousPeriodSummary = {
          'balance': previousIncomeSum - previousExpenseSum,
          'income': previousIncomeSum,
          'expenses': previousExpenseSum,
        };
        _lastSixMonthLabels = monthLabels;
        _months = monthLabels;
        balanceSummary['current_balance'] = incomeSum - expenseSum;
        balanceSummary['total_earnings'] = incomeSum;
        balanceSummary['total_expenses'] = expenseSum;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
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
                            userName.split('@')[0][0].toUpperCase(),
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
                top: _currentIndex == 0 ? _topBarHeight - 10 : 0,
              ),
              child: SafeArea(
                child: IndexedStack(
                  index: _currentIndex,
                  children: [
                    _homeContent(),
                    ExpenseScreen(
                      onBack: () => setState(() => _currentIndex = 0),
                    ),
                    const AiAssistantScreen(),
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
        bottomNavigationBar: GlassBottomNav(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }

  Widget _homeContent() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            "${_timeBasedGreeting()}, ${userName.split('@')[0]}!",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('EEEE, MMM d, y').format(DateTime.now()),
            style: const TextStyle(color: Colors.white54),
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
          _quickActionButtons(),
          const SizedBox(height: 12),
          _quickActionsGrid(),
          const SizedBox(height: 22),
          _segmentTabs(),
          const SizedBox(height: 22),
          _buildSegmentContent(),
        ],
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
              _filterDropdown(),
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
            ...recentTransactions
                .map(
                  (tx) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _transactionTile(
                      tx['title'],
                      tx['subtitle'],
                      tx['amount'],
                      DateFormat('dd MMM y').format(tx['date'] as DateTime),
                      isExpense: tx['isExpense'],
                    ),
                  ),
                )
                .toList(),
        ],
      ),
    );
  }

  Widget _filterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1), width: 1.2),
        color: Colors.white.withOpacity(0.08),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          dropdownColor: const Color(0xFF1A1C2A),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            setState(() {
              _selectedFilter = value!;
            });
            _filterTransactions(value!);
          },
          items: const [
            DropdownMenuItem(value: "All Time", child: Text("All Time")),
            DropdownMenuItem(value: "Today", child: Text("Today")),
            DropdownMenuItem(value: "This Week", child: Text("This Week")),
            DropdownMenuItem(value: "This Month", child: Text("This Month")),
          ],
        ),
      ),
    );
  }

  Future<void> _filterTransactions(String filter) async {
    setState(() => isLoading = true);
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

      final invoices = await supabase
          .from('invoices')
          .select('id, client_name, amount, date_issued, status')
          .gte('date_issued', startDate.toIso8601String())
          .order('date_issued', ascending: false)
          .limit(5);

      final expensesData = await supabase
          .from('expenses')
          .select('id, amount, description, date_incurred, category_name')
          .gte('date_incurred', startDate.toIso8601String())
          .order('date_incurred', ascending: false)
          .limit(5);

      final List<Map<String, dynamic>> filtered = [];

      for (var inv in invoices) {
        filtered.add({
          'id': inv['id'],
          'title': inv['client_name'],
          'subtitle': 'Invoice #${inv['id']}',
          'amount': '₹${NumberFormat('#,##0').format(inv['amount'])}',
          'isExpense': false,
          'date': DateTime.parse(inv['date_issued']),
        });
      }

      for (var exp in expensesData) {
        filtered.add({
          'id': exp['id'],
          'title': exp['description'],
          'subtitle': exp['category_name'] ?? 'Expense',
          'amount': '-₹${NumberFormat('#,##0').format(exp['amount'])}',
          'isExpense': true,
          'date': DateTime.parse(exp['date_incurred']),
        });
      }

      filtered.sort((a, b) => b['date'].compareTo(a['date']));

      setState(() {
        recentTransactions = filtered.take(10).toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error filtering transactions: $e');
      setState(() => isLoading = false);
    }
  }

  Widget _transactionTile(
    String title,
    String subtitle,
    String amount,
    String date, {
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
              const SizedBox(height: 2),
              Text(
                date,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
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
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Analytics",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilterAnalytic,
                    dropdownColor: const Color(0xff1C1C1E),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white70,
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: _filters.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFilterAnalytic = value!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Expected income",
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 6),
          Text(
            "₹${NumberFormat('#,##0').format(expectedIncome)}",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "₹${(value / 1000).toStringAsFixed(1)}K",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getChartData(),
                    isCurved: true,
                    color: const Color(0xff6C63FF),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                minY: 0,
                maxY: _getMaxChartValue(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxChartValue() {
    double max = 0;
    for (var spot in _getChartData()) {
      if (spot.y > max) max = spot.y;
    }
    return max + 1000;
  }

  List<FlSpot> _getChartData() {
    return List.generate(
      6,
      (index) => FlSpot(index.toDouble(), _incomeData[index]),
    );
  }

  Widget _monthlyTrendSection() {
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedTrend,
                    dropdownColor: const Color(0xff1C1C1E),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white70,
                    ),
                    style: const TextStyle(color: Colors.white),
                    items: _trendOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTrend = value!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxBarValue(),
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1000,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.08),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "₹${(value / 1000).toStringAsFixed(0)}K",
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
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index < _lastSixMonthLabels.length) {
                          return Text(
                            _lastSixMonthLabels[index],
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          );
                        }
                        return const Text('');
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
                barGroups: List.generate(6, (index) => _barData(index, _incomeData[index])),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxBarValue() {
    double max = 0;
    for (int i = 0; i < 6; i++) {
      if (i < _incomeData.length && _incomeData[i] > max) {
        max = _incomeData[i];
      }
    }
    return max > 0 ? max + 1000 : 10000;
  }

  BarChartGroupData _barData(int x, double value) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 14,
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xff6C63FF),
        ),
      ],
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
              double percentage = total == 0
                  ? 0
                  : (item['value'] / total) * 100;
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
    List<Color> colors = [
      const Color(0xff6C63FF),
      const Color(0xff2DD4BF),
      const Color(0xffF59E0B),
      const Color(0xffEF4444),
    ];

    int index = 0;
    clientRevenue.forEach((name, value) {
      if (index < colors.length) {
        result.add({"name": name, "value": value, "color": colors[index]});
      }
      index++;
    });

    if (result.isEmpty) {
      result = [
        {
          "name": "Sample Client",
          "value": 7500.0,
          "color": const Color(0xff6C63FF),
        },
        {
          "name": "Another Client",
          "value": 2500.0,
          "color": const Color(0xff2DD4BF),
        },
      ];
    }

    return result;
  }

  Widget _incomeExpenseReport() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.bar_chart_rounded, color: Colors.white70, size: 20),
              SizedBox(width: 8),
              Text(
                "Income vs Expenses (Last 6 Months)",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
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
                maxY: _getMaxIncomeExpenseValue(),
                alignment: BarChartAlignment.center,
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 1000,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.08),
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
                        if (index < _months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _months[index],
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white54,
                              ),
                            ),
                          );
                        }
                        return const Text('');
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
                barGroups: List.generate(6, (index) {
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 6,
                    barRods: [
                      if (_incomeData[index] > 0)
                        BarChartRodData(
                          toY: _incomeData[index],
                          width: 14,
                          borderRadius: BorderRadius.circular(8),
                          gradient: const LinearGradient(
                            colors: [Colors.greenAccent, Colors.green],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      if (_expenseData[index] > 0)
                        BarChartRodData(
                          toY: _expenseData[index],
                          width: 14,
                          borderRadius: BorderRadius.circular(8),
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

  double _getMaxIncomeExpenseValue() {
    double max = 0;
    for (int i = 0; i < 6; i++) {
      if (_incomeData[i] > max) max = _incomeData[i];
      if (_expenseData[i] > max) max = _expenseData[i];
    }
    return max > 0 ? max + 1000 : 5000;
  }

  Widget _summaryCards() {
    final income = (balanceSummary['total_earnings'] as num?)?.toDouble() ?? 0;
    final totalExpenses =
        (balanceSummary['total_expenses'] as num?)?.toDouble() ?? 0;
    final balance = income - totalExpenses;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _overviewCard(
                "Balance",
                "₹${NumberFormat('#,##0').format(balance)}",
                _formatChange(balance, previousPeriodSummary['balance'] ?? 0),
                isLarge: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _overviewCard(
                "Income",
                "₹${NumberFormat('#,##0').format(income)}",
                _formatChange(income, previousPeriodSummary['income'] ?? 0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _overviewCard(
                "Expenses",
                "₹${NumberFormat('#,##0').format(totalExpenses)}",
                _formatChange(
                  totalExpenses,
                  previousPeriodSummary['expenses'] ?? 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _squareStatCard({
    required String value,
    required String label,
    required Color color,
  }) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
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
                    MaterialPageRoute(
                      builder: (_) => const InvoiceDashboardScreen(),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _loadRecentInvoices();
                    }
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
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    Colors.white.withOpacity(0.1),
                  ),
                  dataRowColor: MaterialStateProperty.all(Colors.transparent),
                  headingTextStyle: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  dataTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  columns: const [
                    DataColumn(label: Text('Invoice #')),
                    DataColumn(label: Text('Client')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: recentInvoices.isEmpty
                      ? [
                          DataRow(
                            cells: [
                              DataCell(Container()),
                              DataCell(Container()),
                              DataCell(Container()),
                              DataCell(Container()),
                              DataCell(Container()),
                              DataCell(Container()),
                            ],
                          ),
                        ]
                      : recentInvoices.take(5).map((inv) {
                          final status =
                              inv['status']?.toString().toUpperCase() ??
                              'DRAFT';

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

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  inv['id']?.toString() ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(
                                Text(
                                  inv['client_name']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              DataCell(
                                Text(
                                  "₹${NumberFormat('#,##0.00').format(inv['amount'] ?? 0)}",
                                  style: const TextStyle(
                                    color: Color(0xFF5B8CFF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(DateTime.parse(inv['date_issued'])),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: getStatusColor().withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: getStatusColor().withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: getStatusColor(),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => InvoiceDetailScreen(
                                              invoice: inv,
                                            ),
                                          ),
                                        ).then((_) => _loadRecentInvoices());
                                      },
                                      icon: Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => CreateInvoiceScreen(
                                              invoiceToEdit: inv,
                                            ),
                                          ),
                                        ).then((result) {
                                          if (result == true) {
                                            _loadRecentInvoices();
                                          }
                                        });
                                      },
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                ),
              ),
            ),
          ),
          if (recentInvoices.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: Text(
                  "No invoices yet",
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadRecentInvoices() async {
    try {
      final supabase = invoice_service.SupabaseService();
      final invoices = await supabase.getRecentInvoices(limit: 5);
      if (mounted) {
        setState(() {
          recentInvoices = invoices;
        });
      }
    } catch (e) {
      print('Error loading recent invoices: $e');
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    List<String> parts = name.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Widget _invoiceHeader() {
    return Row(
      children: const [
        SizedBox(width: 120, child: _HeaderText("INVOICE #")),
        SizedBox(width: 220, child: _HeaderText("CLIENT")),
        SizedBox(width: 120, child: _HeaderText("AMOUNT")),
        SizedBox(width: 120, child: _HeaderText("DATE")),
        SizedBox(width: 120, child: _HeaderText("STATUS")),
        SizedBox(width: 200, child: _HeaderText("ACTIONS")),
      ],
    );
  }

  Widget _overviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _summaryCards(),
        const SizedBox(height: 16),
        _glassCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Expected Income",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                "₹${NumberFormat('#,##0').format(expectedIncome)}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _timeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _formatChange(double current, double previous) {
    if (previous == 0) {
      if (current == 0) return '0.0%';
      return '+100.0%';
    }
    final change = ((current - previous) / previous) * 100;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}%';
  }

  Widget _overviewCard(
    String title,
    String amount,
    String percent, {
    bool isLarge = false,
  }) {
    bool isNegative = percent.contains("-");
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isLarge ? 22 : 18,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E293B).withOpacity(0.6),
                const Color(0xFF0F172A).withOpacity(0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
              const SizedBox(height: 8),
              Text(
                amount,
                style: TextStyle(
                  fontSize: isLarge ? 24 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isNegative ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 14,
                    color: isNegative ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    percent,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isNegative ? Colors.red : Colors.green,
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
                const Color(0xFF1E1B4B).withOpacity(0.8),
                const Color(0xFF0F172A).withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "NET BALANCE",
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "₹${NumberFormat('#,##0').format(balance)}",
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _pill(
                    icon: Icons.arrow_upward,
                    text: "+12%",
                    color: Colors.greenAccent,
                    bgColor: Colors.green.withOpacity(0.15),
                  ),
                  const SizedBox(width: 12),
                  _pill(
                    text: "64% Margin",
                    color: const Color(0xFFB794F4),
                    bgColor: const Color(0xFFB794F4).withOpacity(0.15),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _miniStatCard(
                      "INCOME",
                      "₹${NumberFormat.compact().format(income)}",
                      "+4%",
                      isPositive: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _miniStatCard(
                      "EXPENSES",
                      "₹${NumberFormat.compact().format(expenses)}",
                      "-2%",
                      isPositive: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _miniStatCard(
                      "NET PROFIT",
                      "₹${NumberFormat.compact().format(netProfit)}",
                      "All time",
                      isLabelOnly: true,
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

  Widget _pill({
    IconData? icon,
    required String text,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatCard(
    String title,
    String value,
    String bottomText, {
    bool isPositive = true,
    bool isLabelOnly = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white54,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bottomText,
            style: TextStyle(
              fontSize: 11,
              color: isLabelOnly
                  ? Colors.white38
                  : (isPositive ? Colors.green : Colors.red),
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
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        tabs: tabs.map((tab) => Tab(text: tab)).toList(),
      ),
    );
  }

  Widget _tabItem(String title, {bool isActive = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                )
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.white54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _invoiceRow({
    required String id,
    required String client,
    required String initials,
    required String amount,
    required String date,
    required bool paid,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              id,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: paid
                          ? [Colors.pinkAccent, Colors.purpleAccent]
                          : [Colors.greenAccent, Colors.teal],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    client,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              amount,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(date, style: const TextStyle(color: Colors.white70)),
          ),
          SizedBox(
            width: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: paid
                    ? Colors.green.withOpacity(0.15)
                    : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                paid ? "● PAID" : "● PENDING",
                style: TextStyle(
                  fontSize: 11,
                  color: paid ? Colors.greenAccent : Colors.orangeAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 200,
            child: Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _actionButton(Icons.visibility, Colors.blueAccent),
                  const SizedBox(width: 8),
                  _actionButton(Icons.edit, Colors.orangeAccent),
                  const SizedBox(width: 8),
                  _actionButton(Icons.download, Colors.greenAccent),
                  const SizedBox(width: 8),
                  _actionButton(Icons.delete, Colors.redAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _quickActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
              ).then((_) => loadDashboardData());
            },
            icon: const Icon(Icons.receipt_long),
            label: const Text('New Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseScreen()),
              ).then((_) => loadDashboardData());
            },
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('New Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
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
          gradient: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          onTap: () => setState(() => _currentIndex = 1),
        ),
        _GlassAction(
          icon: Icons.receipt_long,
          label: "Invoice",
          gradient: [const Color(0xFF43CEA2), const Color(0xFF185A9D)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => InvoiceDashboardScreen()),
            );
          },
        ),
        _GlassAction(
          icon: Icons.mic,
          label: "Voice AI",
          gradient: [const Color(0xFFFF512F), const Color(0xFFDD2476)],
          onTap: () => setState(() => _currentIndex = 2),
        ),
        _GlassAction(
          icon: Icons.pie_chart_outline,
          label: "Budget",
          gradient: [const Color(0xFF11998E), const Color(0xFF38EF7D)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BudgetTrackingScreen()),
            );
          },
        ),
        _GlassAction(
          icon: Icons.people_outline,
          label: "Clients",
          gradient: [const Color(0xFFFF9966), const Color(0xFFFF5E62)],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ClientManagementScreen()),
            );
          },
        ),
        _GlassAction(
          icon: Icons.trending_up,
          label: "Invest",
          gradient: [const Color(0xFF00C6FF), const Color(0xFF0072FF)],
          onTap: () => setState(() => _currentIndex = 3),
        ),
        _GlassAction(
          icon: Icons.analytics_outlined,
          label: "Business",
          gradient: [const Color(0xFFFC4A1A), const Color(0xFFF7B733)],
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
          gradient: [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)],
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
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

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1,
        color: Colors.white54,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
