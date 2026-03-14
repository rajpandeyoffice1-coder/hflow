import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetTrackingScreen extends StatefulWidget {
  const BudgetTrackingScreen({super.key});

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  final supabase = Supabase.instance.client;
  bool weekly = false;
  bool isLoading = true;
  List<Map<String, dynamic>> budgetData = [];
  List<Map<String, dynamic>> filteredBudgetData = [];
  List<Map<String, dynamic>> expenseCategories = [];
  String? errorMessage;

  // Search related variables
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  late final RealtimeChannel _budgetChannel;
  late final RealtimeChannel _expenseChannel;
  late final RealtimeChannel _categoryChannel;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupRealtimeSubscription();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    supabase.removeChannel(_budgetChannel);
    supabase.removeChannel(_expenseChannel);
    supabase.removeChannel(_categoryChannel);
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
    _filterBudgetData();
  }

  void _filterBudgetData() {
    if (_searchQuery.isEmpty) {
      setState(() {
        filteredBudgetData = List.from(budgetData);
      });
    } else {
      setState(() {
        filteredBudgetData = budgetData.where((budget) {
          final title = budget['title'].toString().toLowerCase();
          final items = budget['items'] as List;

          // Search in category name
          if (title.contains(_searchQuery)) return true;

          // Search in transaction descriptions
          final hasMatchingTransaction = items.any((item) {
            final description = item['description']?.toString().toLowerCase() ?? '';
            final vendor = item['vendor']?.toString().toLowerCase() ?? '';
            return description.contains(_searchQuery) || vendor.contains(_searchQuery);
          });

          return hasMatchingTransaction;
        }).toList();
      });
    }
  }

  void _setupRealtimeSubscription() {
    try {
      _budgetChannel = supabase.channel('budget_changes');
      _budgetChannel.onPostgresChanges(
        table: 'category_budgets',
        callback: (payload) {
          if (mounted) {
            fetchBudget();
          }
        },
        event: PostgresChangeEvent.all,
      ).subscribe();

      _expenseChannel = supabase.channel('expense_changes');
      _expenseChannel.onPostgresChanges(
        table: 'expenses',
        callback: (payload) {
          if (mounted) {
            fetchBudget();
          }
        },
        event: PostgresChangeEvent.all,
      ).subscribe();

      _categoryChannel = supabase.channel('category_changes');
      _categoryChannel.onPostgresChanges(
        table: 'expense_categories',
        callback: (payload) {
          if (mounted) {
            fetchBudget();
            _loadExpenseCategories();
          }
        },
        event: PostgresChangeEvent.all,
      ).subscribe();
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  Future<void> _initializeData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    await _loadExpenseCategories();
    await fetchBudget();
  }

  Future<void> _loadExpenseCategories() async {
    try {
      final response = await supabase
          .from('expense_categories')
          .select('id, name, icon, color, is_default')
          .order('name');

      if (mounted) {
        setState(() {
          expenseCategories = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading expense categories: $e');
    }
  }

  Future<void> fetchBudget() async {
    try {
      DateTime now = DateTime.now();
      DateTime start;
      DateTime end;

      if (weekly) {
        start = now.subtract(Duration(days: now.weekday - 1));
        end = start.add(const Duration(days: 6));
      } else {
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
      }

      final expenses = await supabase
          .from('expenses')
          .select('''
                    amount,
                    description,
                    date_incurred,
                    vendor_name,
                    payment_method,
                    category_id,
                    expense_categories(name)
                  ''')
          .gte('date_incurred', start.toIso8601String())
          .lte('date_incurred', end.toIso8601String())
          .order('date_incurred', ascending: false);

      final budgets = await supabase
          .from('category_budgets')
          .select('budget_amount, category_name');

      final categories = await supabase
          .from('expense_categories')
          .select('name');

      Map<String, double> budgetLimits = {};
      for (var budget in budgets) {
        budgetLimits[budget['category_name']] =
            (budget['budget_amount'] as num).toDouble();
      }

      Set<String> allCategories = {};
      for (var category in categories) {
        allCategories.add(category['name']);
      }
      for (var expense in expenses) {
        allCategories.add(expense['expense_categories']?['name'] ?? 'Other');
      }

      Map<String, Map<String, dynamic>> grouped = {};

      for (var category in allCategories) {
        grouped[category] = {
          "spent": 0.0,
          "items": [],
          "category_id": null
        };
      }

      for (var e in expenses) {
        String cat = e['expense_categories']?['name'] ?? "Other";
        double amt = (e['amount'] as num).toDouble();

        grouped[cat]!["spent"] = (grouped[cat]!["spent"] as double) + amt;
        grouped[cat]!["items"].add({
          "amount": amt,
          "description": e['description'] ?? "No description",
          "date": e['date_incurred'] ?? "",
          "vendor": e['vendor_name'] ?? "",
          "method": e['payment_method'] ?? ""
        });
        if (e['category_id'] != null) {
          grouped[cat]!["category_id"] = e['category_id'];
        }
      }

      List<Map<String, dynamic>> list = [];

      grouped.forEach((key, value) {
        double budgetLimit = budgetLimits[key] ?? 0.0;
        list.add({
          "title": key,
          "spent": (value["spent"] as num).toDouble(),
          "total": budgetLimit,
          "items": value["items"],
          "category_id": value["category_id"],
          "hasBudget": budgetLimits.containsKey(key)
        });
      });

      if (mounted) {
        setState(() {
          budgetData = list..sort((a, b) => b['spent'].compareTo(a['spent']));
          _filterBudgetData(); // Apply current search filter to new data
          isLoading = false;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error loading data: $e';
        });
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
        _filterBudgetData();
      }
    });
  }

  Future<void> _createOrUpdateCategory(String categoryName) async {
    await supabase.from('expense_categories').upsert(
      {
        'name': categoryName,
        'icon': '📁',
        'color': '#6366F1',
        'is_default': false,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'name',
    );
  }

  Future<void> _editBudget(String categoryName, double currentLimit) async {
    final TextEditingController controller = TextEditingController(text: currentLimit.toStringAsFixed(0));

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Edit Budget', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set budget limit for $categoryName', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                hintText: 'Enter amount',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0) {
                Navigator.pop(context, value);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B8CFF)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        setState(() => isLoading = true);

        await _createOrUpdateCategory(categoryName);

        await supabase
            .from('category_budgets')
            .upsert(
          {
            'category_name': categoryName,
            'budget_amount': result,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'category_name',
        )
            .select();

        await fetchBudget();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Budget for $categoryName updated to ₹${result.toStringAsFixed(0)}'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving budget: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _createCustomBudget() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Create Custom Budget', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Budget Name',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'e.g., Goa Trip, Emergency Fund',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Budget Amount',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixText: '₹ ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                hintText: 'Enter amount',
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text);
              if (name.isNotEmpty && amount != null && amount > 0) {
                Navigator.pop(context, {'name': name, 'amount': amount});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B8CFF)),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        setState(() => isLoading = true);

        await _createOrUpdateCategory(result['name']);

        await supabase.from('category_budgets').upsert(
            {
              'category_name': result['name'],
              'budget_amount': result['amount'],
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'category_name'
        );

        await fetchBudget();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom budget "${result['name']}" created!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating budget: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _quickBudgetSetup() async {
    if (budgetData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No expense categories found'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final List<String> categories = budgetData.map((e) => e['title'] as String).toList();
    Map<String, TextEditingController> controllers = {};

    for (var cat in categories) {
      double current = (budgetData.firstWhere((e) => e['title'] == cat)['total'] as num).toDouble();
      controllers[cat] = TextEditingController(text: current == 0 ? "" : current.toString());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _GlassContainer(
          child: SafeArea(
            child: Column(
              children: [
                const Text(
                  "Quick Budget Setup",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.category, color: Color(0xFF5B8CFF), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(category, style: const TextStyle(color: Colors.white)),
                            ),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: controllers[category],
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  prefixText: "₹ ",
                                  hintText: "Amount",
                                  hintStyle: const TextStyle(color: Colors.white38),
                                  filled: true,
                                  fillColor: Colors.white.withOpacity(0.1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B8CFF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          List<Map<String, dynamic>> data = [];
                          controllers.forEach((category, controller) {
                            final amount = double.tryParse(controller.text);
                            if (amount != null && amount > 0) {
                              data.add({
                                'category_name': category,
                                'budget_amount': amount,
                                'updated_at': DateTime.now().toIso8601String(),
                              });
                            }
                          });

                          if (data.isEmpty) {
                            Navigator.pop(context);
                            return;
                          }

                          try {
                            setState(() => isLoading = true);
                            Navigator.pop(context);

                            for (var item in data) {
                              await _createOrUpdateCategory(item['category_name']);
                            }

                            await supabase.from('category_budgets').upsert(
                              data,
                              onConflict: 'category_name',
                            );
                            await fetchBudget();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Budgets saved successfully"),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error saving budgets: $e'),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text("Save All"),
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
  }

  void changePeriod(bool value) async {
    setState(() {
      weekly = value;
      isLoading = true;
    });
    await fetchBudget();
  }

  Future<void> refresh() async {
    await fetchBudget();
  }

  Future<void> _deleteBudget(String categoryName, String categoryId) async {
    final expenseCountResponse = await supabase
        .from('expenses')
        .select('count')
        .eq('category_id', categoryId)
        .count();

    final expenseCount = expenseCountResponse.count;

    final isDefaultCategory = await supabase
        .from('expense_categories')
        .select('is_default')
        .eq('name', categoryName)
        .limit(1)
        .maybeSingle();

    if (expenseCount > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot delete: Category has $expenseCount expenses'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Delete Budget', style: TextStyle(color: Colors.white)),
        content: Text(
          isDefaultCategory != null && isDefaultCategory['is_default'] == true
              ? 'This is a default category. Are you sure you want to delete the budget? (Category will remain)'
              : 'Are you sure you want to delete the budget for "$categoryName"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => isLoading = true);

        await supabase
            .from('category_budgets')
            .delete()
            .eq('category_name', categoryName);

        if (isDefaultCategory == null || isDefaultCategory['is_default'] == false) {
          await supabase
              .from('expense_categories')
              .delete()
              .eq('name', categoryName);
        }

        await fetchBudget();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Budget for "$categoryName" deleted'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting budget: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search categories or transactions...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
                autofocus: true,
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                onPressed: () {
                  _searchController.clear();
                },
              ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 18),
              onPressed: _toggleSearch,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: _liquidBlob(width: 320, height: 420, color: const Color(0xFF9333EA), opacity: 0.28),
          ),
          Positioned(
            bottom: -160,
            right: -120,
            child: _liquidBlob(width: 380, height: 460, color: const Color(0xFF3B82F6), opacity: 0.26),
          ),
          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: RefreshIndicator(
                    key: _refreshIndicatorKey,
                    onRefresh: refresh,
                    color: const Color(0xFF5B8CFF),
                    backgroundColor: const Color(0xFF1A1F2E),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF5B8CFF)))
                        : errorMessage != null
                        ? _buildErrorState()
                        : budgetData.isEmpty
                        ? _buildEmptyState()
                        : Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                            children: [
                              _PeriodToggle(weekly: weekly, onChanged: changePeriod),
                              const SizedBox(height: 20),
                              _buildActionButtons(),
                              const SizedBox(height: 12),

                              if (_isSearching) _buildSearchBar(),

                              const SizedBox(height: 12),
                              if (filteredBudgetData.isEmpty && _searchQuery.isNotEmpty)
                                _buildNoSearchResults()
                              else
                                ...filteredBudgetData.map((e) => _BudgetCard(
                                  title: e["title"],
                                  spent: (e["spent"] as num).toDouble(),
                                  total: (e["total"] as num).toDouble(),
                                  items: e["items"],
                                  hasBudget: e["hasBudget"] ?? false,
                                  onEdit: () => _editBudget(e["title"], (e["total"] as num).toDouble()),
                                  onDelete: () => _deleteBudget(
                                    e["title"],
                                    e["category_id"] ?? "",
                                  ),
                                  searchQuery: _searchQuery,
                                )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: const Icon(Icons.search_off, size: 40, color: Colors.white24),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'No matches for "$_searchQuery"',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.1),
            ),
            child: const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          ),
          const SizedBox(height: 24),
          const Text(
            'Something went wrong',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Failed to load data',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _initializeData(),
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8CFF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
            ),
            child: const Icon(Icons.receipt_long, size: 48, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          const Text(
            'No budgets found',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a budget to get started',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _createCustomBudget(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Create Budget'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8CFF),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: InkWell(
              onTap: _createCustomBudget,
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B8CFF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_circle_outline, color: Color(0xFF5B8CFF), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Custom Budget',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 40),
              color: const Color(0xFF1A1F2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'quick') {
                  _quickBudgetSetup();
                } else if (value == 'reset') {
                  _showResetBudgetsDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'quick',
                  child: Row(
                    children: [
                      Icon(Icons.flash_on, color: Color(0xFF5B8CFF), size: 20),
                      SizedBox(width: 8),
                      Text('Quick Setup', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.restart_alt, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Reset to ₹0', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit, color: Colors.white70, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Set Budgets',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showResetBudgetsDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Reset All Budgets', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to reset all category budgets to ₹0?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => isLoading = true);

        final categories = budgetData.map((e) => e['title'] as String).toSet();
        for (var category in categories) {
          await supabase.from('category_budgets').upsert(
            {
              'category_name': category,
              'budget_amount': 0,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'category_name',
          );
        }

        await fetchBudget();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All budgets reset to ₹0'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        setState(() => isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting budgets: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _header() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.12))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              "Budget Tracking",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
            ),
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: _toggleSearch,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () async {
              setState(() => isLoading = true);
              await fetchBudget();
            },
          )
        ],
      ),
    );
  }

  static Widget _liquidBlob({required double width, required double height, required Color color, required double opacity}) {
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

class _PeriodToggle extends StatelessWidget {
  final bool weekly;
  final Function(bool) onChanged;

  const _PeriodToggle({required this.weekly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassContainer(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleChip(label: "Monthly", active: !weekly, onTap: () => onChanged(false)),
            _ToggleChip(label: "Weekly", active: weekly, onTap: () => onChanged(true)),
          ],
        ),
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _ToggleChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF5B8CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final String title;
  final double spent;
  final double total;
  final List items;
  final bool hasBudget;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String? searchQuery;

  const _BudgetCard({
    required this.title,
    required this.spent,
    required this.total,
    required this.items,
    required this.hasBudget,
    required this.onEdit,
    required this.onDelete,
    this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final double percent = total == 0 ? 0 : (spent / total).clamp(0.0, 2.0);
    final bool isOverBudget = spent > total && total > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isOverBudget ? Colors.red.withOpacity(0.2) : const Color(0xFF5B8CFF).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(title),
                    color: isOverBudget ? Colors.redAccent : const Color(0xFF5B8CFF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHighlightedText(title, searchQuery),
                      const SizedBox(height: 2),
                      Text(
                        '${items.length} ${items.length == 1 ? 'transaction' : 'transactions'}',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  color: const Color(0xFF1A1F2E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Color(0xFF5B8CFF), size: 20),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.more_vert, size: 16, color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spent',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${spent.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isOverBudget ? Colors.redAccent : Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Budget',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 16),
                          ),
                          if (!hasBudget)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'No limit',
                                style: TextStyle(fontSize: 10, color: Colors.orange),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation(
                  isOverBudget ? Colors.redAccent : const Color(0xFF5B8CFF),
                ),
              ),
            ),
            if (isOverBudget) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Over budget by ₹${(spent - total).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              ...items.take(2).map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5B8CFF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildHighlightedText(
                        i["description"] ?? 'Expense',
                        searchQuery,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                    ),
                    Text(
                      '₹${(i["amount"] as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ],
                ),
              )),
              if (items.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${items.length - 2} more transactions',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String? query, {TextStyle? style}) {
    if (query == null || query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(text, style: style ?? const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16));
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: const Color(0xFF5B8CFF).withOpacity(0.3),
            fontWeight: FontWeight.w600,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: style ?? const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return Icons.restaurant;
      case 'transport':
      case 'travel':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'utilities':
        return Icons.electrical_services;
      case 'health':
      case 'medical':
        return Icons.medical_services;
      case 'education':
        return Icons.school;
      case 'goa trip':
      case 'trip':
      case 'vacation':
        return Icons.beach_access;
      case 'emergency':
      case 'emergency fund':
        return Icons.warning;
      default:
        return Icons.category;
    }
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _GlassContainer({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}