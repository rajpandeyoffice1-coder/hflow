import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getClientsWithInvoices() async {
    final clientsResponse = await supabase.from('clients').select().order('created_at', ascending: false);
    final clients = List<Map<String, dynamic>>.from(clientsResponse);

    for (final client in clients) {
      final invoices = await supabase
          .from('invoices')
          .select('id, amount, status, date_issued, created_at')
          .eq('client_id', client['id'])
          .order('date_issued', ascending: false);
      client['invoices'] = invoices;
    }
    return clients;
  }

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> clientData) async {
    final now = DateTime.now().toIso8601String();
    return supabase
        .from('clients')
        .insert({
          'name': clientData['name'],
          'email': clientData['email'],
          'phone': clientData['phone'],
          'address': clientData['address'],
          'payment_terms': clientData['payment_terms'] ?? 'net30',
          'contact_name': clientData['contact_name'],
          'company': clientData['company'],
          'total_invoices': 0,
          'total_amount': 0,
          'created_at': now,
          'updated_at': now,
        })
        .select()
        .single();
  }

  Future<Map<String, dynamic>> updateClient(String id, Map<String, dynamic> clientData) async {
    return supabase
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
        .eq('id', id)
        .select()
        .single();
  }

  Future<bool> hasLinkedInvoices(String clientId) async {
    final rows = await supabase.from('invoices').select('id').eq('client_id', clientId).limit(1);
    return rows.isNotEmpty;
  }

  Future<void> deleteClient(String id) async {
    await supabase.from('clients').delete().eq('id', id);
  }
}
