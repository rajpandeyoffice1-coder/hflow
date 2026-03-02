import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // ========== INVOICE OPERATIONS ==========

  Future<List<Map<String, dynamic>>> getInvoices() async {
    try {
      final response = await _client
          .from('invoices')
          .select('*')
          .order('created_at', ascending: false);

      return _processInvoices(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      throw Exception('Failed to fetch invoices: $e');
    }
  }

  Future<Map<String, dynamic>> getInvoiceById(String id) async {
    try {
      final response =
          await _client.from('invoices').select('*').eq('id', id).single();

      return _processInvoice(response);
    } catch (e) {
      throw Exception('Failed to fetch invoice: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentInvoices({int limit = 5}) async {
    try {
      final response = await _client
          .from('invoices')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);

      return _processInvoices(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      throw Exception('Failed to fetch recent invoices: $e');
    }
  }

  Future<String> generateInvoiceNumber() async {
    final now = DateTime.now();
    final yearCode = '${now.year % 100}${(now.year + 1) % 100}'
        .padLeft(4, '0');
    final prefix = 'HP-$yearCode-';

    final existing = await _client
        .from('invoices')
        .select('id')
        .ilike('id', '$prefix%')
        .order('id', ascending: false)
        .limit(1);

    int nextNumber = 1;
    if (existing.isNotEmpty) {
      final latestId = existing.first['id']?.toString() ?? '';
      final tail = latestId.split('-').last;
      nextNumber = (int.tryParse(tail) ?? 0) + 1;
    }

    return '$prefix${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<void> markInvoiceAsPaid(String id) async {
    await updateInvoiceStatus(id, 'PAID');
    await recalculateBalanceSummary();
  }

  Future<void> duplicateInvoice(String id) async {
    final source = await getInvoiceById(id);
    final newId = await generateInvoiceNumber();
    final duplicate = Map<String, dynamic>.from(source)
      ..['id'] = newId
      ..['status'] = 'DRAFT'
      ..['created_at'] = DateTime.now().toIso8601String()
      ..['updated_at'] = DateTime.now().toIso8601String();

    await createInvoice(duplicate);
  }

  List<Map<String, dynamic>> _processInvoices(List<Map<String, dynamic>> invoices) {
    return invoices.map((invoice) => _processInvoice(invoice)).toList();
  }

  Map<String, dynamic> _processInvoice(Map<String, dynamic> invoice) {
    final processed = Map<String, dynamic>.from(invoice);

    if (processed['amount'] != null) {
      processed['amount'] = _toDouble(processed['amount']);
    }
    if (processed['subtotal'] != null) {
      processed['subtotal'] = _toDouble(processed['subtotal']);
    }
    if (processed['tax'] != null) {
      processed['tax'] = _toDouble(processed['tax']);
    }

    if (processed['items'] != null && processed['items'] is List) {
      processed['items'] = (processed['items'] as List).map((item) {
        final processedItem = Map<String, dynamic>.from(item);
        if (processedItem['rate'] != null) {
          processedItem['rate'] = _toDouble(processedItem['rate']);
        }
        if (processedItem['quantity'] != null) {
          processedItem['quantity'] = _toInt(processedItem['quantity']);
        }
        final quantity = _toDouble(processedItem['quantity']);
        final rate = _toDouble(processedItem['rate']);
        processedItem['amount'] = quantity * rate;
        return processedItem;
      }).toList();
    }

    return processed;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 1;
    return 1;
  }

  Future<void> createInvoice(Map<String, dynamic> invoiceData) async {
    try {
      await _client.from('invoices').insert({
        'id': invoiceData['id'],
        'client_id': invoiceData['client_id'],
        'client_name': invoiceData['client_name'],
        'amount': invoiceData['amount'],
        'subtotal': invoiceData['subtotal'],
        'tax': invoiceData['tax'],
        'date_issued': invoiceData['date_issued'],
        'due_date': invoiceData['due_date'],
        'status': invoiceData['status'],
        'items': invoiceData['items'],
        'notes': invoiceData['notes'] ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (invoiceData['client_id'] != null) {
        await _updateClientStats(invoiceData['client_id']);
      }
    } catch (e) {
      throw Exception('Failed to create invoice: $e');
    }
  }

  Future<void> updateInvoice(String id, Map<String, dynamic> invoiceData) async {
    try {
      await _client
          .from('invoices')
          .update({
            'client_id': invoiceData['client_id'],
            'client_name': invoiceData['client_name'],
            'amount': invoiceData['amount'],
            'subtotal': invoiceData['subtotal'],
            'tax': invoiceData['tax'],
            'date_issued': invoiceData['date_issued'],
            'due_date': invoiceData['due_date'],
            'status': invoiceData['status'],
            'items': invoiceData['items'],
            'notes': invoiceData['notes'] ?? '',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      if (invoiceData['client_id'] != null) {
        await _updateClientStats(invoiceData['client_id']);
      }
    } catch (e) {
      throw Exception('Failed to update invoice: $e');
    }
  }

  Future<void> updateInvoiceStatus(String id, String status) async {
    try {
      await _client
          .from('invoices')
          .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);

      if (status.toUpperCase() == 'PAID') {
        await recalculateBalanceSummary();
      }
    } catch (e) {
      throw Exception('Failed to update invoice status: $e');
    }
  }

  Future<void> deleteInvoice(String id) async {
    try {
      final invoice = await getInvoiceById(id);

      await _client.from('invoices').delete().eq('id', id);

      if (invoice['client_id'] != null) {
        await _updateClientStats(invoice['client_id']);
      }
      await recalculateBalanceSummary();
    } catch (e) {
      throw Exception('Failed to delete invoice: $e');
    }
  }

  Future<void> recalculateBalanceSummary() async {
    try {
      final paidInvoices =
          await _client.from('invoices').select('amount').eq('status', 'PAID');
      final totalEarnings = paidInvoices.fold<double>(
        0,
        (sum, inv) => sum + _toDouble(inv['amount']),
      );

      final existing = await _client
          .from('balance_summary')
          .select('id,total_expenses')
          .limit(1)
          .maybeSingle();

      if (existing == null) return;
      final totalExpenses = _toDouble(existing['total_expenses']);

      await _client.from('balance_summary').update({
        'total_earnings': totalEarnings,
        'balance': totalEarnings - totalExpenses,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', existing['id']);
    } catch (_) {
      // balance_summary is optional in some environments.
    }
  }

  // ========== CLIENT OPERATIONS ==========

  Future<List<Map<String, dynamic>>> getClients() async {
    try {
      final response = await _client.from('clients').select('*').order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch clients: $e');
    }
  }

  Future<void> _updateClientStats(String clientId) async {
    try {
      final invoices =
          await _client.from('invoices').select('amount').eq('client_id', clientId);

      double totalAmount = 0;
      for (var inv in invoices) {
        totalAmount += _toDouble(inv['amount']);
      }

      await _client
          .from('clients')
          .update({
            'total_invoices': invoices.length,
            'total_amount': totalAmount,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', clientId);
    } catch (e) {
      print('Error updating client stats: $e');
    }
  }

  // ========== DASHBOARD STATS ==========

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final invoices = await getInvoices();

      double totalRevenue = 0;
      double paidRevenue = 0;
      int pendingCount = 0;
      int overdueCount = 0;
      int paidCount = 0;
      int draftCount = 0;

      final now = DateTime.now();
      int invoicesThisMonth = 0;

      for (var invoice in invoices) {
        final amount = _toDouble(invoice['amount']);
        final status = invoice['status']?.toString().toUpperCase() ?? 'DRAFT';
        final dateIssued = DateTime.parse(invoice['date_issued']);

        totalRevenue += amount;

        if (dateIssued.month == now.month && dateIssued.year == now.year) {
          invoicesThisMonth++;
        }

        switch (status) {
          case 'PAID':
            paidRevenue += amount;
            paidCount++;
            break;
          case 'PENDING':
            pendingCount++;
            break;
          case 'OVERDUE':
            overdueCount++;
            break;
          case 'DRAFT':
            draftCount++;
            break;
        }
      }

      return {
        'totalInvoices': invoices.length,
        'totalRevenue': totalRevenue,
        'paidRevenue': paidRevenue,
        'pendingRevenue': totalRevenue - paidRevenue,
        'pendingCount': pendingCount,
        'overdueCount': overdueCount,
        'paidCount': paidCount,
        'draftCount': draftCount,
        'invoicesThisMonth': invoicesThisMonth,
      };
    } catch (e) {
      throw Exception('Failed to get dashboard stats: $e');
    }
  }
}
