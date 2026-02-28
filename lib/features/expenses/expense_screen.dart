import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const ExpenseScreen({super.key, this.onBack});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen>
    with SingleTickerProviderStateMixin {
  static const double _headerHeight = 56;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  late TabController _tabController;

  // Filter states
  String _selectedCategory = 'All';
  String _selectedPaymentMethod = 'All';
  DateTimeRange? _selectedDateRange;
  bool _showBusinessOnly = false;

  // Database data
  List<Map<String, dynamic>> _allExpenses = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Stats
  double _totalExpenses = 0;
  double _thisMonthExpenses = 0;
  double _averageExpense = 0;
  int _totalTransactions = 0;

  // Monthly trend data
  List<Map<String, dynamic>> _monthlyTrend = [];

  // Category colors
  final Map<String, Color> _categoryColors = {};

  // Search summary
  Map<String, dynamic> _searchSummary = {'count': 0, 'total': 0.0};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Set default date range to last 6 months
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month - 6, now.day),
      end: now,
    );

    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _currentPage = 1;
      _updateSearchSummary();
    });
  }

  void _updateSearchSummary() {
    if (_searchQuery.isEmpty) {
      _searchSummary = {
        'count': filteredExpenses.length,
        'total': filteredExpenses.fold(
          0.0,
          (sum, item) => sum + item['amount'],
        ),
      };
    } else {
      final searchResults = _allExpenses.where((exp) {
        return exp['description'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            exp['category'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            exp['vendor'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            exp['notes'].toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
      }).toList();

      _searchSummary = {
        'count': searchResults.length,
        'total': searchResults.fold(0.0, (sum, item) => sum + item['amount']),
      };
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadExpenses(),
        _loadCategories(),
        _loadMonthlyTrend(),
      ]);
      _calculateStats();
      _updateSearchSummary();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExpenses() async {
    try {
      final supabase = Supabase.instance.client;

      // Start with the base query
      var query = supabase.from('expenses').select('''
          *,
          expense_categories (
            name,
            color,
            icon
          )
        ''');

      // Apply date range filter FIRST
      if (_selectedDateRange != null) {
        query = query
            .gte('date_incurred', _selectedDateRange!.start.toIso8601String())
            .lte('date_incurred', _selectedDateRange!.end.toIso8601String());
      }

      // Apply category filter
      if (_selectedCategory != 'All') {
        final category = _expenseCategories.firstWhere(
          (cat) => cat['name'] == _selectedCategory,
          orElse: () => {},
        );
        if (category.isNotEmpty) {
          query = query.eq('category_id', category['id']);
        }
      }

      // Apply payment method filter
      if (_selectedPaymentMethod != 'All') {
        query = query.eq(
          'payment_method',
          _selectedPaymentMethod.toLowerCase(),
        );
      }

      // Apply business only filter
      if (_showBusinessOnly) {
        query = query.eq('is_business_expense', true);
      }

      // Apply sorting LAST - this returns a PostgrestTransformBuilder
      // but we're just executing it, so it's fine
      final response = await query.order('date_incurred', ascending: false);

      setState(() {
        _allExpenses = response.map<Map<String, dynamic>>((expense) {
          final category =
              expense['expense_categories'] as Map<String, dynamic>?;
          return {
            'id': expense['id'],
            'date': DateTime.parse(expense['date_incurred']),
            'formattedDate': DateFormat(
              'dd MMM yyyy',
            ).format(DateTime.parse(expense['date_incurred'])),
            'description': expense['description'],
            'notes': expense['notes'] ?? '',
            'amount': (expense['amount'] as num).toDouble(),
            'category':
                category?['name'] ??
                expense['category_name'] ??
                'Uncategorized',
            'paymentMethod':
                expense['payment_method']?.toString().toUpperCase() ?? 'CASH',
            'vendor': expense['vendor_name'] ?? '-',
            'business': expense['is_business_expense'] ?? true,
            'taxDeductible': expense['tax_deductible'] ?? false,
            'receiptNumber': expense['receipt_number'],
            'tags': expense['tags'] ?? [],
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading expenses: $e');
      rethrow;
    }
  }

  Future<void> _loadCategories() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('expense_categories')
          .select()
          .order('name');

      setState(() {
        _expenseCategories = response;
        // Update category colors
        for (var category in _expenseCategories) {
          _categoryColors[category['name']] = _parseColor(
            category['color'] ?? '#6B7280',
          );
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
      _loadDefaultCategories();
    }
  }

  void _loadDefaultCategories() {
    final defaultCategories = [
      {'name': 'Food & Dining', 'color': '#ef4444'},
      {'name': 'Transportation', 'color': '#f59e0b'},
      {'name': 'Utilities', 'color': '#10b981'},
      {'name': 'Office Supplies', 'color': '#6366f1'},
      {'name': 'Software', 'color': '#8b5cf6'},
      {'name': 'Marketing', 'color': '#ec4899'},
      {'name': 'Travel', 'color': '#14b8a6'},
      {'name': 'Professional Services', 'color': '#64748b'},
    ];

    setState(() {
      _expenseCategories = defaultCategories;
      for (var category in defaultCategories) {
        _categoryColors[category['name']!] = _parseColor(category['color']!);
      }
    });
  }

  Future<void> _loadMonthlyTrend() async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

      final response = await supabase
          .from('expenses')
          .select('date_incurred, amount')
          .gte('date_incurred', sixMonthsAgo.toIso8601String())
          .order('date_incurred');

      // Group by month
      final Map<String, double> monthlyTotals = {};
      for (var expense in response) {
        final date = DateTime.parse(expense['date_incurred']);
        final monthKey = DateFormat('MMM yyyy').format(date);
        monthlyTotals[monthKey] =
            (monthlyTotals[monthKey] ?? 0) +
            (expense['amount'] as num).toDouble();
      }

      // Convert to list and sort
      final sortedMonths = monthlyTotals.entries.toList()
        ..sort((a, b) {
          final dateA = DateFormat('MMM yyyy').parse(a.key);
          final dateB = DateFormat('MMM yyyy').parse(b.key);
          return dateA.compareTo(dateB);
        });

      setState(() {
        _monthlyTrend = sortedMonths
            .map((e) => {'month': e.key, 'expenses': e.value})
            .toList();
      });
    } catch (e) {
      print('Error loading monthly trend: $e');
      // Use sample data if database fails
      setState(() {
        _monthlyTrend = [
          {'month': 'Sep 2025', 'expenses': 125000.00},
          {'month': 'Oct 2025', 'expenses': 142000.00},
          {'month': 'Nov 2025', 'expenses': 138000.00},
          {'month': 'Dec 2025', 'expenses': 158000.00},
          {'month': 'Jan 2026', 'expenses': 160500.00},
          {'month': 'Feb 2026', 'expenses': 145000.00},
        ];
      });
    }
  }

  void _calculateStats() {
    double total = 0;
    double monthTotal = 0;
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    for (var expense in _allExpenses) {
      total += expense['amount'];

      final date = expense['date'] as DateTime;
      if (date.month == currentMonth && date.year == currentYear) {
        monthTotal += expense['amount'];
      }
    }

    setState(() {
      _totalExpenses = total;
      _thisMonthExpenses = monthTotal;
      _averageExpense = _allExpenses.isEmpty ? 0 : total / _allExpenses.length;
      _totalTransactions = _allExpenses.length;
    });
  }

  Color _parseColor(String colorHex) {
    try {
      final hex = colorHex.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
    } catch (e) {
      print('Error parsing color: $e');
    }
    return Colors.grey;
  }

  List<Map<String, dynamic>> get filteredExpenses {
    if (_searchQuery.isEmpty) return _allExpenses;

    return _allExpenses.where((exp) {
      return exp['description'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          exp['category'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          exp['vendor'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          exp['notes'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
    }).toList();
  }

  List<Map<String, dynamic>> get paginatedExpenses {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    if (filteredExpenses.isEmpty) return [];
    return filteredExpenses.sublist(
      start,
      end > filteredExpenses.length ? filteredExpenses.length : end,
    );
  }

  int get totalPages => (filteredExpenses.length / _itemsPerPage).ceil();

  Map<String, double> get categoryTotals {
    final totals = <String, double>{};
    for (var exp in _allExpenses) {
      totals[exp['category']] = (totals[exp['category']] ?? 0) + exp['amount'];
    }
    return totals;
  }

  bool get hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedCategory != 'All' ||
        _selectedPaymentMethod != 'All' ||
        _showBusinessOnly ||
        _selectedDateRange != null;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategory = 'All';
      _selectedPaymentMethod = 'All';
      _showBusinessOnly = false;
      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(
        start: DateTime(now.year, now.month - 6, now.day),
        end: now,
      );
      _currentPage = 1;
    });
    _loadExpenses();
  }

  Future<void> _addExpense(Map<String, dynamic> expenseData) async {
    try {
      final supabase = Supabase.instance.client;

      // Find category ID
      String? categoryId;
      if (expenseData['category'] != null) {
        final category = _expenseCategories.firstWhere(
          (cat) => cat['name'] == expenseData['category'],
          orElse: () => {},
        );
        if (category.isNotEmpty) {
          categoryId = category['id'];
        }
      }

      final expense = {
        'amount': expenseData['amount'],
        'description': expenseData['description'],
        'category_id': categoryId,
        'category_name': expenseData['category'],
        'date_incurred': (expenseData['date'] as DateTime).toIso8601String(),
        'payment_method': expenseData['paymentMethod']?.toLowerCase() ?? 'cash',
        'vendor_name': expenseData['vendor'],
        'is_business_expense': expenseData['business'] ?? true,
        'tax_deductible': expenseData['taxDeductible'] ?? false,
        'notes': expenseData['notes'],
        'receipt_number': expenseData['receiptNumber'],
        'tags': expenseData['tags'] ?? [],
      };

      await supabase.from('expenses').insert(expense);

      await _loadExpenses();
      await _loadMonthlyTrend();
      _calculateStats();
      _updateSearchSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Expense added successfully"),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error adding expense: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateExpense(
    String id,
    Map<String, dynamic> expenseData,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      // Find category ID
      String? categoryId;
      if (expenseData['category'] != null) {
        final category = _expenseCategories.firstWhere(
          (cat) => cat['name'] == expenseData['category'],
          orElse: () => {},
        );
        if (category.isNotEmpty) {
          categoryId = category['id'];
        }
      }

      final updates = {
        'amount': expenseData['amount'],
        'description': expenseData['description'],
        'category_id': categoryId,
        'category_name': expenseData['category'],
        'date_incurred': (expenseData['date'] as DateTime).toIso8601String(),
        'payment_method': expenseData['paymentMethod']?.toLowerCase() ?? 'cash',
        'vendor_name': expenseData['vendor'],
        'is_business_expense': expenseData['business'] ?? true,
        'tax_deductible': expenseData['taxDeductible'] ?? false,
        'notes': expenseData['notes'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabase.from('expenses').update(updates).eq('id', id);

      await _loadExpenses();
      await _loadMonthlyTrend();
      _calculateStats();
      _updateSearchSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Expense updated successfully"),
            backgroundColor: Color(0xFF5B8CFF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating expense: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Delete Expense',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${expense['description']}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('expenses').delete().eq('id', expense['id']);

      await _loadExpenses();
      await _loadMonthlyTrend();
      _calculateStats();
      _updateSearchSummary();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted successfully'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
              ),
            ),
          ),

          // Decorative blobs
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

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF5B8CFF),
                          ),
                        )
                      : _errorMessage != null
                      ? _buildErrorState()
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddExpenseModal,
        backgroundColor: const Color(0xFF5B8CFF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8CFF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Title and subtitle
          const Text(
            "Expense Management",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Track and manage your business expenses efficiently",
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),

          // Stats cards
          _buildStatsGrid(),
          const SizedBox(height: 20),

          // Monthly Expense Trend
          if (_monthlyTrend.isNotEmpty) _buildMonthlyTrend(),
          const SizedBox(height: 20),

          // Category Breakdown
          if (categoryTotals.isNotEmpty) _buildCategoryBreakdown(),
          const SizedBox(height: 20),

          // Income vs Expenses
          _buildIncomeVsExpenses(),
          const SizedBox(height: 20),

          // Date Range Filter
          _buildDateRangeFilter(),
          const SizedBox(height: 16),

          // Search and Filter Section
          _buildSearchAndFilterSection(),
          const SizedBox(height: 16),

          // Search Summary
          if (_searchQuery.isNotEmpty) _buildSearchSummary(),
          const SizedBox(height: 16),

          // Expense count and actions
          _buildExpenseHeader(),
          const SizedBox(height: 16),

          // Expenses table
          _buildExpensesTable(),
          const SizedBox(height: 16),

          // Pagination
          if (totalPages > 1) _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Date Range",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedDateRange != null
                                ? "${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}"
                                : "Select date range",
                            style: TextStyle(
                              color: _selectedDateRange != null
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5B8CFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1F2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _currentPage = 1;
      });
      _loadExpenses();
    }
  }

  Widget _buildSearchSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF5B8CFF).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B8CFF).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.search, size: 18, color: const Color(0xFF5B8CFF)),
              const SizedBox(width: 8),
              Text(
                "Found: ${_searchSummary['count']} entries",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF5B8CFF).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Total: ₹${_formatAmount(_searchSummary['total'])}",
              style: const TextStyle(
                color: Color(0xFF5B8CFF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
              } else if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          const Expanded(
            child: Text(
              "Expense Management",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _buildStatCard(
          title: "TOTAL EXPENSES",
          value: "₹${_formatAmount(_totalExpenses)}",
          icon: Icons.account_balance_wallet,
          color: const Color(0xFF5B8CFF),
          trend: "+12%",
        ),
        _buildStatCard(
          title: "THIS MONTH",
          value: "₹${_formatAmount(_thisMonthExpenses)}",
          icon: Icons.calendar_today,
          color: const Color(0xFF22C55E),
        ),
        _buildStatCard(
          title: "AVERAGE EXPENSE",
          value: "₹${_formatAmount(_averageExpense)}",
          icon: Icons.trending_up,
          color: const Color(0xFFF97316),
        ),
        _buildStatCard(
          title: "TOTAL TRANSACTIONS",
          value: "$_totalTransactions",
          icon: Icons.receipt,
          color: const Color(0xFFA855F7),
          badge: "+${_totalTransactions > 0 ? (_totalTransactions ~/ 10) : 0}",
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? trend,
    String? badge,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, size: 12, color: color),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trend != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        trend,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildMonthlyTrend() {
    if (_monthlyTrend.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxExpense = _monthlyTrend
        .map((e) => e['expenses'] as double)
        .reduce((a, b) => a > b ? a : b);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Monthly Expense Trend",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: _monthlyTrend.map((data) {
                    final month = data['month'] as String;
                    final expense = data['expenses'] as double;

                    // Calculate height with proper type casting
                    double barHeight = 0;
                    if (maxExpense > 0) {
                      barHeight = (expense / maxExpense) * 100;
                    }

                    // Ensure minimum height of 4px for visibility with proper double conversion
                    double displayHeight = barHeight;
                    if (barHeight < 4 && barHeight > 0) {
                      displayHeight = 4.0;
                    }
                    // Clamp to max 100 and ensure it's a double
                    if (displayHeight > 100) {
                      displayHeight = 100.0;
                    }

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Bar container with proper constraints
                            Container(
                              height: displayHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF5B8CFF).withOpacity(0.8),
                                    const Color(0xFF5B8CFF).withOpacity(0.3),
                                  ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Month label
                            Text(
                              month.split(' ')[0],
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              // Month names row
              SizedBox(
                height: 20,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _monthlyTrend.length,
                  itemBuilder: (context, index) {
                    final data = _monthlyTrend[index];
                    return Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 8),
                      child: Text(
                        data['month'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final totals = categoryTotals;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Category Breakdown",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ...totals.entries.map((entry) {
                final percentage = (entry.value / _totalExpenses * 100);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _categoryColors[entry.key] ?? Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: percentage / 100,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color:
                                      _categoryColors[entry.key] ?? Colors.grey,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "₹${_formatAmount(entry.value)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncomeVsExpenses() {
    final netProfit = (_totalExpenses * 1.3) - _totalExpenses;
    final profitMargin = _totalExpenses > 0
        ? ((netProfit / (_totalExpenses * 1.3)) * 100)
        : 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Income vs Expenses Overview",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Legend
              Row(
                children: [
                  _buildLegendItem("Income", const Color(0xFF22C55E)),
                  const SizedBox(width: 20),
                  _buildLegendItem("Expenses", const Color(0xFFEF4444)),
                ],
              ),
              const SizedBox(height: 20),

              // Months header
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Category",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      DateFormat('MMM yyyy').format(
                        DateTime.now().subtract(const Duration(days: 30)),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      DateFormat('MMM yyyy').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Income row
              _buildComparisonRow(
                label: "Income",
                amount1: _totalExpenses * 1.3,
                amount2: _thisMonthExpenses * 1.3,
                color: const Color(0xFF22C55E),
              ),
              const SizedBox(height: 12),

              // Expenses row
              _buildComparisonRow(
                label: "Expenses",
                amount1: _totalExpenses,
                amount2: _thisMonthExpenses,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(height: 20),

              // Net Profit and Margin
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Net Profit",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "₹${_formatAmount(netProfit)}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5B8CFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Profit Margin",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${profitMargin.toStringAsFixed(1)}%",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF22C55E),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required double amount1,
    required double amount2,
    required Color color,
    bool isPercentage = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            "₹${_formatAmount(amount1)}",
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        SizedBox(
          width: 100,
          child: Text(
            isPercentage
                ? "${amount2.toStringAsFixed(1)}%"
                : "₹${_formatAmount(amount2)}",
            style: TextStyle(
              fontSize: 13,
              color: isPercentage ? const Color(0xFF22C55E) : color,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search row with filter button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Focus(
                          onFocusChange: (hasFocus) {
                            // No need to rebuild, just let the TextField handle it
                          },
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: "Search expenses...",
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color: Colors.white.withOpacity(0.6),
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        size: 18,
                                        color: Colors.white.withOpacity(0.6),
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filter button
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF5B8CFF).withOpacity(0.3),
                            const Color(0xFF5B8CFF).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasActiveFilters
                              ? const Color(0xFF5B8CFF).withOpacity(0.6)
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _openFilterDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.filter_list,
                                  size: 18,
                                  color: hasActiveFilters
                                      ? const Color(0xFF5B8CFF)
                                      : Colors.white.withOpacity(0.7),
                                ),
                                if (hasActiveFilters) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF5B8CFF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Active filters chips
                if (hasActiveFilters) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (_selectedDateRange != null)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            child: _buildActiveFilterChip(
                              label:
                                  "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                              onRemove: () {
                                setState(() {
                                  final now = DateTime.now();
                                  _selectedDateRange = DateTimeRange(
                                    start: DateTime(
                                      now.year,
                                      now.month - 6,
                                      now.day,
                                    ),
                                    end: now,
                                  );
                                  _currentPage = 1;
                                });
                                _loadExpenses();
                              },
                            ),
                          ),
                        if (_selectedCategory != 'All')
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            child: _buildActiveFilterChip(
                              label: "Category: $_selectedCategory",
                              onRemove: () {
                                setState(() {
                                  _selectedCategory = 'All';
                                  _currentPage = 1;
                                });
                                _loadExpenses();
                              },
                            ),
                          ),
                        if (_selectedPaymentMethod != 'All')
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            child: _buildActiveFilterChip(
                              label: "Payment: $_selectedPaymentMethod",
                              onRemove: () {
                                setState(() {
                                  _selectedPaymentMethod = 'All';
                                  _currentPage = 1;
                                });
                                _loadExpenses();
                              },
                            ),
                          ),
                        if (_showBusinessOnly)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            child: _buildActiveFilterChip(
                              label: "Business Only",
                              onRemove: () {
                                setState(() {
                                  _showBusinessOnly = false;
                                  _currentPage = 1;
                                });
                                _loadExpenses();
                              },
                            ),
                          ),
                        // Clear all button
                        if (hasActiveFilters)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            child: TextButton(
                              onPressed: _clearAllFilters,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                "Clear All",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.7),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip({
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF5B8CFF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF5B8CFF).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF5B8CFF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 12,
              color: const Color(0xFF5B8CFF).withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterDialog() {
    String tempCategory = _selectedCategory;
    String tempPaymentMethod = _selectedPaymentMethod;
    bool tempBusinessOnly = _showBusinessOnly;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filter Expenses",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category Section
                          const Text(
                            "Category",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildDialogFilterChip(
                                label: "All",
                                selected: tempCategory == 'All',
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempCategory = 'All';
                                  });
                                },
                              ),
                              ..._expenseCategories.map((category) {
                                return _buildDialogFilterChip(
                                  label: category['name'],
                                  selected: tempCategory == category['name'],
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempCategory = selected
                                          ? category['name']
                                          : 'All';
                                    });
                                  },
                                );
                              }),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Payment Method Section
                          const Text(
                            "Payment Method",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildDialogFilterChip(
                                label: "All",
                                selected: tempPaymentMethod == 'All',
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempPaymentMethod = 'All';
                                  });
                                },
                              ),
                              _buildDialogFilterChip(
                                label: "Cash",
                                selected: tempPaymentMethod == 'Cash',
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempPaymentMethod = selected
                                        ? 'Cash'
                                        : 'All';
                                  });
                                },
                              ),
                              _buildDialogFilterChip(
                                label: "UPI",
                                selected: tempPaymentMethod == 'UPI',
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempPaymentMethod = selected
                                        ? 'UPI'
                                        : 'All';
                                  });
                                },
                              ),
                              _buildDialogFilterChip(
                                label: "Credit Card",
                                selected: tempPaymentMethod == 'Credit Card',
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempPaymentMethod = selected
                                        ? 'Credit Card'
                                        : 'All';
                                  });
                                },
                              ),
                              _buildDialogFilterChip(
                                label: "Net Banking",
                                selected: tempPaymentMethod == 'Net Banking',
                                onSelected: (selected) {
                                  setModalState(() {
                                    tempPaymentMethod = selected
                                        ? 'Net Banking'
                                        : 'All';
                                  });
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Expense Type Section
                          const Text(
                            "Expense Type",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDialogFilterChip(
                                  label: "All Expenses",
                                  selected: !tempBusinessOnly,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempBusinessOnly = false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDialogFilterChip(
                                  label: "Business Only",
                                  selected: tempBusinessOnly,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempBusinessOnly = true;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setModalState(() {
                                tempCategory = 'All';
                                tempPaymentMethod = 'All';
                                tempBusinessOnly = false;
                              });
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              "Reset",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = tempCategory;
                                _selectedPaymentMethod = tempPaymentMethod;
                                _showBusinessOnly = tempBusinessOnly;
                                _currentPage = 1;
                              });
                              Navigator.pop(context);
                              _loadExpenses();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B8CFF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Apply Filters",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogFilterChip({
    required String label,
    required bool selected,
    required Function(bool) onSelected,
  }) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? Colors.white : Colors.white.withOpacity(0.8),
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      backgroundColor: Colors.white.withOpacity(0.1),
      selectedColor: const Color(0xFF5B8CFF).withOpacity(0.4),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected
            ? const Color(0xFF5B8CFF).withOpacity(0.6)
            : Colors.white.withOpacity(0.2),
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildExpenseHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "${filteredExpenses.length} expenses found",
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.download, size: 14, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    "Export",
                    style: TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF5B8CFF).withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF5B8CFF).withOpacity(0.5),
                ),
              ),
              child: InkWell(
                onTap: _openAddExpenseModal,
                child: const Row(
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF5B8CFF)),
                    SizedBox(width: 4),
                    Text(
                      "Add",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5B8CFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpensesTable() {
    if (filteredExpenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: const [
              Icon(Icons.receipt_outlined, size: 64, color: Colors.white54),
              SizedBox(height: 16),
              Text(
                "No expenses found",
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1A1F2E),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(const Color(0xFF111827)),
            dataRowColor: MaterialStateProperty.all(Colors.transparent),
            columnSpacing: 30,
            headingTextStyle: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
            columns: const [
              DataColumn(label: Text("DATE")),
              DataColumn(label: Text("DESCRIPTION")),
              DataColumn(label: Text("CATEGORY")),
              DataColumn(label: Text("AMOUNT")),
              DataColumn(label: Text("PAYMENT")),
              DataColumn(label: Text("ACTIONS")),
            ],
            rows: paginatedExpenses.map((expense) {
              return DataRow(
                cells: [
                  DataCell(Text(expense['formattedDate'])),
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        expense['description'],
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color:
                                _categoryColors[expense['category']] ??
                                Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(expense['category']),
                      ],
                    ),
                  ),
                  DataCell(
                    Text(
                      "₹${_formatAmount(expense['amount'])}",
                      style: TextStyle(
                        color: expense['business'] == true
                            ? const Color(0xFF5B8CFF)
                            : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(Text(expense['paymentMethod'] ?? '-')),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.white70,
                          ),
                          onPressed: () => _editExpense(expense),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.white70,
                          ),
                          onPressed: () => _deleteExpense(expense),
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
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _currentPage > 1
              ? () {
                  setState(() {
                    _currentPage--;
                  });
                }
              : null,
          icon: Icon(
            Icons.chevron_left,
            color: _currentPage > 1 ? Colors.white : Colors.white24,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            "$_currentPage / $totalPages",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          onPressed: _currentPage < totalPages
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
          icon: Icon(
            Icons.chevron_right,
            color: _currentPage < totalPages ? Colors.white : Colors.white24,
            size: 20,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  void _openAddExpenseModal([Map<String, dynamic>? existingExpense]) {
    final isEditing = existingExpense != null;

    DateTime selectedDate = isEditing
        ? existingExpense['date'] as DateTime
        : DateTime.now();

    final TextEditingController dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(selectedDate),
    );
    final TextEditingController amountController = TextEditingController(
      text: isEditing ? existingExpense['amount'].toString() : '',
    );
    final TextEditingController descriptionController = TextEditingController(
      text: isEditing ? existingExpense['description'] : '',
    );
    final TextEditingController vendorController = TextEditingController(
      text: isEditing ? existingExpense['vendor'] : '',
    );
    final TextEditingController notesController = TextEditingController(
      text: isEditing ? existingExpense['notes'] : '',
    );

    String? selectedCategory = isEditing ? existingExpense['category'] : null;
    String? selectedPayment = isEditing
        ? existingExpense['paymentMethod']
        : null;
    bool isBusiness = isEditing ? existingExpense['business'] : true;
    bool isTaxDeductible = isEditing
        ? (existingExpense['taxDeductible'] ?? false)
        : false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1F2E).withOpacity(0.98),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEditing
                                          ? "Edit Expense"
                                          : "Add New Expense",
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isEditing
                                          ? "Update your expense details"
                                          : "Track your business expenses efficiently",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 24,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Date and Amount row
                          Row(
                            children: [
                              Expanded(
                                child: _buildModalInput(
                                  controller: dateController,
                                  hint: "Select Date",
                                  readOnly: true,
                                  prefixIcon: Icons.calendar_today,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      builder: (context, child) {
                                        return Theme(
                                          data: ThemeData.dark().copyWith(
                                            colorScheme: const ColorScheme.dark(
                                              primary: Color(0xFF5B8CFF),
                                              onPrimary: Colors.white,
                                              surface: Color(0xFF1A1F2E),
                                              onSurface: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        selectedDate = picked;
                                        dateController.text = DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(picked);
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModalInput(
                                  controller: amountController,
                                  hint: "Amount",
                                  keyboardType: TextInputType.number,
                                  prefixText: "₹ ",
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Category and Payment Method row
                          Row(
                            children: [
                              Expanded(
                                child: _buildModalDropdown(
                                  hint: "Select Category",
                                  value: selectedCategory,
                                  items: _expenseCategories
                                      .map((e) => e['name'] as String)
                                      .toList(),
                                  onChanged: (val) {
                                    setModalState(() {
                                      selectedCategory = val;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModalDropdown(
                                  hint: "Payment Method",
                                  value: selectedPayment,
                                  items: const [
                                    "Cash",
                                    "UPI",
                                    "Credit Card",
                                    "Net Banking",
                                    "Digital Wallet",
                                    "Bank Transfer",
                                  ],
                                  onChanged: (val) {
                                    setModalState(() {
                                      selectedPayment = val;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Description
                          _buildModalInput(
                            controller: descriptionController,
                            hint: "Description *",
                          ),
                          const SizedBox(height: 16),

                          // Vendor
                          _buildModalInput(
                            controller: vendorController,
                            hint: "Vendor/Supplier (Optional)",
                          ),
                          const SizedBox(height: 16),

                          // Notes
                          _buildModalInput(
                            controller: notesController,
                            hint: "Additional Notes (Optional)",
                            maxLines: 3,
                          ),
                          const SizedBox(height: 20),

                          // Checkboxes
                          Row(
                            children: [
                              _buildModalCheckbox(
                                label: "Business Expense",
                                value: isBusiness,
                                onChanged: (val) {
                                  setModalState(() {
                                    isBusiness = val ?? true;
                                  });
                                },
                              ),
                              const SizedBox(width: 24),
                              _buildModalCheckbox(
                                label: "Tax Deductible",
                                value: isTaxDeductible,
                                onChanged: (val) {
                                  setModalState(() {
                                    isTaxDeductible = val ?? false;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildModalButton(
                                  text: "Cancel",
                                  onTap: () => Navigator.pop(context),
                                  isPrimary: false,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildModalButton(
                                  text: isEditing
                                      ? "Update Expense"
                                      : "Save Expense",
                                  onTap: () {
                                    if (descriptionController.text.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Description is required",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    if (amountController.text.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Amount is required"),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    if (selectedCategory == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Please select a category",
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                      return;
                                    }

                                    final expenseData = {
                                      'date': selectedDate,
                                      'amount':
                                          double.tryParse(
                                            amountController.text,
                                          ) ??
                                          0,
                                      'description': descriptionController.text,
                                      'category': selectedCategory,
                                      'paymentMethod':
                                          selectedPayment ?? 'Cash',
                                      'vendor': vendorController.text,
                                      'notes': notesController.text,
                                      'business': isBusiness,
                                      'taxDeductible': isTaxDeductible,
                                      'receiptNumber': null,
                                      'tags': [],
                                    };

                                    Navigator.pop(context);

                                    if (isEditing) {
                                      _updateExpense(
                                        existingExpense['id'],
                                        expenseData,
                                      );
                                    } else {
                                      _addExpense(expenseData);
                                    }
                                  },
                                  isPrimary: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
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

  Widget _buildModalInput({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? prefixIcon,
    String? prefixText,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 18, color: Colors.white.withOpacity(0.6))
              : null,
          prefixText: prefixText,
          prefixStyle: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 15,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildModalDropdown({
    required String hint,
    required List<String> items,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1F2E),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          icon: Icon(
            Icons.arrow_drop_down,
            color: Colors.white.withOpacity(0.6),
            size: 24,
          ),
          items: items.map((e) {
            return DropdownMenuItem(value: e, child: Text(e));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildModalCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 22,
          width: 22,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            fillColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const Color(0xFF5B8CFF);
              }
              return Colors.white.withOpacity(0.15);
            }),
            checkColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildModalButton({
    required String text,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF5B8CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isPrimary ? Colors.white : Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) {
    _openAddExpenseModal(expense);
  }

  String _formatAmount(double amount) {
    if (amount >= 10000000) {
      // 1 Crore+
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      // 1 Lakh+
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
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
