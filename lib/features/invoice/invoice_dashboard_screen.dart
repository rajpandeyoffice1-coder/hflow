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

          // extract unique statuses from DB
          final statuses = invoices
              .map((e) => e['status'].toString())
              .toSet()
              .toList();

          _statusList = ["All", ...statuses];

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

    // Search
    if (_searchQuery.isNotEmpty) {
      data = data.where((inv) {

        final id = inv['id']?.toString().toLowerCase() ?? "";
        final client = inv['client_name']?.toString().toLowerCase() ?? "";

        return id.contains(_searchQuery.toLowerCase()) ||
            client.contains(_searchQuery.toLowerCase());

      }).toList();
    }

    // Status filter
    if (_selectedStatus != "All") {
      data = data.where((inv) =>
      inv['status'].toString().toLowerCase() ==
          _selectedStatus.toLowerCase()
      ).toList();
    }

    // Date filter
    if (_selectedDateRange != null) {

      data = data.where((inv) {

        DateTime issueDate = DateTime.parse(inv['date_issued']);

        return issueDate.isAfter(_selectedDateRange!.start) &&
            issueDate.isBefore(_selectedDateRange!.end);

      }).toList();
    }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
              ),
            ),
          ),

          // Decorative blobs
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

          // Main content
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
                          _buildInvoiceFilters(),
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

  Widget _buildInvoiceFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// SEARCH (FULL WIDTH)
        _buildSearchBar(),

        const SizedBox(height: 14),

        /// DATE RANGE CHIPS
        _buildDateFilters(),

        const SizedBox(height: 14),

        /// STATUS SELECT
        _buildStatusDropdown(),
      ],
    );
  }

  Widget _buildDateFilters() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [

        _dateChip("1M", 30),
        _dateChip("3M", 90),
        _dateChip("6M", 180),
        _dateChip("12M", 365),

        GestureDetector(
          onTap: _pickDateRange,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Text(
              "Custom",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _dateChip(String label, int days) {

    final now = DateTime.now();

    bool active = _selectedDateRange != null &&
        _selectedDateRange!.start == now.subtract(Duration(days: days));

    return GestureDetector(
      onTap: () {

        setState(() {
          _selectedDateRange = DateTimeRange(
            start: now.subtract(Duration(days: days)),
            end: now,
          );
        });

      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF5B8CFF)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }


  Widget _buildStatusDropdown() {
    return Row(
      children: [

        const Text(
          "Status:",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(width: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButton<String>(
            value: _selectedStatus,
            dropdownColor: const Color(0xFF1A1F2E),
            underline: const SizedBox(),

            items: _statusList.map((e) {
              return DropdownMenuItem(
                value: e,
                child: Text(
                  e,
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }).toList(),

            onChanged: (val) {
              setState(() {
                _selectedStatus = val!;
              });
            },
          )
        )
      ],
    );
  }

  Future<void> _pickDateRange() async {

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  Widget _glassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05)
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: child,
        ),
      ),
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
      builder: (context) {

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text("Export PDF"),
              onTap: () {
                Navigator.pop(context);
                exportPDF(data);
              },
            ),

            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text("Export Excel"),
              onTap: () {
                Navigator.pop(context);
                exportExcel(data);
              },
            ),

          ],
        );
      },
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
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

  Widget _buildStatusFilter() {
    return Wrap(
      spacing: 8,
      children: [
        _filterChip("All"),
        _filterChip("Paid"),
        _filterChip("Draft"),
        _filterChip("Overdue"),
      ],
    );
  }

  Widget _filterChip(String status) {
    bool active = _selectedStatus == status;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF5B8CFF)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: const TextStyle(color: Colors.white, fontSize: 12),
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
          padding: const EdgeInsets.all(10),

          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),

            // TRANSPARENT GLASS BACKGROUND
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),

            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),

          child: SizedBox(
            height: 520,

            child: DataTable2(

              // remove material background
              headingRowColor:
              WidgetStateProperty.all(Colors.transparent),

              dataRowColor:
              WidgetStateProperty.all(Colors.transparent),

              dividerThickness: 0.3,

              columnSpacing: 14,
              horizontalMargin: 10,
              minWidth: 1500,

              columns: const [

                DataColumn2(
                  label: Text(
                    "Invoice",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                DataColumn2(
                  label: Text(
                    "Client",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                DataColumn2(
                  label: Text(
                    "Amount",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                DataColumn2(
                  label: Text(
                    "Status",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                DataColumn2(
                  label: Text(
                    "Issue Date",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                DataColumn2(
                  label: Text(
                    "Due Date",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

                DataColumn2(
                  label: Text(
                    "Actions",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],

              rows: filteredInvoices.map((invoice) {

                final issue = DateTime.parse(invoice['date_issued']);
                final due = DateTime.parse(invoice['due_date']);

                return DataRow(

                  color: WidgetStateProperty.resolveWith<Color?>(
                        (states) {

                      if (states.contains(WidgetState.hovered)) {
                        return Colors.white.withOpacity(0.05);
                      }

                      return Colors.transparent;
                    },
                  ),

                  cells: [

                    DataCell(
                      Text(
                        invoice['id'].toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),

                    DataCell(
                      Text(
                        invoice['client_name'] ?? "",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),

                    DataCell(
                      Text(
                        _formatCurrency(
                            (invoice['amount'] as num).toDouble()),
                        style: const TextStyle(
                          color: Color(0xFF5B8CFF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    DataCell(
                      Text(
                        invoice['status'],
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),

                    DataCell(
                      Text(
                        DateFormat('dd MMM yyyy').format(issue),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),

                    DataCell(
                      Text(
                        DateFormat('dd MMM yyyy').format(due),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),

                    DataCell(
                      Row(
                        children: [

                          IconButton(
                            icon: const Icon(Icons.visibility,
                                color: Colors.white70),
                            onPressed: () =>
                                _viewInvoiceDetails(invoice),
                          ),

                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.white70),
                            onPressed: () =>
                                _editInvoice(invoice),
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () =>
                                _showDeleteDialog(
                                    invoice['id'],
                                    invoice['id']),
                          ),

                          if ((invoice['status'] ?? '').toString().toUpperCase() != "PAID")
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle,
                                color: Color(0xFF22C55E),
                              ),
                              onPressed: () => _markAsPaid(invoice['id']),
                            ),
                        ],
                      ),
                    ),
                  ],
                );

              }).toList(),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final issueDate = DateTime.parse(invoice['date_issued']);
    final dueDate = DateTime.parse(invoice['due_date']);
    final status = invoice['status']?.toString().toUpperCase() ?? 'DRAFT';
    final now = DateTime.now();
    final isOverdue = status != 'PAID' && dueDate.isBefore(now);

    Color getStatusColor() {
      if (status == 'PAID') return const Color(0xFF22C55E);
      if (status == 'OVERDUE' || isOverdue) return const Color(0xFFEF4444);
      if (status == 'DRAFT') return const Color(0xFF6B7280);
      return const Color(0xFFF59E0B); // PENDING
    }

    String getStatusText() {
      if (isOverdue && status != 'PAID') return 'OVERDUE';
      return status;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
              onTap: () => _viewInvoiceDetails(invoice),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header row with invoice number and status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invoice['id']?.toString() ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                invoice['client_name']?.toString() ?? '',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: getStatusColor().withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: getStatusColor().withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            getStatusText(),
                            style: TextStyle(
                              color: getStatusColor(),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      children: [

                        /// AMOUNT
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Amount",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency((invoice['amount'] as num?)?.toDouble() ?? 0),
                              style: const TextStyle(
                                color: Color(0xFF5B8CFF),
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),

                        /// ISSUE DATE
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Issue Date",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(issueDate),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),

                        /// DUE DATE
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Due Date",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy').format(dueDate),
                              style: TextStyle(
                                color: isOverdue && status != 'PAID'
                                    ? const Color(0xFFEF4444)
                                    : Colors.white,
                                fontSize: 12,
                                fontWeight: isOverdue && status != 'PAID'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if ((invoice['status'] ?? '').toString().toUpperCase() != "PAID")
                          TextButton.icon(
                            onPressed: () => _markAsPaid(invoice['id']),
                            icon: const Icon(Icons.check_circle, size: 16, color: Color(0xFF22C55E)),
                            label: const Text(
                              "Mark Paid",
                              style: TextStyle(color: Color(0xFF22C55E), fontSize: 12),
                            ),
                          ),

                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _editInvoice(invoice),
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          label: Text(
                            "Edit",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _showDeleteDialog(
                            invoice['id'].toString(),
                            invoice['id'].toString(),
                          ),
                          icon: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          label: Text(
                            "Delete",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invoice marked as Paid"),
          backgroundColor: Color(0xFF22C55E),
        ),
      );

    } catch (e) {
      _showErrorSnackBar("Error updating invoice");
    }
  }

  static Widget _liquidBlob({
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

  Future<void> exportExcel(List<Map<String,dynamic>> invoices) async {

    await Permission.storage.request();
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

    final file = File("${downloads.path}/Invoices.xlsx");

    file.writeAsBytesSync(excel.encode()!);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Excel saved to Downloads"),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }

  Future<void> exportPDF(List<Map<String,dynamic>> invoices) async {

    await Permission.storage.request();

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Table.fromTextArray(
            headers: [
              "Invoice",
              "Client",
              "Amount",
              "Status",
              "Issue Date"
            ],
            data: invoices.map((inv) {
              return [
                inv['id'],
                inv['client_name'],
                inv['amount'].toString(),
                inv['status'],
                inv['date_issued']
              ];
            }).toList(),
          );
        },
      ),
    );

    final downloads = Directory("/storage/emulated/0/Download");

    final file = File("${downloads.path}/Invoices.pdf");

    await file.writeAsBytes(await pdf.save());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Excel saved to Downloads"),
        backgroundColor: Color(0xFF22C55E),
      ),
    );
  }
}