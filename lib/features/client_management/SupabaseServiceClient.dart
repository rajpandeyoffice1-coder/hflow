// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getClientsWithInvoices() async {
    try {
      final clientsResponse = await supabase
          .from('clients')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> clients = 
          List<Map<String, dynamic>>.from(clientsResponse);

      for (var clientData in clients) {
        try {
          final invoicesResponse = await supabase
              .from('invoices')
              .select()
              .eq('client_id', clientData['id'])
              .order('date_issued', ascending: false);

          clientData['invoices'] = invoicesResponse;
        } catch (e) {
          clientData['invoices'] = [];
        }
      }

      return clients;
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> clientData) async {
    try {
      final now = DateTime.now().toIso8601String();
      
      final data = {
        'name': clientData['name'],
        'email': clientData['email'],
        'phone': clientData['phone'],
        'address': clientData['address'],
        'payment_terms': clientData['payment_terms'] ?? 'net_30_days',
        'contact_name': clientData['contact_name'],
        'company': clientData['company'],
        'status': clientData['status'] ?? 'Active',
        'total_invoices': 0,
        'total_amount': 0,
        'created_at': now,
        'updated_at': now,
      };

      final response = await supabase
          .from('clients')
          .insert(data)
          .select()
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateClient(String id, Map<String, dynamic> clientData) async {
    try {
      final data = {
        'name': clientData['name'],
        'email': clientData['email'],
        'phone': clientData['phone'],
        'address': clientData['address'],
        'payment_terms': clientData['payment_terms'],
        'contact_name': clientData['contact_name'],
        'company': clientData['company'],
        'status': clientData['status'],
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await supabase
          .from('clients')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteClient(String id) async {
    try {
      await supabase.from('invoices').delete().eq('client_id', id);
      await supabase.from('clients').delete().eq('id', id);
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final clients = await getClientsWithInvoices();

      if (clients.isEmpty) {
        return {
          'totalClients': 0,
          'newThisMonth': 0,
          'totalRevenue': 0.0,
          'avgClientValue': 0.0,
          'paymentRate': 0.0,
        };
      }

      int totalClients = clients.length;
      int newThisMonth = 0;
      double totalRevenue = 0;
      int totalPaidInvoices = 0;
      int totalInvoices = 0;

      DateTime now = DateTime.now();
      DateTime firstDayOfMonth = DateTime(now.year, now.month, 1);

      for (var clientData in clients) {
        if (clientData['invoices'] != null && clientData['invoices'] is List) {
          for (var invoice in clientData['invoices']) {
            double amount = (invoice['amount'] as num?)?.toDouble() ?? 0;
            totalRevenue += amount;

            String status = invoice['status']?.toString().toLowerCase() ?? '';
            if (status == 'paid') {
              totalPaidInvoices++;
            }
            totalInvoices++;
          }
        }

        if (clientData['created_at'] != null) {
          try {
            DateTime createdAt = DateTime.parse(clientData['created_at']);
            if (createdAt.isAfter(firstDayOfMonth) ||
                createdAt.isAtSameMomentAs(firstDayOfMonth)) {
              newThisMonth++;
            }
          } catch (e) {}
        }
      }

      double avgClientValue = totalClients > 0 ? totalRevenue / totalClients : 0;
      double paymentRate = totalInvoices > 0 
          ? (totalPaidInvoices / totalInvoices * 100) 
          : 0;

      return {
        'totalClients': totalClients,
        'newThisMonth': newThisMonth,
        'totalRevenue': totalRevenue,
        'avgClientValue': avgClientValue,
        'paymentRate': paymentRate,
      };
    } catch (e) {
      return {
        'totalClients': 0,
        'newThisMonth': 0,
        'totalRevenue': 0.0,
        'avgClientValue': 0.0,
        'paymentRate': 0.0,
      };
    }
  }
}