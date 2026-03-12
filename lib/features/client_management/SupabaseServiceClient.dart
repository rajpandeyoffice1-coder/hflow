import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getClientsWithInvoices() async {
    final response = await _client
        .from('clients')
        .select('*, invoices(*)')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final clients = await _client.from('clients').select();
    final invoices = await _client.from('invoices').select();

    int totalClients = clients.length;
    int newThisMonth = 0;
    double totalRevenue = 0;

    DateTime now = DateTime.now();

    for (var c in clients) {
      if (c['created_at'] != null) {
        DateTime d = DateTime.parse(c['created_at']);
        if (d.month == now.month && d.year == now.year) {
          newThisMonth++;
        }
      }
    }

    int paidInvoices = 0;

    for (var i in invoices) {
      double amount = (i['amount'] as num?)?.toDouble() ?? 0;

      // FIX 1: total revenue should include all invoices
      totalRevenue += amount;

      // FIX 2: case insensitive status
      String status = (i['status'] ?? '').toString().toLowerCase();

      if (status == 'paid') {
        paidInvoices++;
      }
    }

    double avgClientValue =
    totalClients > 0 ? totalRevenue / totalClients : 0;

    double paymentRate =
    invoices.isEmpty ? 0 : (paidInvoices / invoices.length) * 100;

    return {
      'totalClients': totalClients,
      'newThisMonth': newThisMonth,
      'totalRevenue': totalRevenue,
      'avgClientValue': avgClientValue,
      'paymentRate': paymentRate,
    };
  }

  Future<void> createClient(Map<String, dynamic> data) async {
    await _client.from('clients').insert(data);
  }

  Future<void> updateClient(String id, Map<String, dynamic> data) async {
    await _client.from('clients').update(data).eq('id', id);
  }

  Future<void> deleteClient(String id) async {
    await _client.from('clients').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getInvoicesByClient(String clientId) async {
    final response = await _client
        .from('invoices')
        .select()
        .eq('client_id', clientId)
        .order('date_issued', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createInvoice(Map<String, dynamic> data) async {
    await _client.from('invoices').insert(data);
  }

  Future<void> updateInvoice(String id, Map<String, dynamic> data) async {
    await _client.from('invoices').update(data).eq('id', id);
  }

  Future<void> deleteInvoice(String id) async {
    await _client.from('invoices').delete().eq('id', id);
  }
}