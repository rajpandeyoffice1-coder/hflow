// lib/models/investment_models.dart
class Investment {
  final String id;
  final String date;
  final String category;
  final String? subCategory;
  final double amount;
  final String owner;
  final String paymentMethod;
  final String comments;
  double redeemedAmount;
  List<Redemption> redemptions;
  final int? categoryId;
  final int? subCategoryId;
  final String? goalId;

  Investment({
    required this.id,
    required this.date,
    required this.category,
    this.subCategory,
    required this.amount,
    required this.owner,
    required this.paymentMethod,
    this.comments = '',
    this.redeemedAmount = 0,
    List<Redemption>? redemptions,
    this.categoryId,
    this.subCategoryId,
    this.goalId,
  }) : redemptions = redemptions ?? [];

  double get currentValue {
    double growthFactor = _getGrowthFactor();
    return (amount - redeemedAmount) * growthFactor;
  }

  double get projected5Y {
    return currentValue * 1.5; // 50% growth over 5 years
  }

  double _getGrowthFactor() {
    final cat = category.toLowerCase();

    if (cat.contains('mutual')) return 1.12;
    if (cat.contains('stock')) return 1.08;
    if (cat.contains('fixed')) return 1.05;
    if (cat.contains('gold')) return 1.10;
    if (cat.contains('real')) return 1.15;
    if (cat.contains('crypto')) return 1.20;

    return 1.06;
  }


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'amount': amount,
      'category': category,
      'sub_category': subCategory,
      'owner': owner,
      'payment_method': paymentMethod,
      'comments': comments,
      'redeemed_amount': redeemedAmount,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'goal_id': goalId,
    };
  }

  factory Investment.fromJson(Map<String, dynamic> json) {
    return Investment(
      id: json['id']?.toString() ?? '',
      date: json['date'] ?? '',
      category: json['category_name'] ?? '', // change
      subCategory: json['sub_category_name'],
      amount: (json['amount'] ?? 0).toDouble(),
      owner: json['owner'] ?? 'Hari',
      paymentMethod: json['payment_method'] ?? '',
      comments: json['comments'] ?? '',
      redeemedAmount: (json['redeemed_amount'] ?? 0).toDouble(),
      categoryId: json['category_id'],
      subCategoryId: json['sub_category_id'],
      goalId: json['goal_id']?.toString(),
    );
  }
}

class Redemption {
  final String id;
  final double amount;
  final DateTime date;
  final String notes;

  Redemption({
    required this.id,
    required this.amount,
    required this.date,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'redemption_date': date.toIso8601String().split('T')[0],
      'notes': notes,
    };
  }

  factory Redemption.fromJson(Map<String, dynamic> json) {
    return Redemption(
      id: json['id']?.toString() ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      date: DateTime.parse(json['redemption_date'] ?? DateTime.now().toIso8601String()),
      notes: json['notes'] ?? '',
    );
  }
}

class Category {
  final int id;
  final String name;
  final String icon;
  final String color;
  List<SubCategory> subCategories;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    this.color = '#6366F1',
    this.subCategories = const [],
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      icon: json['icon'] ?? '💎',
      color: json['color'] ?? '#6366F1',
    );
  }
}

class SubCategory {
  final int id;
  final String name;
  final int categoryId;
  final String icon;
  final String color;

  SubCategory({
    required this.id,
    required this.name,
    required this.categoryId,
    this.icon = '📌',
    this.color = '#6366F1',
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id'],
      name: json['name'],
      categoryId: json['category_id'],
      icon: json['icon'] ?? '📌',
      color: json['color'] ?? '#6366F1',
    );
  }
}

class FinancialGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final String icon;
  final String color;
  final bool isCompleted;

  FinancialGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.deadline,
    this.icon = '🎯',
    this.color = '#6366F1',
    this.isCompleted = false,
  });

  factory FinancialGoal.fromJson(Map<String, dynamic> json) {
    return FinancialGoal(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      targetAmount: (json['target_amount'] ?? 0).toDouble(),
      currentAmount: (json['current_amount'] ?? 0).toDouble(),
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
      icon: json['icon'] ?? '🎯',
      color: json['color'] ?? '#6366F1',
      isCompleted: json['is_completed'] ?? false,
    );
  }
}