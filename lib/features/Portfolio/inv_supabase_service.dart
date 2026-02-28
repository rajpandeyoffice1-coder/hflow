// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/investment_models.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final String userId = 'default_user'; // In production, get from auth

  // Categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _client
        .from('investment_categories')
        .select()
        .eq('user_id', userId);

    return response as List<Map<String, dynamic>>;
  }

  Future<List<Map<String, dynamic>>> getSubCategories() async {
    final response = await _client
        .from('investment_sub_categories')
        .select()
        .eq('user_id', userId);

    return response as List<Map<String, dynamic>>;
  }

  // Investments
  Future<List<Map<String, dynamic>>> getInvestments() async {
    final response = await _client
        .from('investments')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false);

    return response as List<Map<String, dynamic>>;
  }

  Future<void> addInvestment(Investment investment) async {
    await _client.from('investments').insert({
      'user_id': userId,
      'date': investment.date,
      'amount': investment.amount,
      'category_id': investment.categoryId,
      'sub_category_id': investment.subCategoryId,
      'comments': investment.comments,
      'payment_method': investment.paymentMethod,
      'owner': investment.owner,
    });
  }

  Future<void> updateInvestment(Investment investment) async {
    await _client
        .from('investments')
        .update({
          'date': investment.date,
          'amount': investment.amount,
          'category': investment.category,
          'sub_category': investment.subCategory,
          'owner': investment.owner,
          'payment_method': investment.paymentMethod,
          'comments': investment.comments,
          'category_id': investment.categoryId,
          'sub_category_id': investment.subCategoryId,
        })
        .eq('id', int.parse(investment.id));
  }

  Future<void> deleteInvestment(String id) async {
    await _client.from('investments').delete().eq('id', int.parse(id));
  }

  // Redemptions
  Future<List<Redemption>> getRedemptions(String investmentId) async {
    final response = await _client
        .from('investment_redemptions')
        .select()
        .eq('investment_id', investmentId);

    return (response as List).map((json) => Redemption.fromJson(json)).toList();
  }

  Future<void> addRedemption(
    String investmentId,
    double amount,
    String notes,
  ) async {
    await _client.from('investment_redemptions').insert({
      'user_id': userId,
      'investment_id': investmentId,
      'amount': amount,
      'redemption_date': DateTime.now().toIso8601String().split('T')[0],
      'redemption_type': 'partial',
      'notes': notes,
    });
  }

  // Financial Goals
  Future<List<Map<String, dynamic>>> getFinancialGoals() async {
    final response = await _client
        .from('financial_goals')
        .select()
        .eq('user_id', userId);

    return response as List<Map<String, dynamic>>;
  }

  Future<List<Redemption>> getAllRedemptions() async {
    final response = await _client
        .from('investment_redemptions') // ✅ correct table
        .select()
        .eq('user_id', userId);

    return (response as List).map((json) => Redemption.fromJson(json)).toList();
  }
}
