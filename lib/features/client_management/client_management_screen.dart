import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hflow/features/invoice/create_invoice.dart';
import 'package:intl/intl.dart';

import '../../models/client_model.dart';
import 'SupabaseServiceClient.dart';

class ClientManagementScreen extends StatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  final SupabaseService _service = SupabaseService();

  bool _loading = true;
  List<ClientModel> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _loading = true);
    final rows = await _service.getClientsWithInvoices();
    setState(() {
      _clients = rows.map(ClientModel.fromJson).toList();
      _loading = false;
    });
  }

  int get _activeClients => _clients.where((c) => c.isActive).length;
  double get _totalRevenue => _clients.fold(0, (sum, c) => sum + c.totalAmount);
  double get _averageRevenue => _clients.isEmpty ? 0 : _totalRevenue / _clients.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Clients', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  _buildKpiBar(),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.92,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _clients.length,
                      itemBuilder: (context, index) => _clientCard(_clients[index]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildKpiBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _kpi('Total Clients', _clients.length.toString()),
          _kpi('Active Clients', _activeClients.toString()),
          _kpi('Total Revenue', _formatMoney(_totalRevenue)),
          _kpi('Avg Revenue/Client', _formatMoney(_averageRevenue)),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) => Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))]),
      );

  Widget _clientCard(ClientModel client) {
    return GestureDetector(
      onTap: () => _openDetails(client),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [CircleAvatar(child: Text(client.initials)), const Spacer(), _statusBadge(client)]),
              const SizedBox(height: 8),
              Text(client.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(client.company ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(client.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(client.phone ?? 'No phone', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text('Invoices: ${client.totalInvoices}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(client.formattedRevenue, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => _openForm(client: client), child: const Text('Edit'))),
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton(onPressed: () => _createInvoice(client), child: const Text('Invoice'))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(ClientModel c) {
    Color color = Colors.blue;
    IconData? icon;
    if (c.isVip) {
      color = Colors.green;
    } else if (c.isGold) {
      color = Colors.amber;
      icon = Icons.star;
    } else if (c.isNew) {
      color = Colors.purple;
    } else if (!c.isActive) {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [if (icon != null) Icon(icon, size: 12, color: color), Text(c.statusLabel, style: TextStyle(color: color, fontSize: 10))]),
    );
  }

  Future<void> _openForm({ClientModel? client}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ClientFormModal(
        client: client,
        onSave: (payload) async {
          if (client == null) {
            await _service.createClient(payload);
          } else {
            await _service.updateClient(client.id!, payload);
          }
          if (mounted) Navigator.pop(context);
          await _loadClients();
        },
      ),
    );
  }

  Future<void> _deleteClient(ClientModel client) async {
    final linked = await _service.hasLinkedInvoices(client.id!);
    if (linked) {
      _snack('Cannot delete: linked invoices exist.');
      return;
    }
    await _service.deleteClient(client.id!);
    _snack('Client deleted.');
    await _loadClients();
  }

  void _openDetails(ClientModel client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ClientDetailModal(client: client, onDelete: () => _deleteClient(client)),
    );
  }

  void _createInvoice(ClientModel client) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateInvoiceScreen(
          preselectedClientId: client.id,
          preselectedClientName: client.name,
        ),
      ),
    );
    _snack('Invoice form opened for ${client.name}.');
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _formatMoney(double value) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(value);
}

class ClientFormModal extends StatefulWidget {
  final ClientModel? client;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const ClientFormModal({super.key, this.client, required this.onSave});

  @override
  State<ClientFormModal> createState() => _ClientFormModalState();
}

class _ClientFormModalState extends State<ClientFormModal> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  String _terms = 'net30';

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    if (c != null) {
      _name.text = c.name;
      _email.text = c.email;
      _phone.text = c.phone ?? '';
      _company.text = c.company ?? '';
      _contact.text = c.contactName ?? '';
      _address.text = c.address ?? '';
      _terms = c.paymentTerms;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          color: const Color(0xFF0B0F1A),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(children: [
              _field(_name, 'Name', required: true),
              _field(_email, 'Email', required: true, isEmail: true),
              _field(_phone, 'Phone'),
              _field(_company, 'Company'),
              _field(_contact, 'Contact Name'),
              _field(_address, 'Address', maxLines: 3),
              DropdownButtonFormField<String>(
                value: _terms,
                decoration: const InputDecoration(labelText: 'Payment Terms'),
                items: const [
                  DropdownMenuItem(value: 'net15', child: Text('Net 15')),
                  DropdownMenuItem(value: 'net30', child: Text('Net 30')),
                  DropdownMenuItem(value: 'net45', child: Text('Net 45')),
                  DropdownMenuItem(value: 'net60', child: Text('Net 60')),
                  DropdownMenuItem(value: 'due_on_receipt', child: Text('Due on Receipt')),
                ],
                onChanged: (v) => setState(() => _terms = v ?? 'net30'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  await widget.onSave({
                    'name': _name.text.trim(),
                    'email': _email.text.trim(),
                    'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
                    'company': _company.text.trim().isEmpty ? null : _company.text.trim(),
                    'contact_name': _contact.text.trim().isEmpty ? null : _contact.text.trim(),
                    'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
                    'payment_terms': _terms,
                  });
                },
                child: Text(widget.client == null ? 'Create Client' : 'Update Client'),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool required = false, bool isEmail = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (value) {
          final v = value?.trim() ?? '';
          if (required && v.isEmpty) return '$label is required';
          if (isEmail && v.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) return 'Enter a valid email';
          return null;
        },
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class ClientDetailModal extends StatelessWidget {
  final ClientModel client;
  final VoidCallback onDelete;

  const ClientDetailModal({super.key, required this.client, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final monthly = <String, double>{};
    for (final invoice in client.invoices) {
      final amount = (invoice['amount'] as num?)?.toDouble() ?? 0;
      final d = DateTime.tryParse((invoice['date_issued'] ?? invoice['created_at'] ?? '').toString());
      if (d == null) continue;
      final key = DateFormat('MMM').format(d);
      monthly[key] = (monthly[key] ?? 0) + amount;
    }

    return Container(
      color: const Color(0xFF0B0F1A),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(client.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Contact: ${client.contactName ?? '-'} • ${client.email} • ${client.phone ?? '-'}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            const Text('Revenue chart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: monthly.entries.map((e) {
                final max = monthly.values.isEmpty ? 1.0 : monthly.values.reduce((a, b) => a > b ? a : b);
                return Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(height: (e.value / max) * 80, color: Colors.blueAccent),
                    Text(e.key, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ]),
                );
              }).toList()),
            ),
            const SizedBox(height: 10),
            const Text('Invoice timeline', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            Expanded(
              child: ListView.builder(
                itemCount: client.invoices.length,
                itemBuilder: (_, i) {
                  final inv = client.invoices[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt_long, color: Colors.white70),
                    title: Text('₹${inv['amount'] ?? 0}', style: const TextStyle(color: Colors.white)),
                    subtitle: Text('${inv['status'] ?? 'unknown'} • ${inv['date_issued'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                  );
                },
              ),
            ),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Delete Client'),
                        content: const Text('Are you sure you want to delete this client?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      Navigator.pop(context);
                      onDelete();
                    }
                  },
                  child: const Text('Delete'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
