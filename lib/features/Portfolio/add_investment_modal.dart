// lib/screens/investment/add_investment_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/investment_models.dart';
import 'inv_supabase_service.dart';

class AddInvestmentModal extends StatefulWidget {
  final Investment? investment;
  final List<Category> categories;
  final Function(Investment) onSave;
  final List<FinancialGoal> goals;
  final String? goalId;

  const AddInvestmentModal({
    super.key,
    this.investment,
    required this.categories,
    required this.goals,
    required this.onSave,
    this.goalId,
  });

  @override
  State<AddInvestmentModal> createState() => _AddInvestmentModalState();
}

class _AddInvestmentModalState extends State<AddInvestmentModal> {
  late TextEditingController _dateController;
  late TextEditingController _amountController;
  late TextEditingController _commentsController;


  late String _selectedCategory;
  String? _selectedSubCategory;
  late String _selectedOwner;
  String _selectedPaymentMethod = '';
  int? _selectedCategoryId;
  String? _selectedGoalId;

  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();

    if (widget.investment != null) {
      _dateController = TextEditingController(text: widget.investment!.date);
      _amountController = TextEditingController(
        text: widget.investment!.amount.toString(),
      );
      _selectedCategory = widget.investment!.category.trim();
      _selectedSubCategory = widget.investment!.subCategory;
      _selectedOwner = widget.investment!.owner;
      _selectedPaymentMethod = widget.investment!.paymentMethod;
      _commentsController = TextEditingController(
        text: widget.investment!.comments,
      );

      final category = widget.categories.firstWhere(
        (c) => c.name == widget.investment!.category,
        orElse: () => Category(id: 0, name: '', icon: ''),
      );
      _selectedCategoryId = category.id;
    } else {
      _dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      _amountController = TextEditingController();
      _selectedCategory = '';
      _selectedOwner = 'Hari';
      _commentsController = TextEditingController();
      _selectedGoalId = widget.investment?.goalId ?? widget.goalId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F1A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              _buildHeader(),

              /// SCROLLABLE FORM
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildDateAndAmountRow(),
                      const SizedBox(height: 16),
                      _buildCategoryRow(),
                      const SizedBox(height: 16),
                      _buildOwnerAndPaymentRow(),
                      const SizedBox(height: 16),
                      _buildGoalSelector(),
                      const SizedBox(height: 16),
                      _buildCommentsField(),
                    ],
                  ),
                ),
              ),

              _buildFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGoalSelector() {
    if (widget.goals.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial Goal',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String?>(
            value: _selectedGoalId,
            hint: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Link Goal (Optional)',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            isExpanded: true,
            dropdownColor: const Color(0xFF1A1F2E),
            underline: const SizedBox(),
            icon: const Icon(Icons.flag, color: Colors.white),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'No Goal',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              ...widget.goals.map((goal) {
                return DropdownMenuItem<String?>(
                  value: goal.id,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${goal.icon} ${goal.name}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }).toList(),
            ],
            onChanged: (value) {
              setState(() {
                _selectedGoalId = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.investment == null
                      ? 'Add Investment'
                      : 'Edit Investment',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.investment == null
                      ? 'Track your investments and grow your wealth'
                      : 'Update your investment details',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAndAmountRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _dateController,
            label: 'Date',
            hint: 'YYYY-MM-DD',
            icon: Icons.calendar_today,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTextField(
            controller: _amountController,
            label: 'Amount',
            hint: '10000',
            icon: Icons.currency_rupee,
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow() {
    final categoryNames =
    widget.categories.map((c) => c.name.trim()).toSet().toList();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: categoryNames.contains(_selectedCategory.trim())
                      ? _selectedCategory.trim()
                      : null,
                  hint: const Text(
                    'Select Category',
                    style: TextStyle(color: Colors.white38),
                  ),
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1F2E),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: [
                    ...categoryNames.map((name) {
                      final cat = widget.categories.firstWhere(
                            (c) => c.name.trim() == name,
                      );

                      return DropdownMenuItem(
                        value: name,
                        child: Text(
                          '${cat.icon} $name',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }),

                    const DropdownMenuItem(
                      value: "__add_category__",
                      child: Text(
                        "+ Add Category",
                        style: TextStyle(color: Color(0xFF5B8CFF)),
                      ),
                    )
                  ],
                  onChanged: (value) {
                    if (value == "__add_category__") {
                      _showAddCategoryDialog();
                      return;
                    }

                    if (value != null) {
                      final category = widget.categories.firstWhere(
                            (c) => c.name.trim() == value,
                      );

                      setState(() {
                        _selectedCategory = value;
                        _selectedSubCategory = null;
                        _selectedCategoryId = category.id;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        if (_selectedCategoryId != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sub-Category',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedSubCategory,
                    hint: const Text(
                      'Select',
                      style: TextStyle(color: Colors.white38),
                    ),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1F2E),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    items: [
                      ...widget.categories
                          .firstWhere((c) => c.id == _selectedCategoryId)
                          .subCategories
                          .map((sub) {
                        return DropdownMenuItem(
                          value: sub.name,
                          child: Text(
                            '${sub.icon} ${sub.name}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }),

                      const DropdownMenuItem(
                        value: "__add_sub__",
                        child: Text(
                          "+ Add SubCategory",
                          style: TextStyle(color: Color(0xFF5B8CFF)),
                        ),
                      )
                    ],
                    onChanged: (value) {
                      if (value == "__add_sub__") {
                        _showAddSubCategoryDialog();
                        return;
                      }

                      setState(() {
                        _selectedSubCategory = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1F2E),
          title: const Text("Add Category", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Category name",
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {

                final name = controller.text.trim();
                if (name.isEmpty) return;

                final id = await _supabaseService.addCategory(name);

                if (id == null) return;

                final newCat = Category(
                  id: id,
                  name: name,
                  icon: "💰",
                );

                setState(() {
                  widget.categories.add(newCat);
                  _selectedCategory = name;
                  _selectedCategoryId = id;
                });

                Navigator.pop(context);
              },
              child: const Text("Add"),
            )
          ],
        );
      },
    );
  }

  void _showAddSubCategoryDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1F2E),
          title:
          const Text("Add SubCategory", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Sub category name",
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {

                final name = controller.text.trim();
                if (name.isEmpty) return;

                final id = await _supabaseService.addSubCategory(
                    _selectedCategoryId!, name);

                if (id == null) return;

                final category =
                widget.categories.firstWhere((c) => c.id == _selectedCategoryId);

                final sub = SubCategory(
                  id: id,
                  name: name,
                  categoryId: category.id,
                );

                setState(() {
                  category.subCategories.add(sub);
                  _selectedSubCategory = name;
                });

                Navigator.pop(context);
              } ,
              child: const Text("Add"),
            )
          ],
        );
      },
    );
  }

  Widget _buildOwnerAndPaymentRow() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Owner',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedOwner,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1F2E),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: 'Hari',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Color(0xFF5B8CFF),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text('Hari', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Sangeetha',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sangeetha',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedOwner = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Method',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _selectedPaymentMethod.isNotEmpty
                      ? _selectedPaymentMethod
                      : null,
                  hint: const Text(
                    'Select',
                    style: TextStyle(color: Colors.white38),
                  ),
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1F2E),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: 'Bank Transfer',
                      child: Text(
                        '🏦 Bank Transfer',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'UPI',
                      child: Text(
                        '📱 UPI',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Cash',
                      child: Text(
                        '💵 Cash',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Cheque',
                      child: Text(
                        '📝 Cheque',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Auto-Debit',
                      child: Text(
                        '🔄 Auto-Debit',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedPaymentMethod = value);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comments / Notes',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _commentsController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add any notes about this investment...',
              hintStyle: const TextStyle(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            keyboardType: keyboardType,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Colors.white54, size: 16),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.12))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B8CFF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                widget.investment == null
                    ? 'Save Investment'
                    : 'Update Investment',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSave() {

    if (_amountController.text.isEmpty || _selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all required fields'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final amount = double.parse(_amountController.text);

    /// CHECK GOAL LIMIT
    if (_selectedGoalId != null) {

      final goal = widget.goals.firstWhere(
            (g) => g.id == _selectedGoalId,
      );

      double currentGoalAmount = goal.currentAmount;

      /// when editing subtract previous amount
      if (widget.investment != null &&
          widget.investment!.goalId == _selectedGoalId) {
        currentGoalAmount -= widget.investment!.amount;
      }

      if (currentGoalAmount + amount > goal.targetAmount) {

        final remaining = goal.targetAmount - currentGoalAmount;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Goal limit exceeded.\nRemaining allowed: ₹${remaining.toStringAsFixed(0)}",
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );

        return;
      }
    }

    final investment = Investment(
      id: widget.investment?.id ?? '',
      date: _dateController.text,
      category: _selectedCategory,
      subCategory: _selectedSubCategory,
      amount: amount,
      owner: _selectedOwner,
      paymentMethod: _selectedPaymentMethod,
      comments: _commentsController.text,
      redeemedAmount: widget.investment?.redeemedAmount ?? 0,
      redemptions: widget.investment?.redemptions ?? [],
      categoryId: _selectedCategoryId,
      goalId: _selectedGoalId,
    );

    widget.onSave(investment);
  }


  @override
  void dispose() {
    _dateController.dispose();
    _amountController.dispose();
    _commentsController.dispose();
    super.dispose();
  }
}
