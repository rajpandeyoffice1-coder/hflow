import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessAnalyticsScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const BusinessAnalyticsScreen({super.key, this.onBack});

  @override
  State<BusinessAnalyticsScreen> createState() =>
      _BusinessAnalyticsScreenState();
}

class _BusinessAnalyticsScreenState extends State<BusinessAnalyticsScreen> {
  static const double _headerHeight = 64;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String _selectedPeriod = 'Today';
  String _selectedClient = 'All Clients';
  String _selectedStatus = 'All Status';

  final List<String> _periods = ['Today', '7D', '30D', 'YTD', 'All'];
  final List<String> _clients = [
    'All Clients',
    'Tata Motors Ltd',
    'Metro Builders',
    'Apex Pharmaceuticals',
    'Infosys Limited',
    'UrbanClap Technologies',
    'Global Trading Co',
    'Greenfield Constructions',
    'TechMahindra Solutions',
    'Zomato Media',
    'Retail Solutions India',
  ];
  final List<String> _statuses = [
    'All Status',
    'Paid Only',
    'Pending Only',
    'Overdue Only',
    'Draft Only',
  ];

  // Original data from backend
  List<dynamic> _originalInvoices = [];
  List<dynamic> _originalClients = [];
  
  // Analytics data from backend
  double totalRevenue = 0;
  double topClientRevenue = 0;
  double averageInvoice = 0;
  String topClient = '';
  double topClientPercentage = 0;

  List<Map<String, dynamic>> clientsList = [];
  List<Map<String, String>> clientRows = [];

  // Status breakdown
  double paidPercentage = 0;
  double pendingPercentage = 0;
  double overduePercentage = 0;

  // Client distribution data
  List<Map<String, dynamic>> clientDistribution = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalyticsData();
  }

  Future<void> _fetchAnalyticsData() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final supabase = Supabase.instance.client;

      // Fetch invoices data
      _originalInvoices = await supabase.from('invoices').select('*');

      // Fetch clients data
      _originalClients = await supabase.from('clients').select('*');

      // Process the data with current filters
      _applyFilters();
    } catch (e) {
      debugPrint('Error fetching analytics data: $e');
      // Fallback to sample data if error occurs
      _loadSampleData();
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
    List<dynamic> filteredInvoices = List.from(_originalInvoices);
    
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
    if (_selectedPeriod != 'All') {
      DateTime now = DateTime.now();
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
    _processAnalyticsData(filteredInvoices, _originalClients);
  }

  void _processAnalyticsData(List<dynamic> invoices, List<dynamic> clients) {
    // Calculate total revenue
    totalRevenue = invoices.fold<double>(
      0,
      (sum, invoice) => sum + (invoice['amount'] as num).toDouble(),
    );

    // Calculate average invoice
    averageInvoice = invoices.isNotEmpty ? totalRevenue / invoices.length : 0;

    // Group invoices by client
    Map<String, Map<String, dynamic>> clientStats = {};

    for (var invoice in invoices) {
      String clientId = invoice['client_id'] ?? '';
      String clientName = invoice['client_name'] ?? 'Unknown';
      double amount = (invoice['amount'] as num).toDouble();
      String status = invoice['status'] ?? 'DRAFT';
      String dateIssued = invoice['date_issued'] ?? '';

      if (!clientStats.containsKey(clientId)) {
        clientStats[clientId] = {
          'name': clientName,
          'email': _getClientEmail(clients, clientId),
          'totalRevenue': 0.0,
          'invoices': 0,
          'lastInvoice': '',
          'lastInvoiceDate': DateTime(2000),
          'status': status,
        };
      }

      clientStats[clientId]!['totalRevenue'] += amount;
      clientStats[clientId]!['invoices'] += 1;

      // Track latest invoice
      DateTime invoiceDate = DateTime.tryParse(dateIssued) ?? DateTime(2000);
      if (invoiceDate.isAfter(clientStats[clientId]!['lastInvoiceDate'])) {
        clientStats[clientId]!['lastInvoiceDate'] = invoiceDate;
        clientStats[clientId]!['lastInvoice'] = _formatDate(invoiceDate);
        clientStats[clientId]!['status'] = status;
      }
    }

    // Convert to list and sort by revenue
    List<Map<String, dynamic>> sortedClients = clientStats.entries.map((entry) {
      return {
        'id': entry.key,
        'name': entry.value['name'],
        'email': entry.value['email'],
        'totalRevenue': entry.value['totalRevenue'],
        'invoices': entry.value['invoices'].toString(),
        'lastInvoice': entry.value['lastInvoice'],
        'status': entry.value['status'],
      };
    }).toList();

    sortedClients.sort(
      (a, b) => b['totalRevenue'].compareTo(a['totalRevenue']),
    );

    // Find top client
    if (sortedClients.isNotEmpty) {
      topClient = sortedClients.first['name'];
      topClientRevenue = sortedClients.first['totalRevenue'];
      topClientPercentage = totalRevenue > 0
          ? (topClientRevenue / totalRevenue * 100)
          : 0;
    }

    // Prepare client rows for table
    clientRows = sortedClients.map<Map<String, String>>((client) {
      double avgAmount = client['invoices'] != '0'
          ? client['totalRevenue'] / int.parse(client['invoices'])
          : 0;

      return {
        'name': client['name'] as String,
        'email': client['email'] as String,
        'revenue': _formatNumber((client['totalRevenue'] as num).toInt()),
        'invoices': client['invoices'] as String,
        'avgAmount': _formatNumber(avgAmount.toInt()),
        'lastInvoice': client['lastInvoice'] as String? ?? 'N/A',
        'status':
            (client['status'] as String?)?.toString().toUpperCase() ?? 'DRAFT',
      };
    }).toList();

    // Prepare client distribution
    clientDistribution = sortedClients.take(4).map((client) {
      return {
        'name': client['name'],
        'percentage': totalRevenue > 0
            ? (client['totalRevenue'] / totalRevenue * 100)
            : 0,
        'amount': '€${_formatNumber((client['totalRevenue'] as num).toInt())}',
      };
    }).toList();

    // Calculate status breakdown
    int totalInvoices = invoices.length;
    if (totalInvoices > 0) {
      int paidCount = invoices.where((i) => i['status'] == 'PAID').length;
      int pendingCount = invoices.where((i) => i['status'] == 'PENDING').length;
      int overdueCount = invoices.where((i) => i['status'] == 'OVERDUE').length;

      paidPercentage = paidCount / totalInvoices;
      pendingPercentage = pendingCount / totalInvoices;
      overduePercentage = overdueCount / totalInvoices;
    } else {
      paidPercentage = 0;
      pendingPercentage = 0;
      overduePercentage = 0;
    }
  }

  String _getClientEmail(List<dynamic> clients, String clientId) {
    try {
      var client = clients.firstWhere(
        (c) => c['id'].toString() == clientId,
        orElse: () => null,
      );
      return client != null
          ? client['email'] ?? 'email@example.com'
          : 'email@example.com';
    } catch (e) {
      return 'email@example.com';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_getMonthAbbr(date.month)} ${date.year}';
  }

  String _getMonthAbbr(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _loadSampleData() {
    // Fallback sample data from your original code
    totalRevenue = 2329000;
    topClientRevenue = 450000;
    averageInvoice = 116450;
    topClient = 'Tata Motors Ltd';
    topClientPercentage = 19.3;
    paidPercentage = 0.65;
    pendingPercentage = 0.25;
    overduePercentage = 0.10;

    clientRows = [
      {
        'name': 'Tata Motors Ltd',
        'email': 'payables@tatamotors.com',
        'revenue': '4,50,000',
        'invoices': '1',
        'avgAmount': '4,50,000',
        'lastInvoice': '8 Feb 2025',
        'status': 'PAID',
      },
      {
        'name': 'Metro Builders',
        'email': 'finance@metrobuilders.com',
        'revenue': '3,45,000',
        'invoices': '1',
        'avgAmount': '3,45,000',
        'lastInvoice': '28 Jan 2025',
        'status': 'PENDING',
      },
      {
        'name': 'Apex Pharmaceuticals',
        'email': 'billing@apexpharma.com',
        'revenue': '2,10,000',
        'invoices': '1',
        'avgAmount': '2,10,000',
        'lastInvoice': '25 Jan 2025',
        'status': 'PAID',
      },
      {
        'name': 'Infosys Limited',
        'email': 'vendor@infosys.com',
        'revenue': '1,85,000',
        'invoices': '1',
        'avgAmount': '1,85,000',
        'lastInvoice': '14 Feb 2025',
        'status': 'PENDING',
      },
      {
        'name': 'UrbanClap Technologies',
        'email': 'accounts@urbanclap.com',
        'revenue': '1,48,000',
        'invoices': '1',
        'avgAmount': '1,48,000',
        'lastInvoice': '27 Feb 2025',
        'status': 'PENDING',
      },
      {
        'name': 'Global Trading Co',
        'email': 'accounts@globaltrading.com',
        'revenue': '1,25,000',
        'invoices': '1',
        'avgAmount': '1,25,000',
        'lastInvoice': '18 Feb 2025',
        'status': 'DRAFT',
      },
      {
        'name': 'Greenfield Constructions',
        'email': 'finance@greenfield.com',
        'revenue': '1,25,000',
        'invoices': '1',
        'avgAmount': '1,25,000',
        'lastInvoice': '15 Jan 2025',
        'status': 'PENDING',
      },
      {
        'name': 'TechMahindra Solutions',
        'email': 'invoices@techmahindra.com',
        'revenue': '95,000',
        'invoices': '1',
        'avgAmount': '95,000',
        'lastInvoice': '25 Feb 2025',
        'status': 'DRAFT',
      },
      {
        'name': 'Zomato Media',
        'email': 'finance@zomato.com',
        'revenue': '92,000',
        'invoices': '1',
        'avgAmount': '92,000',
        'lastInvoice': '19 Feb 2025',
        'status': 'PAID',
      },
      {
        'name': 'Retail Solutions India',
        'email': 'finance@retailsolutions.in',
        'revenue': '89,000',
        'invoices': '1',
        'avgAmount': '89,000',
        'lastInvoice': '20 Jan 2025',
        'status': 'OVERDUE',
      },
    ];

    clientDistribution = [
      {'name': 'Tata Motors Ltd', 'percentage': 19.3, 'amount': '€4,50,000'},
      {
        'name': 'Apex Pharmaceuticals',
        'percentage': null,
        'amount': '€2,10,000',
      },
      {'name': 'Infosys Limited', 'percentage': null, 'amount': '€9,52,000'},
      {
        'name': 'UrbanClap Technologies',
        'percentage': null,
        'amount': '€1,16,450',
      },
    ];
  }

  Future<void> _refreshData() async {
    setState(() {
      _isRefreshing = true;
    });

    await _fetchAnalyticsData();
  }

  void _onPeriodChanged(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    if (_originalInvoices.isNotEmpty) {
      _applyFilters();
    }
  }

  void _onClientChanged(String? client) {
    setState(() {
      _selectedClient = client!;
    });
    if (_originalInvoices.isNotEmpty) {
      _applyFilters();
    }
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status!;
    });
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
          // Background gradients
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
              ),
            ),
          ),

          // Background blobs with unique keys to avoid hero conflicts
          Positioned(
            top: -120,
            left: -100,
            child: _liquidBlob(
              key: const ValueKey('blob1'),
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
              key: const ValueKey('blob2'),
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF5B8CFF),
                      ),
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
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.transparent,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF5B8CFF),
                                      ),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          // Refresh button
          IconButton(
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: _isRefreshing ? Colors.grey : Colors.white70,
            ),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20, color: Colors.white70),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              // Navigate to login screen or handle logout
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
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
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
          icon: Icon(
            Icons.arrow_drop_down,
            color: Colors.white.withOpacity(0.7),
          ),
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
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Earnings Trend Analysis",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          // Chart bars with fixed height
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
                    children: [
                      _buildYAxisLabel('€7,00,000'),
                      _buildYAxisLabel('€6,00,000'),
                      _buildYAxisLabel('€5,00,000'),
                      _buildYAxisLabel('€4,00,000'),
                      _buildYAxisLabel('€3,00,000'),
                      _buildYAxisLabel('€2,00,000'),
                      _buildYAxisLabel('€1,00,000'),
                      _buildYAxisLabel('€0'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Chart bars
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildChartBar('2025-01', 0.6),
                      _buildChartBar('2025-02', 0.9),
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

  Widget _buildYAxisLabel(String label) {
    return Text(
      label,
      style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.5)),
    );
  }

  Widget _buildChartBar(String month, double percentage) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 40,
          height: 140 * percentage,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF5B8CFF),
                const Color(0xFF9333EA).withOpacity(0.7),
              ],
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Use dynamic data if available, otherwise fallback to sample
              if (clientDistribution.isNotEmpty) ...[
                for (int i = 0; i < clientDistribution.length; i++)
                  _buildClientItem(
                    clientDistribution[i]['name'],
                    clientDistribution[i]['percentage'] != null
                        ? '${(clientDistribution[i]['percentage'] as double).toStringAsFixed(1)}%'
                        : null,
                    clientDistribution[i]['amount'],
                    isSubItem: i == 1, // Second item as sub-item
                  ),
              ] else ...[
                _buildClientItem('Tata Motors Ltd', '19.3%', '€4,50,000'),
                _buildClientItem(
                  'Apex Pharmaceuticals',
                  null,
                  '€2,10,000',
                  isSubItem: true,
                ),
                _buildClientItem('Infosys Limited', null, '€9,52,000'),
                _buildClientItem('UrbanClap Technologies', null, '€1,16,450'),
              ],
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              _buildStatusItem('Paid', paidPercentage, const Color(0xFF22C55E)),
              _buildStatusItem(
                'Pending',
                pendingPercentage,
                const Color(0xFFF59E0B),
              ),
              _buildStatusItem(
                'Overdue',
                overduePercentage,
                const Color(0xFFEF4444),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClientItem(
    String name,
    String? percentage,
    String amount, {
    bool isSubItem = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: isSubItem ? 16 : 0, bottom: 12),
      child: Row(
        children: [
          if (!isSubItem)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF5B8CFF),
              ),
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
                if (percentage != null)
                  Text(
                    percentage,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, double percentage, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                '${(percentage * 100).toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // First row - 3 cards
        Row(
          children: [
            Expanded(
              child: _buildInsightCard(
                title: 'Total Revenue',
                value: '€${_formatNumber(totalRevenue.toInt())}',
                description:
                    'Your business has generated €${_formatNumber(totalRevenue.toInt())} in total revenue.',
                valueColor: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInsightCard(
                title: 'Top Client',
                value: '${topClientPercentage.toStringAsFixed(1)}%',
                description:
                    '$topClient contributes ${topClientPercentage.toStringAsFixed(1)}% of your revenue (€${_formatNumber(topClientRevenue.toInt())}).',
                valueColor: const Color(0xFF5B8CFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInsightCard(
                title: 'Average Invoice',
                value: '€${_formatNumber(averageInvoice.toInt())}',
                description:
                    'Your average invoice value is €${_formatNumber(averageInvoice.toInt())}.',
                valueColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),

        // Second row - full width card for recommendations
        const SizedBox(height: 12),
        _glassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recommendations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Consider following up with pending invoices from Metro Builders and Infosys Limited\n'
                '• Review overdue payments from Retail Solutions India\n'
                '• Your top client $topClient represents ${topClientPercentage.toStringAsFixed(1)}% of revenue - consider diversifying',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.5,
                ),
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
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
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
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Fixed width container for horizontal scrolling
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth:
                        MediaQuery.of(context).size.width -
                        72, // Account for padding
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.white.withOpacity(0.1),
                    ),
                    dataRowColor: WidgetStateProperty.resolveWith<Color?>((
                      Set<WidgetState> states,
                    ) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white.withOpacity(0.15);
                      }
                      return Colors.transparent;
                    }),
                    headingTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    dataTextStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
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
                    rows: clientRows.map((client) {
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 180,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    client['name']!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    client['email']!,
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
                              child: Text('€${client['revenue']}'),
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
                              child: Text('€${client['avgAmount']}'),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    client['status']!,
                                  ).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _getStatusColor(
                                      client['status']!,
                                    ).withOpacity(0.3),
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
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PAID':
        return const Color(0xFF22C55E);
      case 'PENDING':
        return const Color(0xFFF59E0B);
      case 'OVERDUE':
        return const Color(0xFFEF4444);
      case 'DRAFT':
        return Colors.grey;
      default:
        return Colors.white;
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
          color: isSelected
              ? const Color(0xFF5B8CFF).withOpacity(0.2)
              : Colors.transparent,
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
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
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
    Key? key,
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    return ImageFiltered(
      key: key,
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