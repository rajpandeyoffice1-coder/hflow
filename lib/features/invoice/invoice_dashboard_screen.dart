import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hflow/features/invoice/create_invoice.dart';
import 'package:hflow/features/invoice/InvoiceSupabaseService.dart';
import 'package:hflow/features/invoice/invoice_detail.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:data_table_2/data_table_2.dart';

class InvoiceDashboardScreen extends StatefulWidget {
  const InvoiceDashboardScreen({super.key});

  @override
  State<InvoiceDashboardScreen> createState() => _InvoiceDashboardScreenState();
}

class _InvoiceDashboardScreenState extends State<InvoiceDashboardScreen> {
  static const double _headerHeight = 56;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isRefreshing = false;

  String _selectedStatus = "All";
  List<String> _statusList = ["All"];

  DateTimeRange? _selectedDateRange;
  bool _sortAscending = true;
  int _sortColumnIndex = 0;

  String _selectedClientFilter = "All";
  List<String> _clientList = ["All"];

  double _minAmount = 0;
  double _maxAmount = 1000000;
  RangeValues _amountRange = const RangeValues(0, 1000000);

  final SupabaseService _supabase = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isRefreshing) return;

    setState(() {
      _isLoading = true;
      _isRefreshing = true;
    });

    try {
      final invoices = await _supabase.getInvoices();
      final stats = await _supabase.getDashboardStats();

      if (mounted) {
        setState(() {
          _invoices = List<Map<String, dynamic>>.from(invoices);
          _stats = stats;

          final statuses = invoices
              .map((e) => e['status'].toString())
              .toSet()
              .toList();
          _statusList = ["All", ...statuses];

          final clients = invoices
              .map((e) => e['client_name'].toString())
              .toSet()
              .toList();
          _clientList = ["All", ...clients];

          if (invoices.isNotEmpty) {
            final amounts = invoices.map((e) => (e['amount'] as num).toDouble()).toList();
            _minAmount = amounts.reduce((a, b) => a < b ? a : b);
            _maxAmount = amounts.reduce((a, b) => a > b ? a : b);
            _amountRange = RangeValues(_minAmount, _maxAmount);
          }

          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        _showErrorSnackBar('Error loading data: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteInvoice(String id) async {
    try {
      await _supabase.deleteInvoice(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice deleted successfully'),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error deleting invoice: $e');
      }
    }
  }

  void _showDeleteDialog(String id, String invoiceNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Delete Invoice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete invoice #$invoiceNumber?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteInvoice(id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _viewInvoiceDetails(Map<String, dynamic> invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoice: invoice)),
    ).then((_) => _loadData());
  }

  void _editInvoice(Map<String, dynamic> invoice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateInvoiceScreen(invoiceToEdit: invoice),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  List<Map<String, dynamic>> get filteredInvoices {
    List<Map<String, dynamic>> data = _invoices;

    if (_searchQuery.isNotEmpty) {
      data = data.where((inv) {
        final id = inv['id']?.toString().toLowerCase() ?? "";
        final client = inv['client_name']?.toString().toLowerCase() ?? "";
        return id.contains(_searchQuery.toLowerCase()) ||
            client.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_selectedStatus != "All") {
      data = data.where((inv) =>
      inv['status'].toString().toLowerCase() ==
          _selectedStatus.toLowerCase()
      ).toList();
    }

    if (_selectedDateRange != null) {
      data = data.where((inv) {
        DateTime issueDate = DateTime.parse(inv['date_issued']);
        return issueDate.isAfter(_selectedDateRange!.start) &&
            issueDate.isBefore(_selectedDateRange!.end);
      }).toList();
    }

    if (_selectedClientFilter != "All") {
      data = data.where((inv) =>
      inv['client_name'] == _selectedClientFilter
      ).toList();
    }

    data = data.where((inv) {
      final amount = (inv['amount'] as num).toDouble();
      return amount >= _amountRange.start && amount <= _amountRange.end;
    }).toList();

    return data;
  }

  String _daysAgo(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(2)}K';
    }
    return '₹${amount.toStringAsFixed(2)}';
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [

                  /// HEADER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Invoices',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  /// BODY
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          /// STATUS
                          const Text(
                            'Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _statusList.map((status) {
                              final isSelected = _selectedStatus == status;

                              return GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    _selectedStatus = status;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF5B8CFF)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.transparent
                                          : Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color:
                                      isSelected ? Colors.white : Colors.white70,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 24),

                          /// CLIENT
                          const Text(
                            'Client',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border:
                              Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedClientFilter,
                              dropdownColor: const Color(0xFF1A1F2E),
                              underline: const SizedBox(),
                              isExpanded: true,
                              items: _clientList.map((client) {
                                return DropdownMenuItem(
                                  value: client,
                                  child: Text(
                                    client,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setModalState(() {
                                  _selectedClientFilter = val!;
                                });
                              },
                            ),
                          ),

                          const SizedBox(height: 24),

                          /// DATE RANGE
                          const Text(
                            'Date Range',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFilterDateChip(
                                  'Today', 0, setModalState),
                              _buildFilterDateChip(
                                  '7 Days', 7, setModalState),
                              _buildFilterDateChip(
                                  '30 Days', 30, setModalState),
                              _buildFilterDateChip(
                                  '90 Days', 90, setModalState),
                              _buildFilterDateChip(
                                  'This Year', 365, setModalState),

                              /// CUSTOM DATE
                              GestureDetector(
                                onTap: () async {
                                  DateTimeRange? range = await _pickDateRange();

                                  if (range != null) {
                                    setModalState(() {
                                      _selectedDateRange = range;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedDateRange != null
                                        ? const Color(0xFF5B8CFF)
                                        : Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _selectedDateRange != null
                                          ? Colors.transparent
                                          : Colors.white.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    _selectedDateRange != null
                                        ? '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}'
                                        : 'Custom',
                                    style: TextStyle(
                                      color: _selectedDateRange != null
                                          ? Colors.white
                                          : Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          /// AMOUNT RANGE
                          const Text(
                            'Amount Range',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 12),

                          RangeSlider(
                            values: _amountRange,
                            min: _minAmount,
                            max: _maxAmount,
                            divisions: 100,
                            activeColor: const Color(0xFF5B8CFF),
                            inactiveColor: Colors.white.withOpacity(0.2),
                            labels: RangeLabels(
                              _formatCurrency(_amountRange.start),
                              _formatCurrency(_amountRange.end),
                            ),
                            onChanged: (values) {
                              setModalState(() {
                                _amountRange = values;
                              });
                            },
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatCurrency(_amountRange.start),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                              Text(
                                _formatCurrency(_amountRange.end),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// FOOTER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [

                        /// RESET
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedStatus = "All";
                                _selectedClientFilter = "All";
                                _selectedDateRange = null;
                                _amountRange =
                                    RangeValues(_minAmount, _maxAmount);
                              });
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        /// APPLY
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B8CFF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Apply Filters',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTimeRange?> _pickDateRange() async {
    return await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5B8CFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1A1F2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Widget _buildFilterDateChip(
      String label, int days, StateSetter setModalState) {

    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    final isSelected = _selectedDateRange != null &&
        _selectedDateRange!.start == startDate &&
        _selectedDateRange!.end == now;

    return GestureDetector(
      onTap: () {
        setModalState(() {
          _selectedDateRange = DateTimeRange(
            start: startDate,
            end: now,
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF5B8CFF)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
            isSelected ? Colors.transparent : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -100,
            child: _liquidBlob(
              width: 320,
              height: 420,
              color: const Color(0xFF9333EA),
              opacity: 0.28,
            ),
          ),
          Positioned(
            bottom: -160,
            right: -120,
            child: _liquidBlob(
              width: 380,
              height: 460,
              color: const Color(0xFF3B82F6),
              opacity: 0.26,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF5B8CFF),
                    ),
                  )
                      : RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFF5B8CFF),
                    backgroundColor: const Color(0xFF1A1F2E),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildHeaderTitle(),
                          const SizedBox(height: 20),
                          _buildStatsGrid(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                          const SizedBox(height: 24),
                          _buildInvoicesHeader(),
                          const SizedBox(height: 16),
                          _buildSearchAndFilter(),
                          const SizedBox(height: 20),
                          _buildInvoicesTable(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Row(
      children: [
        Expanded(
          child: _buildSearchBar(),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _showFilterDialog,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5B8CFF).withOpacity(0.2),
                  const Color(0xFF5B8CFF).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF5B8CFF).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.filter_list,
              color: Color(0xFF5B8CFF),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              "Invoice Management",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isRefreshing ? null : _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Invoices",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Manage and track all your invoices",
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: _buildStatCard(
              label: "Total",
              value: "${_stats['totalInvoices'] ?? 0}",
              icon: Icons.receipt,
              color: const Color(0xFF5B8CFF),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: _buildStatCard(
              label: "Paid",
              value: "${_stats['paidCount'] ?? 0}",
              icon: Icons.check_circle,
              color: const Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: _buildStatCard(
              label: "Pending",
              value: "${_stats['pendingCount'] ?? 0}",
              icon: Icons.hourglass_top,
              color: const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: _buildStatCard(
              label: "Draft",
              value: "${_stats['draftCount'] ?? 0}",
              icon: Icons.description,
              color: const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: _buildStatCard(
              label: "Overdue",
              value: "${_stats['overdueCount'] ?? 0}",
              icon: Icons.warning,
              color: const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    String? subValue,
    Color? subValueColor,
    required IconData icon,
    required Color color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              if (subValue != null) ...[
                const SizedBox(height: 4),
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 9,
                    color: subValueColor ?? Colors.white54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.03),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 0.8,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: _exportInvoices,
                    child: const Center(
                      child: Text(
                        "Export",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateInvoiceScreen(),
                  ),
                );
                if (result == true) {
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B8CFF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "Create Invoice",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _exportInvoices() {
    final data = filteredInvoices;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
                ),
                title: const Text(
                  "Export PDF",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  exportPDF(data);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.table_chart, color: Color(0xFF22C55E)),
                ),
                title: const Text(
                  "Export Excel",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(context);
                  exportExcel(data);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInvoicesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "All Invoices",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "${filteredInvoices.length} total",
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 0.8,
            ),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Search by invoice number or client...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: Colors.white.withOpacity(0.5),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: Icon(
                  Icons.clear,
                  size: 16,
                  color: Colors.white.withOpacity(0.5),
                ),
                padding: EdgeInsets.zero,
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoicesTable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B8CFF).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SizedBox(
            height: 520,
            child: DataTable2(
              columnSpacing: 16,
              horizontalMargin: 12,
              minWidth: 1400,
              headingRowHeight: 50,
              dataRowHeight: 56,
              dividerThickness: 0.3,
              headingRowColor:
              WidgetStateProperty.all(const Color(0xFF5B8CFF).withOpacity(0.15)),
              columns: const [
                DataColumn2(
                  label: Row(
                    children: [
                      Icon(Icons.receipt, color: Color(0xFF5B8CFF), size: 18),
                      SizedBox(width: 6),
                      Text("Invoice",
                          style: TextStyle(
                              color: Color(0xFF5B8CFF),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                DataColumn2(
                  label: Row(
                    children: [
                      Icon(Icons.person, color: Color(0xFF5B8CFF), size: 18),
                      SizedBox(width: 6),
                      Text("Client",
                          style: TextStyle(
                              color: Color(0xFF5B8CFF),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                DataColumn2(
                  label: Row(
                    children: [
                      Icon(Icons.currency_rupee,
                          color: Color(0xFF5B8CFF), size: 18),
                      SizedBox(width: 6),
                      Text("Amount",
                          style: TextStyle(
                              color: Color(0xFF5B8CFF),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                DataColumn2(
                  label: Row(
                    children: [
                      Icon(Icons.flag, color: Color(0xFF5B8CFF), size: 18),
                      SizedBox(width: 6),
                      Text("Status",
                          style: TextStyle(
                              color: Color(0xFF5B8CFF),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                DataColumn2(
                  label: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          color: Color(0xFF5B8CFF), size: 18),
                      SizedBox(width: 6),
                      Text("Issue Date",
                          style: TextStyle(
                              color: Color(0xFF5B8CFF),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                DataColumn2(
                  label: Row(
                    children: [
                      Icon(Icons.event, color: Color(0xFF5B8CFF), size: 18),
                      SizedBox(width: 6),
                      Text("Due Date",
                          style: TextStyle(
                              color: Color(0xFF5B8CFF),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                DataColumn2(
                  label: Row(
                    children: [
                      Icon(Icons.settings,
                          color: Color(0xFF5B8CFF), size: 18),
                      SizedBox(width: 6),
                      Text("Actions",
                          style: TextStyle(
                              color: Color(0xFF5B8CFF),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              rows: filteredInvoices.map((invoice) {
                final issue = DateTime.parse(invoice['date_issued']);
                final due = DateTime.parse(invoice['due_date']);
                final status = invoice['status'].toString().toLowerCase();

                Color statusColor;

                switch (status) {
                  case 'paid':
                    statusColor = const Color(0xFF22C55E);
                    break;
                  case 'pending':
                    statusColor = const Color(0xFFF59E0B);
                    break;
                  case 'overdue':
                    statusColor = const Color(0xFFEF4444);
                    break;
                  case 'draft':
                    statusColor = const Color(0xFF6B7280);
                    break;
                  default:
                    statusColor = Colors.white70;
                }

                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return const Color(0xFF5B8CFF).withOpacity(0.1);
                    }
                    return Colors.transparent;
                  }),
                  cells: [
                    DataCell(Text(
                      invoice['id'].toString(),
                      style: const TextStyle(color: Colors.white),
                    )),
                    DataCell(Text(
                      invoice['client_name'] ?? "",
                      style: const TextStyle(color: Colors.white),
                    )),
                    DataCell(Text(
                      _formatCurrency((invoice['amount'] as num).toDouble()),
                      style: const TextStyle(
                          color: Color(0xFF5B8CFF),
                          fontWeight: FontWeight.bold),
                    )),
                    DataCell(Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        invoice['status'],
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    )),
                    DataCell(Text(
                      DateFormat('dd MMM yyyy').format(issue),
                      style: const TextStyle(color: Colors.white70),
                    )),
                    DataCell(Text(
                      DateFormat('dd MMM yyyy').format(due),
                      style: TextStyle(
                          color: due.isBefore(DateTime.now()) &&
                              status != "paid"
                              ? const Color(0xFFEF4444)
                              : Colors.white70),
                    )),
                    DataCell(Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility,
                              size: 18, color: Colors.white70),
                          onPressed: () => _viewInvoiceDetails(invoice),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit,
                              size: 18, color: Color(0xFF5B8CFF)),
                          onPressed: () => _editInvoice(invoice),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 18, color: Color(0xFFEF4444)),
                          onPressed: () =>
                              _showDeleteDialog(invoice['id'], invoice['id']),
                        ),
                        // if (status != "paid")
                        //   IconButton(
                        //     icon: const Icon(Icons.check_circle,
                        //         size: 18, color: Color(0xFF22C55E)),
                        //     onPressed: () => _markAsPaid(invoice['id']),
                        //   ),
                      ],
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAsPaid(String id) async {
    try {
      await _supabase.updateInvoiceStatus(id, "PAID");
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invoice marked as Paid"),
            backgroundColor: Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar("Error updating invoice");
    }
  }

  Widget _liquidBlob({
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }

  Future<void> exportExcel(List<Map<String, dynamic>> invoices) async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      _showErrorSnackBar("Storage permission required");
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Invoices'];

      sheet.appendRow([
        "Invoice ID",
        "Client",
        "Amount",
        "Status",
        "Issue Date",
        "Due Date"
      ]);

      for (var inv in invoices) {
        sheet.appendRow([
          inv['id'],
          inv['client_name'],
          inv['amount'],
          inv['status'],
          inv['date_issued'],
          inv['due_date']
        ]);
      }

      final downloads = Directory("/storage/emulated/0/Download");
      if (!await downloads.exists()) {
        _showErrorSnackBar("Downloads folder not found");
        return;
      }

      final file = File("${downloads.path}/Invoices_${DateTime.now().millisecondsSinceEpoch}.xlsx");
      await file.writeAsBytes(excel.encode()!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Excel saved to ${file.path}"),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar("Error saving Excel: $e");
    }
  }

  Future<void> exportPDF(List<Map<String, dynamic>> invoices) async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      _showErrorSnackBar("Storage permission required");
      return;
    }

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              children: [
                pw.Text(
                  "Invoices Report",
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(
                  headers: ["Invoice", "Client", "Amount", "Status", "Issue Date"],
                  data: invoices.map((inv) {
                    return [
                      inv['id'],
                      inv['client_name'],
                      "₹${inv['amount']}",
                      inv['status'],
                      inv['date_issued']
                    ];
                  }).toList(),
                ),
              ],
            );
          },
        ),
      );

      final downloads = Directory("/storage/emulated/0/Download");
      if (!await downloads.exists()) {
        _showErrorSnackBar("Downloads folder not found");
        return;
      }

      final file = File("${downloads.path}/Invoices_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("PDF saved to ${file.path}"),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar("Error saving PDF: $e");
    }
  }
}