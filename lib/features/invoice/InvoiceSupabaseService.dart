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
      final response = await _client
          .from('invoices')
          .select('*')
          .eq('id', id)
          .single();

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

  List<Map<String, dynamic>> _processInvoices(List<Map<String, dynamic>> invoices) {
    return invoices.map((invoice) => _processInvoice(invoice)).toList();
  }

  Map<String, dynamic> _processInvoice(Map<String, dynamic> invoice) {
    // Convert all numeric values to double consistently
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

    // Process items if they exist
    if (processed['items'] != null && processed['items'] is List) {
      processed['items'] = (processed['items'] as List).map((item) {
        final processedItem = Map<String, dynamic>.from(item as Map);
        if (processedItem['rate'] != null) {
          processedItem['rate'] = _toDouble(processedItem['rate']);
        }
        if (processedItem['quantity'] != null) {
          processedItem['quantity'] = _toInt(processedItem['quantity']);
        }
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
        'status': invoiceData['status'] ?? 'DRAFT',
        'items': invoiceData['items'] ?? [],
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
        'status': invoiceData['status'] ?? 'DRAFT',
        'items': invoiceData['items'] ?? [],
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
          .update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update invoice status: $e');
    }
  }

  Future<void> deleteInvoice(String id) async {
    try {
      // First get the invoice to get client_id
      final invoice = await getInvoiceById(id);

      await _client.from('invoices').delete().eq('id', id);

      if (invoice['client_id'] != null) {
        await _updateClientStats(invoice['client_id']);
      }
    } catch (e) {
      throw Exception('Failed to delete invoice: $e');
    }
  }

  // ========== CLIENT OPERATIONS ==========

  Future<List<Map<String, dynamic>>> getClients() async {
    try {
      final response = await _client
          .from('clients')
          .select('*')
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch clients: $e');
    }
  }

  Future<Map<String, dynamic>> getClientById(String id) async {
    try {
      final response = await _client
          .from('clients')
          .select('*')
          .eq('id', id)
          .single();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch client: $e');
    }
  }

  Future<void> createClient(Map<String, dynamic> clientData) async {
    try {
      await _client.from('clients').insert({
        'name': clientData['name'],
        'email': clientData['email'],
        'phone': clientData['phone'],
        'address': clientData['address'],
        'payment_terms': clientData['payment_terms'] ?? 'net30',
        'contact_name': clientData['contact_name'] ?? '',
        'company': clientData['company'],
        'total_invoices': 0,
        'total_amount': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to create client: $e');
    }
  }

  Future<void> updateClient(String id, Map<String, dynamic> clientData) async {
    try {
      await _client
          .from('clients')
          .update({
        'name': clientData['name'],
        'email': clientData['email'],
        'phone': clientData['phone'],
        'address': clientData['address'],
        'payment_terms': clientData['payment_terms'],
        'contact_name': clientData['contact_name'],
        'company': clientData['company'],
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update client: $e');
    }
  }

  Future<void> deleteClient(String id) async {
    try {
      await _client.from('clients').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete client: $e');
    }
  }

  Future<void> _updateClientStats(String clientId) async {
    try {
      final invoices = await _client
          .from('invoices')
          .select('amount')
          .eq('client_id', clientId);

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

        switch(status) {
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

  // ========== SETTINGS OPERATIONS ==========

  Future<Map<String, dynamic>?> getSettings(String userId) async {
    try {
      final response = await _client
          .from('settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch settings: $e');
    }
  }

  Future<void> updateSettings(String userId, Map<String, dynamic> settingsData) async {
    try {
      final existing = await getSettings(userId);

      if (existing == null) {
        await _client.from('settings').insert({
          'user_id': userId,
          ...settingsData,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        await _client
            .from('settings')
            .update({
          ...settingsData,
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Failed to update settings: $e');
    }
  }
}