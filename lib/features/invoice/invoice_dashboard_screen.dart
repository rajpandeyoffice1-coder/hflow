import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hflow/features/invoice/InvoiceSupabaseService.dart';
import 'package:hflow/features/invoice/create_invoice.dart';
import 'package:hflow/features/invoice/invoice_detail.dart';
import 'package:intl/intl.dart';

class InvoiceDashboardScreen extends StatefulWidget {
  const InvoiceDashboardScreen({super.key});

  @override
  State<InvoiceDashboardScreen> createState() => _InvoiceDashboardScreenState();
}

class _InvoiceDashboardScreenState extends State<InvoiceDashboardScreen> {
  final SupabaseService _supabase = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  String _statusFilter = 'All';
  DateTimeRange? _dateRange;
  String _searchQuery = '';

  int? _sortColumnIndex;
  bool _sortAscending = true;
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await _supabase.getInvoices();
      final stats = await _supabase.getDashboardStats();
      if (!mounted) return;
      setState(() {
        _invoices = List<Map<String, dynamic>>.from(invoices);
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading invoices: $e')));
    }
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    return _invoices.where((invoice) {
      final status = invoice['status']?.toString().toUpperCase() ?? 'DRAFT';
      final issued = DateTime.tryParse(invoice['date_issued']?.toString() ?? '');
      final query = _searchQuery.toLowerCase();

      final statusMatches =
          _statusFilter == 'All' || status == _statusFilter.toUpperCase();
      final searchMatches =
          invoice['client_name']?.toString().toLowerCase().contains(query) == true ||
          invoice['id']?.toString().toLowerCase().contains(query) == true;
      final dateMatches =
          _dateRange == null ||
          (issued != null &&
              !issued.isBefore(_dateRange!.start) &&
              !issued.isAfter(_dateRange!.end));

      return statusMatches && searchMatches && dateMatches;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dateRange,
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  void _sort<T>(Comparable<T> Function(Map<String, dynamic>) getField, int index) {
    setState(() {
      if (_sortColumnIndex == index) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = index;
        _sortAscending = true;
      }

      _invoices.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return _sortAscending
            ? Comparable.compare(aValue, bValue)
            : Comparable.compare(bValue, aValue);
      });
    });
  }

  Future<void> _deleteInvoice(String id) async {
    await _supabase.deleteInvoice(id);
    await _loadData();
  }

  Future<void> _markAsPaid(String id) async {
    await _supabase.markInvoiceAsPaid(id);
    await _loadData();
  }

  Future<void> _duplicateInvoice(String id) async {
    await _supabase.duplicateInvoice(id);
    await _loadData();
  }

  String _statusLabel(String status) {
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

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return const Color(0xFF22C55E);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'OVERDUE':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    const Text('Invoices', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _statsRow(),
                    const SizedBox(height: 16),
                    _filters(),
                    const SizedBox(height: 16),
                    _tableCard(),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
          );
          if (changed == true) _loadData();
        },
        label: const Text('Create Invoice'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _stat('Total', '${_stats['totalInvoices'] ?? 0}'),
        const SizedBox(width: 10),
        _stat('Paid', '${_stats['paidCount'] ?? 0}'),
        const SizedBox(width: 10),
        _stat('Revenue', '₹${(_stats['totalRevenue'] ?? 0).toStringAsFixed(0)}'),
      ],
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _filters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Search by client / invoice',
              hintStyle: TextStyle(color: Colors.white54),
            ),
          ),
        ),
        DropdownButton<String>(
          value: _statusFilter,
          dropdownColor: const Color(0xFF1A1F2E),
          style: const TextStyle(color: Colors.white),
          items: const ['All', 'Draft', 'Pending', 'Paid', 'Overdue']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (value) => setState(() => _statusFilter = value ?? 'All'),
        ),
        OutlinedButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range),
          label: Text(_dateRange == null
              ? 'Date range'
              : '${DateFormat('dd MMM').format(_dateRange!.start)} - ${DateFormat('dd MMM').format(_dateRange!.end)}'),
        ),
        if (_dateRange != null)
          TextButton(
            onPressed: () => setState(() => _dateRange = null),
            child: const Text('Clear dates'),
          ),
      ],
    );
  }

  Widget _tableCard() {
    final rows = _filteredInvoices;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withOpacity(0.05),
          child: PaginatedDataTable(
            rowsPerPage: 20,
            showCheckboxColumn: true,
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            onSelectAll: (value) {
              setState(() {
                if (value == true) {
                  _selectedIds
                    ..clear()
                    ..addAll(rows.map((e) => e['id'].toString()));
                } else {
                  _selectedIds.clear();
                }
              });
            },
            columns: [
              DataColumn(label: const Text('Invoice Number'), onSort: (_, __) => _sort((m) => m['id'].toString(), 0)),
              DataColumn(label: const Text('Client'), onSort: (_, __) => _sort((m) => m['client_name'].toString(), 1)),
              DataColumn(label: const Text('Amount'), numeric: true, onSort: (_, __) => _sort((m) => (m['amount'] as num?)?.toDouble() ?? 0, 2)),
              DataColumn(label: const Text('Date Issued'), onSort: (_, __) => _sort((m) => DateTime.parse(m['date_issued']).millisecondsSinceEpoch, 3)),
              DataColumn(label: const Text('Due Date'), onSort: (_, __) => _sort((m) => DateTime.parse(m['due_date']).millisecondsSinceEpoch, 4)),
              DataColumn(label: const Text('Status'), onSort: (_, __) => _sort((m) => m['status'].toString(), 5)),
              const DataColumn(label: Text('Actions')),
            ],
            source: _InvoiceDataSource(
              rows,
              selectedIds: _selectedIds,
              statusLabel: _statusLabel,
              statusColor: _statusColor,
              onToggleSelection: (id, selected) {
                setState(() {
                  selected ? _selectedIds.add(id) : _selectedIds.remove(id);
                });
              },
              onView: (invoice) => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoice: invoice))),
              onEdit: (invoice) async {
                final changed = await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateInvoiceScreen(invoiceToEdit: invoice)));
                if (changed == true) _loadData();
              },
              onDelete: _deleteInvoice,
              onMarkAsPaid: _markAsPaid,
              onDuplicate: _duplicateInvoice,
            ),
          ),
        ),
      ),
    );
  }
}

class _InvoiceDataSource extends DataTableSource {
  _InvoiceDataSource(
    this.rows, {
    required this.selectedIds,
    required this.statusLabel,
    required this.statusColor,
    required this.onToggleSelection,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkAsPaid,
    required this.onDuplicate,
  });

  final List<Map<String, dynamic>> rows;
  final Set<String> selectedIds;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final void Function(String id, bool selected) onToggleSelection;
  final void Function(Map<String, dynamic>) onView;
  final void Function(Map<String, dynamic>) onEdit;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(String id) onMarkAsPaid;
  final Future<void> Function(String id) onDuplicate;

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final invoice = rows[index];
    final id = invoice['id'].toString();
    final status = invoice['status']?.toString() ?? 'DRAFT';
    return DataRow.byIndex(
      index: index,
      selected: selectedIds.contains(id),
      onSelectChanged: (selected) => onToggleSelection(id, selected ?? false),
      cells: [
        DataCell(Text(id)),
        DataCell(Text(invoice['client_name']?.toString() ?? '-')),
        DataCell(Text('₹${(invoice['amount'] as num?)?.toStringAsFixed(2) ?? '0.00'}')),
        DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.parse(invoice['date_issued'])))),
        DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.parse(invoice['due_date'])))),
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor(status).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(statusLabel(status), style: TextStyle(color: statusColor(status))),
        )),
        DataCell(Row(
          children: [
            IconButton(onPressed: () => onView(invoice), icon: const Icon(Icons.visibility_outlined, size: 18)),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') onEdit(invoice);
                if (value == 'delete') await onDelete(id);
                if (value == 'paid') await onMarkAsPaid(id);
                if (value == 'duplicate') await onDuplicate(id);
                if (value == 'pdf') {}
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
                PopupMenuItem(value: 'pdf', child: Text('Download PDF')),
                PopupMenuItem(value: 'paid', child: Text('Mark as Paid')),
                PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              ],
            ),
          ],
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => rows.length;

  @override
  int get selectedRowCount => selectedIds.length;
}
