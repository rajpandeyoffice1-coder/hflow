import 'package:flutter/material.dart';
import 'package:hflow/features/invoice/InvoiceSupabaseService.dart';
import 'package:intl/intl.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic>? invoiceToEdit;
  const CreateInvoiceScreen({super.key, this.invoiceToEdit});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabase = SupabaseService();

  List<Map<String, dynamic>> _clients = [];
  String? _invoiceNumber;
  String? _clientId;
  String _clientName = '';
  DateTime _dateIssued = DateTime.now();
  DateTime _dueDate = DateTime.now();
  String _status = 'Draft';
  double _tax = 0;

  final List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _dueDate = DateTime.now().add(const Duration(days: 7));
    _loadClients();
    _initialize();
  }

  Future<void> _initialize() async {
    if (widget.invoiceToEdit != null) {
      final inv = widget.invoiceToEdit!;
      _invoiceNumber = inv['id']?.toString();
      _clientId = inv['client_id']?.toString();
      _clientName = inv['client_name']?.toString() ?? '';
      _dateIssued = DateTime.parse(inv['date_issued']);
      _dueDate = DateTime.parse(inv['due_date']);
      _status = _displayStatus(inv['status']?.toString() ?? 'Draft');
      _tax = ((inv['tax'] as num?)?.toDouble() ?? 0);
      final raw = (inv['items'] as List?) ?? [];
      _items
        ..clear()
        ..addAll(raw.map((e) => {
              'description': e['description']?.toString() ?? '',
              'quantity': (e['quantity'] as num?)?.toDouble() ?? 0,
              'rate': (e['rate'] as num?)?.toDouble() ?? 0,
            }));
    } else {
      _invoiceNumber = await _supabase.generateInvoiceNumber();
      _addItem();
    }
    if (mounted) setState(() {});
  }

  String _displayStatus(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return 'Paid';
      case 'PENDING':
        return 'Pending';
      case 'OVERDUE':
        return 'Overdue';
      default:
        return 'Draft';
    }
  }

  String _dbStatus(String status) => status.toUpperCase();

  Future<void> _loadClients() async {
    final data = await _supabase.getClients();
    if (!mounted) return;
    setState(() => _clients = data);
  }

  void _addItem() {
    setState(() {
      _items.add({'description': '', 'quantity': 1.0, 'rate': 0.0});
    });
  }

  double get _subtotal => _items.fold(
      0,
      (sum, i) =>
          sum + ((i['quantity'] as double? ?? 0) * (i['rate'] as double? ?? 0)));

  double get _total => _subtotal + _tax;

  Future<void> _pickDate(bool due) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: due ? _dueDate : _dateIssued,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() {
      if (due) {
        _dueDate = selected;
      } else {
        _dateIssued = selected;
        if (_dueDate.isBefore(selected)) _dueDate = selected;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clientId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Client is required')));
      return;
    }
    if (_dueDate.isBefore(_dateIssued)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Due date must be >= issue date')));
      return;
    }

    final payload = {
      'id': _invoiceNumber,
      'client_id': _clientId,
      'client_name': _clientName,
      'amount': _total,
      'subtotal': _subtotal,
      'tax': _tax,
      'date_issued': DateFormat('yyyy-MM-dd').format(_dateIssued),
      'due_date': DateFormat('yyyy-MM-dd').format(_dueDate),
      'status': _dbStatus(_status),
      'items': _items
          .map((i) => {
                'description': i['description'],
                'quantity': i['quantity'],
                'rate': i['rate'],
                'amount': (i['quantity'] as double) * (i['rate'] as double),
              })
          .toList(),
    };

    if (widget.invoiceToEdit == null) {
      await _supabase.createInvoice(payload);
    } else {
      await _supabase.updateInvoice(widget.invoiceToEdit!['id'], payload);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.invoiceToEdit == null ? 'Create Invoice' : 'Edit Invoice')),
      body: _invoiceNumber == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(initialValue: _invoiceNumber, readOnly: true, decoration: const InputDecoration(labelText: 'Invoice Number')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _clientId,
                    items: _clients
                        .map((c) => DropdownMenuItem<String>(
                            value: c['id'].toString(), child: Text(c['name'].toString())))
                        .toList(),
                    onChanged: (v) {
                      final client = _clients.firstWhere((e) => e['id'].toString() == v);
                      setState(() {
                        _clientId = v;
                        _clientName = client['name'].toString();
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Client'),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Text('Issued: ${DateFormat('dd MMM yyyy').format(_dateIssued)}')),
                    TextButton(onPressed: () => _pickDate(false), child: const Text('Change')),
                  ]),
                  Row(children: [
                    Expanded(child: Text('Due: ${DateFormat('dd MMM yyyy').format(_dueDate)}')),
                    TextButton(onPressed: () => _pickDate(true), child: const Text('Change')),
                  ]),
                  DropdownButtonFormField<String>(
                    value: _status,
                    items: const ['Draft', 'Pending', 'Paid', 'Overdue']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'Draft'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 12),
                  const Text('Line Items', style: TextStyle(fontWeight: FontWeight.bold)),
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(children: [
                          TextFormField(
                            initialValue: item['description'],
                            decoration: const InputDecoration(labelText: 'Description'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            onChanged: (v) => item['description'] = v,
                          ),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: '${item['quantity']}',
                                decoration: const InputDecoration(labelText: 'Quantity'),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final numValue = double.tryParse(v ?? '');
                                  if (numValue == null || numValue < 0) return '>= 0';
                                  return null;
                                },
                                onChanged: (v) => setState(() => item['quantity'] = double.tryParse(v) ?? 0),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: '${item['rate']}',
                                decoration: const InputDecoration(labelText: 'Rate (₹)'),
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  final numValue = double.tryParse(v ?? '');
                                  if (numValue == null || numValue < 0) return '>= 0';
                                  return null;
                                },
                                onChanged: (v) => setState(() => item['rate'] = double.tryParse(v) ?? 0),
                              ),
                            ),
                          ]),
                          Align(
                              alignment: Alignment.centerRight,
                              child: Text('Amount: ₹${((item['quantity'] as double) * (item['rate'] as double)).toStringAsFixed(2)}')),
                          if (_items.length > 1)
                            TextButton(
                                onPressed: () => setState(() => _items.removeAt(index)),
                                child: const Text('Remove')),
                        ]),
                      ),
                    );
                  }),
                  TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Add line item')),
                  TextFormField(
                    initialValue: _tax.toString(),
                    decoration: const InputDecoration(labelText: 'Tax (₹ amount)'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setState(() => _tax = double.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 8),
                  Text('Subtotal: ₹${_subtotal.toStringAsFixed(2)}'),
                  Text('Total: ₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _save, child: const Text('Save Invoice')),
                ],
              ),
            ),
    );
  }
}
