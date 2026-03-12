import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessAnalyticsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const BusinessAnalyticsScreen({super.key, this.onBack});

  @override
  State<BusinessAnalyticsScreen> createState() => _BusinessAnalyticsScreenState();
}

class _BusinessAnalyticsScreenState extends State<BusinessAnalyticsScreen> {
  static const double _headerHeight = 64;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _selectedPeriod = '30D';
  String _selectedClient = 'All Clients';
  String _selectedStatus = 'All Status';

  final List<String> _periods = ['Today', '7D', '30D', 'YTD', 'All'];
  List<String> _clients = ['All Clients'];
  final List<String> _statuses = [
    'All Status',
    'Paid Only',
    'Pending Only',
    'Overdue Only',
    'Draft Only',
  ];

  // Data from backend
  List<Map<String, dynamic>> _originalInvoices = [];
  List<Map<String, dynamic>> _originalClients = [];

  // Analytics data
  double totalRevenue = 0;
  double topClientRevenue = 0;
  double averageInvoice = 0;
  String topClient = '';
  double topClientPercentage = 0;

  List<Map<String, String>> allClientRows = [];
  List<Map<String, String>> filteredClientRows = [];
  List<Map<String, String>> paginatedClientRows = [];

  // Status breakdown
  int paidCount = 0;
  int pendingCount = 0;
  int overdueCount = 0;
  int draftCount = 0;

  // Client distribution data
  List<Map<String, dynamic>> clientDistribution = [];

  // Monthly data for chart
  Map<String, double> monthlyRevenue = {};
  double maxMonthlyRevenue = 0;

  // Pagination variables
  int _currentPage = 0;
  int _rowsPerPage = 5;
  int _totalRows = 0;
  List<int> _rowsPerPageOptions = [5, 10, 25, 50, 100];

  // Search/filter variables
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterClientRows();
      _currentPage = 0; // Reset to first page on search
    });
  }

  void _filterClientRows() {
    if (_searchQuery.isEmpty) {
      filteredClientRows = List.from(allClientRows);
    } else {
      filteredClientRows = allClientRows.where((client) {
        return client['name']!.toLowerCase().contains(_searchQuery) ||
            client['email']!.toLowerCase().contains(_searchQuery) ||
            client['status']!.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    _totalRows = filteredClientRows.length;
    _updatePaginatedRows();
  }

  void _updatePaginatedRows() {
    int start = _currentPage * _rowsPerPage;
    int end = (start + _rowsPerPage) > filteredClientRows.length
        ? filteredClientRows.length
        : start + _rowsPerPage;

    if (start < filteredClientRows.length) {
      paginatedClientRows = filteredClientRows.sublist(start, end);
    } else {
      paginatedClientRows = [];
    }
  }

  void _nextPage() {
    if ((_currentPage + 1) * _rowsPerPage < filteredClientRows.length) {
      setState(() {
        _currentPage++;
        _updatePaginatedRows();
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
        _updatePaginatedRows();
      });
    }
  }

  void _onRowsPerPageChanged(int? value) {
    setState(() {
      _rowsPerPage = value!;
      _currentPage = 0;
      _updatePaginatedRows();
    });
  }

  Future<void> _fetchAnalyticsData() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final supabase = Supabase.instance.client;

      // Fetch all invoices
      final invoicesResponse = await supabase
          .from('invoices')
          .select('''
            *,
            clients (
              id,
              name,
              email,
              phone
            )
          ''')
          .order('date_issued', ascending: false);

      _originalInvoices = List<Map<String, dynamic>>.from(invoicesResponse);

      // Fetch all clients for reference
      final clientsResponse = await supabase
          .from('clients')
          .select('*')
          .order('name');

      _originalClients = List<Map<String, dynamic>>.from(clientsResponse);

      // Extract unique client names for filter
      Set<String> clientNames = {};
      for (var invoice in _originalInvoices) {
        if (invoice['client_name'] != null && invoice['client_name'].toString().isNotEmpty) {
          clientNames.add(invoice['client_name'].toString());
        }
      }

      setState(() {
        _clients = ['All Clients', ...clientNames.toList()..sort()];
      });

      // Process the data
      _processAnalyticsData(_originalInvoices);

    } catch (e) {
      debugPrint('Error fetching analytics data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _applyFilters() {
    // Start with all invoices
    List<Map<String, dynamic>> filteredInvoices = List.from(_originalInvoices);

    // Apply status filter
    if (_selectedStatus != 'All Status') {
      String statusFilter = _selectedStatus.replaceAll(' Only', '').toUpperCase();
      filteredInvoices = filteredInvoices.where((invoice) {
        return (invoice['status'] as String?)?.toUpperCase() == statusFilter;
      }).toList();
    }

    // Apply client filter
    if (_selectedClient != 'All Clients') {
      filteredInvoices = filteredInvoices.where((invoice) {
        return (invoice['client_name'] as String?) == _selectedClient;
      }).toList();
    }

    // Apply period filter
    DateTime now = DateTime.now();
    if (_selectedPeriod != 'All') {
      filteredInvoices = filteredInvoices.where((invoice) {
        DateTime invoiceDate = DateTime.tryParse(invoice['date_issued'] ?? '') ?? DateTime(2000);

        switch (_selectedPeriod) {
          case 'Today':
            return invoiceDate.year == now.year &&
                invoiceDate.month == now.month &&
                invoiceDate.day == now.day;
          case '7D':
            return invoiceDate.isAfter(now.subtract(const Duration(days: 7)));
          case '30D':
            return invoiceDate.isAfter(now.subtract(const Duration(days: 30)));
          case 'YTD':
            return invoiceDate.year == now.year;
          default:
            return true;
        }
      }).toList();
    }

    // Process the filtered data
    _processAnalyticsData(filteredInvoices);
  }

  void _processAnalyticsData(List<Map<String, dynamic>> invoices) {
    // Reset data
    totalRevenue = 0;
    monthlyRevenue = {};
    Map<String, Map<String, dynamic>> clientStats = {};
    maxMonthlyRevenue = 0;

    // Process each invoice
    for (var invoice in invoices) {
      double amount = (invoice['amount'] ?? 0).toDouble();
      String clientName = invoice['client_name'] ?? 'Unknown';
      String status = invoice['status'] ?? 'DRAFT';
      String dateIssued = invoice['date_issued'] ?? '';

      // Add to total revenue
      totalRevenue += amount;

      // Update client stats
      if (!clientStats.containsKey(clientName)) {
        clientStats[clientName] = {
          'name': clientName,
          'totalRevenue': 0.0,
          'invoices': 0,
          'lastInvoice': dateIssued,
          'status': status,
          'email': _getClientEmail(clientName),
        };
      }

      clientStats[clientName]!['totalRevenue'] =
          (clientStats[clientName]!['totalRevenue'] as double) + amount;
      clientStats[clientName]!['invoices'] =
          (clientStats[clientName]!['invoices'] as int) + 1;

      // Track latest invoice date
      if (dateIssued.isNotEmpty) {
        DateTime currentLast = DateTime.tryParse(clientStats[clientName]!['lastInvoice'] ?? '') ?? DateTime(2000);
        DateTime newDate = DateTime.tryParse(dateIssued) ?? DateTime(2000);
        if (newDate.isAfter(currentLast)) {
          clientStats[clientName]!['lastInvoice'] = dateIssued;
          clientStats[clientName]!['status'] = status;
        }
      }

      // Monthly revenue for chart
      if (dateIssued.isNotEmpty) {
        try {
          DateTime date = DateTime.parse(dateIssued);
          String monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
          monthlyRevenue[monthKey] = (monthlyRevenue[monthKey] ?? 0) + amount;
          if (monthlyRevenue[monthKey]! > maxMonthlyRevenue) {
            maxMonthlyRevenue = monthlyRevenue[monthKey]!;
          }
        } catch (e) {
          // Skip if date parsing fails
        }
      }
    }

    // Convert client stats to list and sort by revenue
    List<Map<String, dynamic>> sortedClients = clientStats.entries.map((entry) {
      return {
        'name': entry.value['name'],
        'totalRevenue': entry.value['totalRevenue'],
        'invoices': entry.value['invoices'],
        'lastInvoice': entry.value['lastInvoice'],
        'status': entry.value['status'],
        'email': entry.value['email'],
      };
    }).toList();

    sortedClients.sort((a, b) =>
        (b['totalRevenue'] as double).compareTo(a['totalRevenue'] as double));

    // Calculate top client
    if (sortedClients.isNotEmpty) {
      topClient = sortedClients.first['name'];
      topClientRevenue = sortedClients.first['totalRevenue'];
      topClientPercentage = totalRevenue > 0
          ? (topClientRevenue / totalRevenue * 100)
          : 0;
    }

    // Calculate average invoice
    averageInvoice = invoices.isNotEmpty ? totalRevenue / invoices.length : 0;

    // Prepare all client rows for table
    allClientRows = sortedClients.map<Map<String, String>>((client) {
      double avgAmount = (client['invoices'] as int) > 0
          ? (client['totalRevenue'] as double) / (client['invoices'] as int)
          : 0;

      String lastInvoice = client['lastInvoice'] ?? '';
      String formattedDate = 'N/A';
      if (lastInvoice.isNotEmpty) {
        try {
          DateTime date = DateTime.parse(lastInvoice);
          formattedDate = '${date.day} ${_getMonthAbbr(date.month)} ${date.year}';
        } catch (e) {
          formattedDate = 'N/A';
        }
      }

      return {
        'name': client['name'] as String,
        'email': client['email'] as String,
        'revenue': _formatNumber((client['totalRevenue'] as double).round()),
        'revenue_raw': (client['totalRevenue'] as double).toString(),
        'invoices': (client['invoices'] as int).toString(),
        'avgAmount': _formatNumber(avgAmount.round()),
        'avgAmount_raw': avgAmount.toString(),
        'lastInvoice': formattedDate,
        'status': (client['status'] as String?)?.toUpperCase() ?? 'DRAFT',
      };
    }).toList();

    // Apply search filter and update pagination
    _filterClientRows();

    // Prepare client distribution (top 4 clients)
    clientDistribution = [];
    if (totalRevenue > 0) {
      for (var i = 0; i < sortedClients.length && i < 4; i++) {
        double percentage = (sortedClients[i]['totalRevenue'] as double) / totalRevenue * 100;
        clientDistribution.add({
          'name': sortedClients[i]['name'],
          'percentage': percentage,
          'amount': '₹${_formatNumber((sortedClients[i]['totalRevenue'] as double).round())}',
        });
      }
    }

    // Calculate status counts
    paidCount = invoices.where((i) => i['status'] == 'PAID').length;
    pendingCount = invoices.where((i) => i['status'] == 'PENDING').length;
    overdueCount = invoices.where((i) => i['status'] == 'OVERDUE').length;
    draftCount = invoices.where((i) => i['status'] == 'DRAFT').length;

    // Update UI
    setState(() {});
  }

  String _getClientEmail(String clientName) {
    try {
      // First try to get from invoice's client relation
      for (var invoice in _originalInvoices) {
        if (invoice['client_name'] == clientName &&
            invoice['clients'] != null &&
            invoice['clients']['email'] != null) {
          return invoice['clients']['email'];
        }
      }

      // Then try from clients table
      for (var client in _originalClients) {
        if (client['name'] == clientName && client['email'] != null) {
          return client['email'];
        }
      }
    } catch (e) {
      debugPrint('Error getting client email: $e');
    }
    return 'email@example.com';
  }

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatNumber(int number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(1)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(1)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatYAxisLabel(double value) {
    if (value >= 10000000) {
      return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
    } else if (value >= 100000) {
      return '₹${(value / 100000).toStringAsFixed(1)}L';
    } else if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(1)}K';
    }
    return '₹${value.round()}';
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _fetchAnalyticsData();
  }

  void _onPeriodChanged(String period) {
    setState(() => _selectedPeriod = period);
    if (_originalInvoices.isNotEmpty) {
      _applyFilters();
    }
  }

  void _onClientChanged(String? client) {
    setState(() => _selectedClient = client!);
    if (_originalInvoices.isNotEmpty) {
      _applyFilters();
    }
  }

  void _onStatusChanged(String? status) {
    setState(() => _selectedStatus = status!);
    if (_originalInvoices.isNotEmpty) {
      _applyFilters();
    }
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

          // Background blobs
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
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B8CFF)),
              ),
            )
                : Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTitle(),
                            const SizedBox(height: 24),
                            _buildFilters(),
                            const SizedBox(height: 24),
                            _buildEarningsChart(),
                            const SizedBox(height: 24),
                            _buildClientDistribution(),
                            const SizedBox(height: 24),
                            _buildKeyInsights(),
                            const SizedBox(height: 24),
                            _buildTopClientsTable(),
                          ],
                        ),
                      ),
                      if (_isRefreshing)
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B8CFF)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: _headerHeight,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.12))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
          ),
          const Expanded(
            child: Text(
              "Business Analytics",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 20, color: _isRefreshing ? Colors.grey : Colors.white70),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: Colors.white70),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Business Analytics",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        SizedBox(height: 4),
        Text(
          "Comprehensive insights and performance metrics",
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        // Period filters
        Row(
          children: _periods.map((period) {
            bool isSelected = period == _selectedPeriod;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _glassButton(
                  label: period,
                  isSelected: isSelected,
                  onTap: () => _onPeriodChanged(period),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        // Dropdown filters
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: _selectedClient,
                items: _clients,
                onChanged: _onClientChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                value: _selectedStatus,
                items: _statuses,
                onChanged: _onStatusChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1A1F2E),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          icon: Icon(Icons.arrow_drop_down, color: Colors.white.withOpacity(0.7)),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item, style: const TextStyle(color: Colors.white)),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildEarningsChart() {
    // Get last 6 months for display, but show at least 2
    List<String> months = monthlyRevenue.keys.toList()..sort();
    if (months.length > 6) {
      months = months.sublist(months.length - 6);
    }

    // Ensure we have at least 2 months for display
    while (months.length < 2) {
      months.add('No Data');
    }

    // Create Y-axis labels (5 steps)
    List<double> yAxisValues = [];
    if (maxMonthlyRevenue > 0) {
      for (int i = 0; i <= 5; i++) {
        yAxisValues.add((maxMonthlyRevenue * (5 - i) / 5).roundToDouble());
      }
    } else {
      yAxisValues = [0, 0, 0, 0, 0, 0];
    }

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Earnings Trend Analysis",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-axis labels
                SizedBox(
                  width: 60,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: yAxisValues.map((value) {
                      return Text(
                        _formatYAxisLabel(value),
                        style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 12),

                // Chart bars
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: months.map((month) {
                      double revenue = monthlyRevenue[month] ?? 0;
                      double percentage = maxMonthlyRevenue > 0 ? revenue / maxMonthlyRevenue : 0.1;
                      return _buildChartBar(month, percentage);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(String month, double percentage) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 140 * percentage.clamp(0.1, 1.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF5B8CFF), Color(0xFF9333EA)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          month,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildClientDistribution() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Client Distribution Card
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Client Distribution",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 16),
              if (clientDistribution.isNotEmpty)
                ...List.generate(clientDistribution.length, (index) {
                  return _buildClientItem(
                    clientDistribution[index]['name'],
                    '${(clientDistribution[index]['percentage'] as double).toStringAsFixed(1)}%',
                    clientDistribution[index]['amount'],
                    isSubItem: index == 1,
                  );
                })
              else
                _buildClientItem('No Data', '0%', '₹0'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Status Breakdown Card
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Status Breakdown",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 16),
              _buildStatusItem('Paid', paidCount, const Color(0xFF22C55E)),
              _buildStatusItem('Pending', pendingCount, const Color(0xFFF59E0B)),
              _buildStatusItem('Overdue', overdueCount, const Color(0xFFEF4444)),
              _buildStatusItem('Draft', draftCount, Colors.grey),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientItem(String name, String percentage, String amount, {bool isSubItem = false}) {
    return Padding(
      padding: EdgeInsets.only(left: isSubItem ? 16 : 0, bottom: 12),
      child: Row(
        children: [
          if (!isSubItem)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF5B8CFF)),
            ),
          if (isSubItem) const SizedBox(width: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSubItem ? FontWeight.normal : FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  percentage,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, int count, Color color) {
    int total = paidCount + pendingCount + overdueCount + draftCount;
    double percentage = total > 0 ? count / total : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(width: 8),
                  Text(
                    '($count)',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                  ),
                ],
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Key Insights & Recommendations",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 16),

        // Insight cards
        Row(
          children: [
            Expanded(
              child: _buildInsightCard(
                title: 'Total Revenue',
                value: '₹${_formatNumber(totalRevenue.round())}',
                description: 'Your business has generated ₹${_formatNumber(totalRevenue.round())} in total revenue.',
                valueColor: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInsightCard(
                title: 'Top Client',
                value: '${topClientPercentage.toStringAsFixed(1)}%',
                description: '$topClient contributes ${topClientPercentage.toStringAsFixed(1)}% of your revenue (₹${_formatNumber(topClientRevenue.round())}).',
                valueColor: const Color(0xFF5B8CFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInsightCard(
                title: 'Average Invoice',
                value: '₹${_formatNumber(averageInvoice.round())}',
                description: 'Your average invoice value is ₹${_formatNumber(averageInvoice.round())}.',
                valueColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),

        // Recommendations
        const SizedBox(height: 12),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recommendations',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                '• Consider following up with pending invoices ($pendingCount pending)\n'
                    '• Review overdue payments ($overdueCount overdue)\n'
                    '• Your top client $topClient represents ${topClientPercentage.toStringAsFixed(1)}% of revenue - consider diversifying',
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8), height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String description,
    required Color valueColor,
  }) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: valueColor),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTopClientsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Top Performing Clients",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 16),

        // Search Bar
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search clients...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
                onPressed: () {
                  _searchController.clear();
                },
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Table
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  // Table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 72),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)),
                        headingTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        dataTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
                        dividerThickness: 0,
                        columnSpacing: 24,
                        horizontalMargin: 16,
                        columns: const [
                          DataColumn(label: Text('CLIENT')),
                          DataColumn(label: Text('TOTAL REVENUE')),
                          DataColumn(label: Text('INVOICES')),
                          DataColumn(label: Text('AVG AMOUNT')),
                          DataColumn(label: Text('LAST INVOICE')),
                          DataColumn(label: Text('STATUS')),
                          DataColumn(label: Text('ACTIONS')),
                        ],
                        rows: paginatedClientRows.isEmpty
                            ? [
                          DataRow(cells: [
                            DataCell(Text('No data available',
                                style: TextStyle(color: Colors.white.withOpacity(0.5)))),
                            DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                            DataCell(Text('')), DataCell(Text('')), DataCell(Text('')),
                          ])
                        ]
                            : paginatedClientRows.map((client) {
                          return DataRow(cells: [
                            DataCell(
                            SizedBox(
                            width: 180,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  client['name']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  client['email']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                            DataCell(
                              SizedBox(
                                width: 100,
                                child: Text('₹${client['revenue']}'),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 70,
                                child: Text(client['invoices']!),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 90,
                                child: Text('₹${client['avgAmount']}'),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 90,
                                child: Text(client['lastInvoice']!),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 80,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(client['status']!).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _getStatusColor(client['status']!).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    client['status']!,
                                    style: TextStyle(
                                      color: _getStatusColor(client['status']!),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SizedBox(
                                width: 50,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.more_horiz,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _showClientDetails(client);
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),

                  // Pagination Controls
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Rows per page:\n${_currentPage * _rowsPerPage + 1}-${(_currentPage * _rowsPerPage + paginatedClientRows.length)} of $_totalRows',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _rowsPerPage,
                                      dropdownColor: const Color(0xFF1A1F2E),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      items: _rowsPerPageOptions.map((value) {
                                        return DropdownMenuItem(
                                          value: value,
                                          child: Text(value.toString()),
                                        );
                                      }).toList(),
                                      onChanged: _onRowsPerPageChanged,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.chevron_left,
                                    color: _currentPage > 0
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                                    size: 20,
                                  ),
                                  onPressed: _currentPage > 0 ? _previousPage : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.chevron_right,
                                    color: (_currentPage + 1) * _rowsPerPage < filteredClientRows.length
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                                    size: 20,
                                  ),
                                  onPressed: (_currentPage + 1) * _rowsPerPage < filteredClientRows.length
                                      ? _nextPage
                                      : null,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showClientDetails(Map<String, String> client) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1F2E),
          title: Text(
            client['name']!,
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Email', client['email']!),
              _buildDetailRow('Total Revenue', '₹${client['revenue']}'),
              _buildDetailRow('Invoices', client['invoices']!),
              _buildDetailRow('Average Amount', '₹${client['avgAmount']}'),
              _buildDetailRow('Last Invoice', client['lastInvoice']!),
              _buildDetailRow('Status', client['status']!),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Color(0xFF5B8CFF))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
          ),
          Text(
            ':',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PAID': return const Color(0xFF22C55E);
      case 'PENDING': return const Color(0xFFF59E0B);
      case 'OVERDUE': return const Color(0xFFEF4444);
      case 'DRAFT': return Colors.grey;
      default: return Colors.white;
    }
  }

  Widget _glassButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5B8CFF).withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5B8CFF).withOpacity(0.5)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF5B8CFF) : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
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
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}