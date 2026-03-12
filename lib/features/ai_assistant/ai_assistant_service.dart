// lib/services/ai_assistant_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class AIAssistantService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Store conversation history
  final List<ChatMessage> _messageHistory = [];

  // Get conversation history
  List<ChatMessage> get messageHistory => List.unmodifiable(_messageHistory);

  // Add message to history
  void addMessage(ChatMessage message) {
    _messageHistory.add(message);
  }

  // Clear history
  void clearHistory() {
    _messageHistory.clear();
  }

  // Process user query and return AI response
  Future<ChatMessage> processQuery(String query) async {
    try {
      // Add user message to history
      final userMessage = ChatMessage(
        text: query,
        isUser: true,
        timestamp: DateTime.now(),
      );
      addMessage(userMessage);

      // Determine intent and fetch relevant data
      final response = await _fetchRelevantData(query);

      // Add AI response to history
      final aiMessage = ChatMessage(
        text: response.text,
        isUser: false,
        timestamp: DateTime.now(),
        dataType: response.dataType,
        data: response.data,
      );
      addMessage(aiMessage);

      return aiMessage;
    } catch (e) {
      return ChatMessage(
        text: "I encountered an error: $e",
        isUser: false,
        timestamp: DateTime.now(),
      );
    }
  }

  // Fetch relevant data based on query intent
  Future<AIResponse> _fetchRelevantData(String query) async {
    final lowercaseQuery = query.toLowerCase();

    // Determine query type
    if (lowercaseQuery.contains('invoice') || lowercaseQuery.contains('bill')) {
      return await _handleInvoiceQuery(query);
    } else if (lowercaseQuery.contains('expense') ||
        lowercaseQuery.contains('spent') ||
        lowercaseQuery.contains('spending')) {
      return await _handleExpenseQuery(query);
    } else if (lowercaseQuery.contains('investment') ||
        lowercaseQuery.contains('mutual fund') ||
        lowercaseQuery.contains('sip')) {
      return await _handleInvestmentQuery(query);
    } else if (lowercaseQuery.contains('tax')) {
      return await _handleTaxQuery(query);
    } else if (lowercaseQuery.contains('client') ||
        lowercaseQuery.contains('customer')) {
      return await _handleClientQuery(query);
    } else if (lowercaseQuery.contains('balance') ||
        lowercaseQuery.contains('summary')) {
      return await _handleBalanceQuery(query);
    } else if (lowercaseQuery.contains('goal')) {
      return await _handleGoalQuery(query);
    } else {
      return await _handleGeneralQuery(query);
    }
  }

  // Handle invoice-related queries
  Future<AIResponse> _handleInvoiceQuery(String query) async {
    final lowercaseQuery = query.toLowerCase();

    try {
      // Check for specific invoice requests
      if (lowercaseQuery.contains('create') || lowercaseQuery.contains('new')) {
        return AIResponse(
          text: "I can help you create a new invoice. What would you like to include?",
          dataType: DataType.invoiceCreation,
          data: null,
        );
      }

      // Fetch recent invoices
      final invoices = await _supabase
          .from('invoices')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      if (invoices.isEmpty) {
        return AIResponse(
          text: "You don't have any invoices yet. Would you like to create one?",
          dataType: DataType.empty,
          data: null,
        );
      }

      // Check for status filter
      if (lowercaseQuery.contains('pending') || lowercaseQuery.contains('unpaid')) {
        final pendingInvoices = await _supabase
            .from('invoices')
            .select()
            .eq('status', 'Pending')
            .order('due_date', ascending: true);

        final totalPending = pendingInvoices.fold<double>(
            0, (sum, inv) => sum + (inv['amount'] as num).toDouble()
        );

        return AIResponse(
          text: "You have ${pendingInvoices.length} pending invoices totaling ₹${totalPending.toStringAsFixed(2)}",
          dataType: DataType.invoiceList,
          data: pendingInvoices,
        );
      }


      // Calculate totals
      final totalAmount = invoices.fold<double>(
          0, (sum, inv) => sum + (inv['amount'] as num).toDouble()
      );

      return AIResponse(
        text: "Here are your recent invoices. Total amount: ₹${totalAmount.toStringAsFixed(2)}",
        dataType: DataType.invoiceList,
        data: invoices,
      );
    } catch (e) {
      return AIResponse(
        text: "I found some invoice information but couldn't process it completely.",
        dataType: DataType.general,
        data: null,
      );
    }
  }

  // Handle expense-related queries
  Future<AIResponse> _handleExpenseQuery(String query) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    try {
      // Get current month expenses
      final expenses = await _supabase
          .from('expenses')
          .select('''
            *,
            expense_categories (
              name,
              icon,
              color
            )
          ''')
          .gte('date_incurred', firstDayOfMonth.toIso8601String())
          .order('date_incurred', ascending: false);

      if (expenses.isEmpty) {
        return AIResponse(
          text: "You haven't recorded any expenses this month.",
          dataType: DataType.empty,
          data: null,
        );
      }

      // Calculate totals
      final totalExpenses = expenses.fold<double>(
          0, (sum, exp) => sum + (exp['amount'] as num).toDouble()
      );

      // Group by category
      final Map<String, double> categoryTotals = {};
      for (var exp in expenses) {
        final category = exp['expense_categories']?['name'] ?? exp['category_name'] ?? 'Uncategorized';
        categoryTotals[category] = (categoryTotals[category] ?? 0) + (exp['amount'] as num).toDouble();
      }

      // Find top category
      String topCategory = '';
      double topAmount = 0;
      categoryTotals.forEach((category, amount) {
        if (amount > topAmount) {
          topAmount = amount;
          topCategory = category;
        }
      });

      return AIResponse(
        text: "This month you've spent ₹${totalExpenses.toStringAsFixed(2)}. Your highest spending category is $topCategory (₹${topAmount.toStringAsFixed(2)}).",
        dataType: DataType.expenseList,
        data: expenses,
      );
    } catch (e) {
      return AIResponse(
        text: "I found some expense information but couldn't process it completely.",
        dataType: DataType.general,
        data: null,
      );
    }
  }

  // Handle investment queries
  Future<AIResponse> _handleInvestmentQuery(String query) async {
    try {
      final lowercaseQuery = query.toLowerCase();

      // Check for SIP queries
      if (lowercaseQuery.contains('sip')) {
        final sips = await _supabase
            .from('investment_sub_categories')
            .select('''
              *,
              investment_categories (*)
            ''')
            .eq('is_recurring', true)
            .eq('is_active', true);

        if (sips.isEmpty) {
          return AIResponse(
            text: "You don't have any active SIPs configured.",
            dataType: DataType.empty,
            data: null,
          );
        }

        final totalSipAmount = sips.fold<double>(
            0, (sum, sip) => sum + (sip['recurring_amount'] ?? 0).toDouble()
        );

        return AIResponse(
          text: "You have ${sips.length} active SIPs totaling ₹${totalSipAmount.toStringAsFixed(2)} per month.",
          dataType: DataType.sipList,
          data: sips,
        );
      }

      // Get total investments
      final investments = await _supabase
          .from('investments')
          .select('''
            *,
            investment_categories (*)
          ''')
          .order('date', ascending: false)
          .limit(20);

      if (investments.isEmpty) {
        return AIResponse(
          text: "You haven't recorded any investments yet.",
          dataType: DataType.empty,
          data: null,
        );
      }

      final totalInvested = investments.fold<double>(
          0, (sum, inv) => sum + (inv['amount'] as num).toDouble()
      );

      return AIResponse(
        text: "Your total investments amount to ₹${totalInvested.toStringAsFixed(2)} across ${investments.length} transactions.",
        dataType: DataType.investmentList,
        data: investments,
      );
    } catch (e) {
      return AIResponse(
        text: "I found some investment information but couldn't process it completely.",
        dataType: DataType.general,
        data: null,
      );
    }
  }

  // Handle tax queries
  Future<AIResponse> _handleTaxQuery(String query) async {
    final currentYear = DateTime.now().year;
    final fiscalYear = currentYear.toString();

    try {
      // Get tax calculations
      final taxCalc = await _supabase
          .from('tax_calculations')
          .select()
          .eq('fiscal_year', fiscalYear)
          .order('calculation_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (taxCalc != null) {
        return AIResponse(
          text: "For FY $fiscalYear, your estimated tax liability is ₹${(taxCalc['total_tax_liability'] as num).toStringAsFixed(2)}. You can save up to ₹${(taxCalc['potential_savings'] ?? 0).toStringAsFixed(2)} by choosing the ${taxCalc['recommended_regime']} tax regime.",
          dataType: DataType.taxSummary,
          data: taxCalc,
        );
      }

      // Get deductions
      final deductions = await _supabase
          .from('tax_deductions')
          .select()
          .eq('fiscal_year', fiscalYear);

      if (deductions.isNotEmpty) {
        final totalDeductions = deductions.fold<double>(
            0, (sum, d) => sum + (d['amount'] as num).toDouble()
        );

        return AIResponse(
          text: "You've claimed ₹${totalDeductions.toStringAsFixed(2)} in tax deductions for FY $fiscalYear.",
          dataType: DataType.deductionList,
          data: deductions,
        );
      }

      return AIResponse(
        text: "I don't have any tax information for FY $fiscalYear. Would you like to start tax planning?",
        dataType: DataType.general,
        data: null,
      );
    } catch (e) {
      return AIResponse(
        text: "I found some tax information but couldn't process it completely.",
        dataType: DataType.general,
        data: null,
      );
    }
  }

  // Handle client queries
  Future<AIResponse> _handleClientQuery(String query) async {
    try {
      final clients = await _supabase
          .from('clients')
          .select()
          .order('total_amount', ascending: false)
          .limit(10);

      if (clients.isEmpty) {
        return AIResponse(
          text: "You don't have any clients in your database yet.",
          dataType: DataType.empty,
          data: null,
        );
      }

      final totalClients = clients.length;
      final totalRevenue = clients.fold<double>(
          0, (sum, c) => sum + (c['total_amount'] ?? 0).toDouble()
      );

      // Find top client
      String topClient = '';
      double topAmount = 0;
      for (var client in clients) {
        final amount = (client['total_amount'] ?? 0).toDouble();
        if (amount > topAmount) {
          topAmount = amount;
          topClient = client['name'] ?? '';
        }
      }

      return AIResponse(
        text: "You have $totalClients clients with total revenue of ₹${totalRevenue.toStringAsFixed(2)}. Your top client is $topClient (₹${topAmount.toStringAsFixed(2)}).",
        dataType: DataType.clientList,
        data: clients,
      );
    } catch (e) {
      return AIResponse(
        text: "I found some client information but couldn't process it completely.",
        dataType: DataType.general,
        data: null,
      );
    }
  }

  // Handle balance queries
  Future<AIResponse> _handleBalanceQuery(String query) async {
    try {
      // Get balance summary
      final balance = await _supabase
          .from('balance_summary')
          .select()
          .order('last_calculated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (balance != null) {
        return AIResponse(
          text: "Current balance: ₹${(balance['current_balance'] as num).toStringAsFixed(2)}. Total earnings: ₹${(balance['total_earnings'] as num).toStringAsFixed(2)}. Total expenses: ₹${(balance['total_expenses'] as num).toStringAsFixed(2)}.",
          dataType: DataType.balanceSummary,
          data: balance,
        );
      }

      // Calculate from invoices and expenses
      final invoices = await _supabase
          .from('invoices')
          .select('amount')
          .eq('status', 'Paid');

      final expenses = await _supabase
          .from('expenses')
          .select('amount');

      final totalEarnings = invoices.fold<double>(
          0, (sum, inv) => sum + (inv['amount'] as num).toDouble()
      );

      final totalExpenses = expenses.fold<double>(
          0, (sum, exp) => sum + (exp['amount'] as num).toDouble()
      );

      final currentBalance = totalEarnings - totalExpenses;

      return AIResponse(
        text: "Current balance: ₹${currentBalance.toStringAsFixed(2)}. Total earnings: ₹${totalEarnings.toStringAsFixed(2)}. Total expenses: ₹${totalExpenses.toStringAsFixed(2)}.",
        dataType: DataType.balanceSummary,
        data: {
          'current_balance': currentBalance,
          'total_earnings': totalEarnings,
          'total_expenses': totalExpenses,
        },
      );
    } catch (e) {
      return AIResponse(
        text: "I found some balance information but couldn't process it completely.",
        dataType: DataType.general,
        data: null,
      );
    }
  }

  // Handle goal queries
  Future<AIResponse> _handleGoalQuery(String query) async {
    try {
      final goals = await _supabase
          .from('financial_goals')
          .select()
          .order('deadline', ascending: true);

      if (goals.isEmpty) {
        return AIResponse(
          text: "You haven't set any financial goals yet. Would you like to create one?",
          dataType: DataType.empty,
          data: null,
        );
      }

      final activeGoals = goals.where((g) => !(g['is_completed'] ?? false)).toList();

      if (activeGoals.isEmpty) {
        return AIResponse(
          text: "Congratulations! You've completed all your financial goals.",
          dataType: DataType.goalList,
          data: goals,
        );
      }

      return AIResponse(
        text: "You have ${activeGoals.length} active financial goals. Your next goal is '${activeGoals.first['name']}' with target ₹${(activeGoals.first['target_amount'] as num).toStringAsFixed(2)}.",
        dataType: DataType.goalList,
        data: activeGoals,
      );
    } catch (e) {
      return AIResponse(
        text: "I found some goal information but couldn't process it completely.",
        dataType: DataType.general,
        data: null,
      );
    }
  }

  // Handle general queries
  Future<AIResponse> _handleGeneralQuery(String query) async {
    // Search across multiple tables
    try {
      final results = <String, dynamic>{};

      // Search invoices
      final invoices = await _supabase
          .from('invoices')
          .select()
          .ilike('client_name', '%$query%')
          .limit(5);

      if (invoices.isNotEmpty) {
        results['invoices'] = invoices;
      }

      // Search expenses
      final expenses = await _supabase
          .from('expenses')
          .select()
          .ilike('description', '%$query%')
          .limit(5);

      if (expenses.isNotEmpty) {
        results['expenses'] = expenses;
      }

      // Search clients
      final clients = await _supabase
          .from('clients')
          .select()
          .ilike('name', '%$query%')
          .limit(5);

      if (clients.isNotEmpty) {
        results['clients'] = clients;
      }

      if (results.isEmpty) {
        return AIResponse(
          text: "I couldn't find any information matching '$query'. Would you like to ask about invoices, expenses, investments, or something else?",
          dataType: DataType.general,
          data: null,
        );
      }

      return AIResponse(
        text: "I found some information related to '$query'.",
        dataType: DataType.searchResults,
        data: results,
      );
    } catch (e) {
      return AIResponse(
        text: "I'm here to help with your financial data. You can ask about invoices, expenses, investments, taxes, clients, or your current balance.",
        dataType: DataType.general,
        data: null,
      );
    }
  }
}

// Data models
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final DataType dataType;
  final dynamic data;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.dataType = DataType.general,
    this.data,
  });
}

enum DataType {
  general,
  invoiceList,
  invoiceCreation,
  expenseList,
  investmentList,
  sipList,
  taxSummary,
  deductionList,
  clientList,
  balanceSummary,
  goalList,
  searchResults,
  empty,
}

class AIResponse {
  final String text;
  final DataType dataType;
  final dynamic data;

  AIResponse({
    required this.text,
    required this.dataType,
    this.data,
  });
}