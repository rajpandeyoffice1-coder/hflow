import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BudgetTrackingScreen extends StatefulWidget {
  const BudgetTrackingScreen({super.key});

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  final supabase = Supabase.instance.client;

  bool weekly = false;
  bool loading = true;

  List<Map<String, dynamic>> budgetData = [];

  @override
  void initState() {
    super.initState();
    fetchBudget();
    _showOnboardingPrompt();
  }

  Future<void> fetchBudget() async {
    setState(() {
      loading = true;
    });

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

    final response = await supabase
        .from('expenses')
        .select(
        'amount,description,category_name,date_incurred,vendor_name,payment_method')
        .gte('date_incurred', start.toIso8601String())
        .lte('date_incurred', end.toIso8601String())
        .order('date_incurred', ascending: false);

    // ✅ IMPLEMENTED: Fetch custom budget limits from category_budgets table
    final budgetLimits = await supabase
        .from('category_budgets')
        .select('category_name, budget_amount');

    Map<String, double> customLimits = {};
    for (var limit in budgetLimits) {
      customLimits[limit['category_name']] =
          (limit['budget_amount'] as num).toDouble();
    }

    Map<String, Map<String, dynamic>> grouped = {};

    for (var e in response) {
      String cat = e['category_name'] ?? "Other";
      double amt = (e['amount'] as num).toDouble();

      if (!grouped.containsKey(cat)) {
        grouped[cat] = {
          "spent": 0.0,
          "items": []
        };
      }

      grouped[cat]!["spent"] += amt;

      grouped[cat]!["items"].add({
        "amount": amt,
        "description": e['description'] ?? "",
        "date": e['date_incurred'] ?? "",
        "vendor": e['vendor_name'] ?? "",
        "method": e['payment_method'] ?? ""
      });
    }

    List<Map<String, dynamic>> list = [];

    grouped.forEach((key, value) {
      // ✅ IMPLEMENTED: Use custom budget limit if available, otherwise default to 500
      double budgetLimit = customLimits[key] ?? 0.0;

      list.add({
        "title": key,
        "spent": (value["spent"] as num).toDouble(),
        "total": budgetLimit,
        "items": value["items"]
      });
    });

    setState(() {
      budgetData = list;
      loading = false;
    });
  }

  // ✅ IMPLEMENTED: Edit budget function using category_budgets table
  Future<void> _editBudget(String categoryName, double currentLimit) async {
    final TextEditingController controller =
    TextEditingController(text: currentLimit.toStringAsFixed(0));

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Edit Budget',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set budget limit for $categoryName',
              style: const TextStyle(color: Colors.white70),
            ),
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
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8CFF),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      // ✅ IMPLEMENTED: Save to category_budgets table using upsert
      try {
        await supabase.from('category_budgets').upsert({
          'category_name': categoryName,
          'budget_amount': result,
          'updated_at': DateTime.now().toIso8601String(),
        });

        await fetchBudget(); // Refresh data

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Budget for $categoryName updated to ₹${result.toStringAsFixed(0)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving budget: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ IMPLEMENTED: Show onboarding prompt for first-time users
  Future<void> _showOnboardingPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSeenOnboarding = prefs.getBool('has_seen_budget_onboarding') ?? false;

    if (!hasSeenOnboarding) {
      // Wait for budget data to load
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1F2E),
            title: const Text(
              'Welcome to Budget Tracking!',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'You can set custom budgets for each category by tapping the edit icon or the budget card. '
                  'Your budgets will be saved and synced across devices. '
                  'Default budget is set to ₹500 for all categories.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  prefs.setBool('has_seen_budget_onboarding', true);
                  Navigator.pop(context);
                },
                child: const Text('Got it', style: TextStyle(color: Color(0xFF5B8CFF))),
              ),
            ],
          ),
        );
      }
    }
  }

  // ✅ IMPLEMENTED: Quick budget setup for all categories
  Future<void> _quickBudgetSetup() async {
    if (budgetData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No expense categories found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final List<String> categories =
    budgetData.map((e) => e['title'] as String).toList();

    Map<String, TextEditingController> controllers = {};

    for (var cat in categories) {
      double current =
      (budgetData.firstWhere((e) => e['title'] == cat)['total'] as num)
          .toDouble();

      controllers[cat] =
          TextEditingController(text: current == 0 ? "" : current.toString());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: _GlassContainer(
            child: SafeArea(
              child: Column(
                children: [
                  const Text(
                    "Quick Budget Setup",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
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
                              const Icon(Icons.category,
                                  color: Color(0xFF5B8CFF)),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              SizedBox(
                                width: 120,
                                child: TextField(
                                  controller: controllers[category],
                                  keyboardType: TextInputType.number,
                                  style:
                                  const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    prefixText: "₹ ",
                                    hintText: "Amount",
                                    hintStyle: const TextStyle(
                                        color: Colors.white38),
                                    filled: true,
                                    fillColor:
                                    Colors.white.withOpacity(0.1),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(10),
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5B8CFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        List<Map<String, dynamic>> data = [];

                        controllers.forEach((category, controller) {
                          final amount =
                          double.tryParse(controller.text);

                          if (amount != null && amount > 0) {
                            data.add({
                              'category_name': category,
                              'budget_amount': amount,
                              'updated_at':
                              DateTime.now().toIso8601String(),
                            });
                          }
                        });

                        if (data.isEmpty) return;

                        await supabase
                            .from('category_budgets')
                            .upsert(data);

                        if (mounted) {
                          Navigator.pop(context);

                          await fetchBudget();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content:
                              Text("Budgets saved successfully"),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      child: const Text("Save All"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void changePeriod(bool value) async {
    setState(() {
      weekly = value;
    });
    await fetchBudget();
  }

  Future<void> refresh() async {
    await fetchBudget();
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
                _header(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: refresh,
                    child: loading
                        ? const Center(
                      child: CircularProgressIndicator(),
                    )
                        : budgetData.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.white.withOpacity(0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No expenses found',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add expenses to track budgets',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView(
                      padding:
                      const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      children: [
                        _PeriodToggle(
                          weekly: weekly,
                          onChanged: changePeriod,
                        ),
                        const SizedBox(height: 20),

                        // ✅ IMPLEMENTED: Global Set Budgets button with options
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              _GlassContainer(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: PopupMenuButton<String>(
                                  offset: const Offset(0, 40),
                                  color: const Color(0xFF1A1F2E),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                          Text('Reset to Default', style: TextStyle(color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Color(0xFF5B8CFF),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Set Budgets',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 12,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_drop_down,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        ...budgetData.map((e) => _BudgetCard(
                          title: e["title"],
                          spent:
                          (e["spent"] as num).toDouble(),
                          total:
                          (e["total"] as num).toDouble(),
                          items: e["items"],
                          onEdit: () => _editBudget(
                              e["title"],
                              (e["total"] as num).toDouble()
                          ),
                        ))
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

  // ✅ IMPLEMENTED: Reset all budgets to default ₹500
  Future<void> _showResetBudgetsDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Reset Budgets',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to reset all category budgets to ₹0.0?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final categories = budgetData.map((e) => e['title'] as String).toSet();

        for (var category in categories) {
          await supabase.from('category_budgets').upsert({
            'category_name': category,
            'budget_amount': 0,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        await fetchBudget();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All budgets reset to ₹0.0'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting budgets: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ✅ IMPLEMENTED: Added back navigation button
  Widget _header() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              "Budget Tracking",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: refresh,
          )
        ],
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

class _PeriodToggle extends StatelessWidget {
  final bool weekly;
  final Function(bool) onChanged;

  const _PeriodToggle({
    required this.weekly,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassContainer(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleChip(
              label: "Monthly",
              active: !weekly,
              onTap: () => onChanged(false),
            ),
            _ToggleChip(
              label: "Weekly",
              active: weekly,
              onTap: () => onChanged(true),
            ),
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

  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF5B8CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
            fontWeight: FontWeight.w500,
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
  final VoidCallback onEdit;

  const _BudgetCard({
    required this.title,
    required this.spent,
    required this.total,
    required this.items,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final double percent = total == 0 ? 0 : (spent / total).clamp(0.0, 2.0).toDouble();
    final bool isOverBudget = spent > total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: onEdit, // ✅ IMPLEMENTED: Tap card to edit
        child: _GlassContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // ✅ IMPLEMENTED: Edit icon
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18, color: Colors.white70),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${(percent * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 12,
                      color: isOverBudget ? Colors.redAccent : Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "₹${spent.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isOverBudget ? Colors.redAccent : Colors.white,
                    ),
                  ),
                  Text(
                    " of ₹${total.toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  if (isOverBudget) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 12,
                            color: Colors.redAccent,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Over budget',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percent.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white.withOpacity(0.08),
                  valueColor: AlwaysStoppedAnimation(
                    isOverBudget ? Colors.redAccent : const Color(0xFF5B8CFF),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "${i["date"]}  ${i["description"]}  ₹${(i["amount"] as num).toDouble().toStringAsFixed(2)}  ${i["vendor"]}  ${i["method"]}",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
            ],
          ),
        ),
      ),
    );
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
        filter:
        ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding:
          padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color:
              Colors.white.withOpacity(0.10),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}