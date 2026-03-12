// lib/screens/client_management_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'SupabaseServiceClient.dart';
import '../../models/client_model.dart';
import '../../core/widgets/client_journey_widget.dart';
import '../invoice/invoice_detail.dart';

class ClientManagementScreen extends StatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();

  List<ClientModel> _clients = [];
  List<ClientModel> _filteredClients = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String _selectedSort = 'Recent';
  bool _showSearchStatus = false;

  int _totalClients = 0;
  int _newThisMonth = 0;
  double _totalRevenue = 0;
  double _avgClientValue = 0;
  double _paymentRate = 0;

  final List<String> _filterOptions = ['All', 'VIP', 'Overdue', 'Dormant'];
  final List<String> _sortOptions = ['Recent', 'Name', 'Amount', 'Last Invoice'];

  @override
  void initState() {
    super.initState();
    _loadData();
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
      _searchQuery = _searchController.text;
      _showSearchStatus = _searchQuery.isNotEmpty;
    });
    _applyFilters();
  }

  void _clearSearch() {
    _searchController.clear();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clientsData = await _supabaseService.getClientsWithInvoices();
      
      final List<ClientModel> clients = [];
      for (var json in clientsData) {
        try {
          clients.add(ClientModel.fromJson(json));
        } catch (e) {
          print('Error parsing client: $e');
        }
      }

      final stats = await _supabaseService.getDashboardStats();

      setState(() {
        _clients = clients;
        _filteredClients = clients;
        _totalClients = stats['totalClients'] ?? 0;
        _newThisMonth = stats['newThisMonth'] ?? 0;
        _totalRevenue = (stats['totalRevenue'] as num?)?.toDouble() ?? 0;
        _avgClientValue = (stats['avgClientValue'] as num?)?.toDouble() ?? 0;
        _paymentRate = (stats['paymentRate'] as num?)?.toDouble() ?? 0;
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<ClientModel> filtered = List.from(_clients);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((client) {
        return client.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            client.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (client.phone?.contains(_searchQuery) ?? false);
      }).toList();
    }

    if (_selectedFilter != 'All') {
      filtered = filtered.where((client) {
        switch (_selectedFilter) {
          case 'VIP':
            return client.isVip;
          case 'Overdue':
            return client.hasOverdue;
          case 'Dormant':
            return client.isDormant;
          default:
            return true;
        }
      }).toList();
    }

    switch (_selectedSort) {
      case 'Recent':
        filtered.sort((a, b) {
          if (a.lastInvoiceDate == null) return 1;
          if (b.lastInvoiceDate == null) return -1;
          return b.lastInvoiceDate!.compareTo(a.lastInvoiceDate!);
        });
        break;
      case 'Name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Amount':
        filtered.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case 'Last Invoice':
        filtered.sort((a, b) {
          if (a.lastInvoiceDate == null) return 1;
          if (b.lastInvoiceDate == null) return -1;
          return b.lastInvoiceDate!.compareTo(a.lastInvoiceDate!);
        });
        break;
    }

    setState(() {
      _filteredClients = filtered;
    });
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
            child: _liquidBlob(320, 420, const Color(0xFF9333EA), 0.28),
          ),
          Positioned(
            bottom: -160,
            right: -120,
            child: _liquidBlob(380, 460, const Color(0xFF3B82F6), 0.26),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF5B8CFF)),
                    ),
                  )
                else if (_error != null)
                  _buildErrorState()
                else
                  Expanded(
                    child: Column(
                      children: [
                        _buildStatsCards(),
                        _buildFilterAndSort(),
                        if (_showSearchStatus) _buildSearchStatus(),
                        Expanded(
                          child: _filteredClients.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                  itemCount: _filteredClients.length,
                                  itemBuilder: (context, index) {
                                    return _buildClientCard(_filteredClients[index]);
                                  },
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
      floatingActionButton: !_isLoading && _error == null
          ? FloatingActionButton(
              heroTag: "cmsFAB",
              onPressed: _showAddClientModal,
              backgroundColor: const Color(0xFF5B8CFF),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.12))),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Client Management", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 18)),
                SizedBox(height: 2),
                Text("Manage client relationships and track performance", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search clients by name, email, phone...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.5)),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF5B8CFF).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B8CFF).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 16, color: const Color(0xFF5B8CFF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Found ${_filteredClients.length} client${_filteredClients.length != 1 ? 's' : ''} for "$_searchQuery"',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _clearSearch,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            child: const Text('Clear', style: TextStyle(color: Color(0xFF5B8CFF), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text('Error loading data', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.white54, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5B8CFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
            size: 60,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No clients match your search' : 'No clients found',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          ),
          if (_searchQuery.isNotEmpty)
            TextButton(onPressed: _clearSearch, child: const Text('Clear Search'))
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard(
              value: _totalClients.toString(),
              label: "Total Clients",
              subLabel: "$_newThisMonth new this month",
              color: const Color(0xFF5B8CFF),
              icon: Icons.people,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              value: _formatCurrency(_totalRevenue),
              label: "Total Revenue",
              subLabel: "12.5% growth",
              color: const Color(0xFF22C55E),
              icon: Icons.currency_rupee,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              value: _formatCurrency(_avgClientValue),
              label: "Avg Client Value",
              subLabel: "1.8% increase",
              color: const Color(0xFFF59E0B),
              icon: Icons.trending_up,
            ),
            const SizedBox(width: 12),
            _buildStatCard(
              value: "${_paymentRate.toStringAsFixed(0)}%",
              label: "Payment Rate",
              subLabel: "1.5% improvement",
              color: const Color(0xFFEC4899),
              icon: Icons.percent,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(2)}Cr';
    } else if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(2)}L';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    } else {
      return '₹${value.toStringAsFixed(0)}';
    }
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required String subLabel,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      width: 140,
      child: _GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 12, color: color),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('↗', style: TextStyle(color: color, fontSize: 10)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: Text(subLabel, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterAndSort() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : const Color.fromARGB(255, 0, 0, 0))),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        _applyFilters();
                      },
                      backgroundColor: Colors.white.withOpacity(0.05),
                      selectedColor: const Color(0xFF5B8CFF),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("SORT:", style: TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Container(
                  constraints: const BoxConstraints(minWidth: 70, maxWidth: 90),
                  child: DropdownButton<String>(
                    value: _selectedSort,
                    isDense: true,
                    dropdownColor: const Color(0xFF1A1F2E),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    items: _sortOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value, style: const TextStyle(fontSize: 11)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSort = value;
                        });
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(ClientModel client) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _GlassContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: client.isVip
                          ? [const Color(0xFFFFD700), const Color(0xFFFBBF24)]
                          : client.hasOverdue
                              ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                              : client.isDormant
                                  ? [const Color(0xFF6B7280), const Color(0xFF4B5563)]
                                  : [const Color(0xFF5B8CFF), const Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: Text(client.initials, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(client.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis),
                          ),
                          if (client.isVip)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFFFD700).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                              child: const Text('🌟 VIP', style: TextStyle(fontSize: 9, color: Color(0xFFFFD700), fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(client.contactName != null ? "POC: ${client.contactName}" : "No contact person", style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5)),
                  color: const Color(0xFF1A1F2E),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditClientModal(client);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(client);
                    } else if (value == 'journey') {
                      _showClientJourney(client);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'journey', child: Row(children: [Icon(Icons.timeline, size: 18, color: Color(0xFF5B8CFF)), SizedBox(width: 8), Text('View Journey', style: TextStyle(color: Colors.white))])),
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Color(0xFF5B8CFF)), SizedBox(width: 8), Text('Edit', style: TextStyle(color: Colors.white))])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (client.hasOverdue)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                      child: const Text('⚠️ Overdue', style: TextStyle(fontSize: 10, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                    ),
                  if (client.isDormant)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: const Text('😴 Dormant', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInfoChip(Icons.phone_outlined, client.phone ?? 'No phone')),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoChip(Icons.email_outlined, client.email)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(client.invoices.length.toString(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Invoices',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10))
                      ],
                    ),
                  ),
                  Container(height: 30, width: 1, color: Colors.white.withOpacity(0.1)),
                  Expanded(child: Column(children: [Text(currencyFormat.format(client.totalAmount), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text('Revenue', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10))])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showClientJourney(client),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF5B8CFF).withOpacity(0.15), const Color(0xFF5B8CFF).withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF5B8CFF).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        children: [
                          Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.1), width: 2))),
                          CircularProgressIndicator(
                            value: client.collectionRate / 100,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              client.collectionRate >= 70 ? const Color(0xFF22C55E) : client.collectionRate >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                            ),
                            strokeWidth: 3,
                          ),
                          Center(child: Text('${client.collectionRate.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Collected: ${currencyFormat.format(client.paidAmount)}', style: const TextStyle(color: Color(0xFF22C55E), fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Last invoice ${client.formattedLastInvoice}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white54),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  void _showAddClientModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClientFormModal(
        onSave: (clientData) async {
          Navigator.pop(context);
          try {
            await _supabaseService.createClient(clientData);
            await _loadData();
            if (mounted) _showSnackBar('Client added successfully', isSuccess: true);
          } catch (e) {
            if (mounted) _showSnackBar('Error: ${e.toString()}');
          }
        },
      ),
    );
  }

  void _showEditClientModal(ClientModel client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ClientFormModal(
        client: client,
        onSave: (clientData) async {
          Navigator.pop(context);
          try {
            await _supabaseService.updateClient(client.id!, clientData);
            await _loadData();
            if (mounted) _showSnackBar('Client updated successfully', isSuccess: true);
          } catch (e) {
            if (mounted) _showSnackBar('Error: ${e.toString()}');
          }
        },
      ),
    );
  }

  void _showDeleteConfirmation(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text('Delete Client', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to delete ${client.name}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _supabaseService.deleteClient(client.id!);
                await _loadData();
                if (mounted) _showSnackBar('Client deleted successfully');
              } catch (e) {
                if (mounted) _showSnackBar('Error: ${e.toString()}');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClientJourney(ClientModel client) {
    final List<Map<String, dynamic>> timeline = [];
    
    if (client.createdAt != null) {
      timeline.add({
        'type': 'client_created',
        'date': client.createdAt!.toIso8601String(),
      });
    }
    
    for (var invoice in client.invoices) {
      timeline.add({
        'type': 'invoice_created',
        'date': invoice['date_issued'] ?? invoice['date'],
        'amount': invoice['amount'],
        'status': invoice['status'],
        'number': invoice['id'] ?? invoice['number'],
      });
      
      if (invoice['status']?.toString().toLowerCase() == 'paid') {
        timeline.add({
          'type': 'invoice_paid',
          'date': invoice['paid_date'] ?? invoice['date_issued'] ?? invoice['date'],
          'amount': invoice['amount'],
          'status': invoice['status'],
          'number': invoice['id'] ?? invoice['number'],
        });
      }
    }
    
    timeline.sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B0F1A).withOpacity(0.95),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [const Color(0xFF5B8CFF).withOpacity(0.2), const Color(0xFF5B8CFF).withOpacity(0.1)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text('🗺️', style: TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${client.name}\'s Journey', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${client.totalInvoices} invoices • ${_formatCurrency(client.totalAmount)}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ClientJourneyWidget(client: client, timeline: timeline),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? const Color(0xFF22C55E) : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _liquidBlob(double width, double height, Color color, double opacity) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(width: width, height: height, decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: color.withOpacity(opacity))),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ClientFormModal extends StatefulWidget {
  final ClientModel? client;
  final Function(Map<String, dynamic>) onSave;

  const _ClientFormModal({this.client, required this.onSave});

  @override
  State<_ClientFormModal> createState() => __ClientFormModalState();
}

class __ClientFormModalState extends State<_ClientFormModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _contactPersonController;
  late TextEditingController _companyController;
  late TextEditingController _addressController;
  late String _paymentTerms;
  late String _status;

  // Map to convert between database values and display values
  final Map<String, String> _paymentTermsMap = {
    'net15': 'net_15_days',
    'net30': 'net_30_days',
    'net45': 'net_45_days',
    'net60': 'net_60_days',
    'due_on_receipt': 'due_on_receipt',
    'net_15_days': 'net_15_days',
    'net_30_days': 'net_30_days',
    'net_45_days': 'net_45_days',
    'net_60_days': 'net_60_days',
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client?.name ?? '');
    _emailController = TextEditingController(text: widget.client?.email ?? '');
    _phoneController = TextEditingController(text: widget.client?.phone ?? '');
    _contactPersonController = TextEditingController(text: widget.client?.contactName ?? '');
    _companyController = TextEditingController(text: widget.client?.company ?? '');
    _addressController = TextEditingController(text: widget.client?.address ?? '');
    
    // Convert database value to dropdown value
    String dbValue = widget.client?.paymentTerms ?? 'net_30_days';
    _paymentTerms = _paymentTermsMap[dbValue] ?? 'net_30_days';
    
    _status = widget.client?.status ?? 'Active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _contactPersonController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.client != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0B0F1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF5B8CFF).withOpacity(0.2),
                                const Color(0xFF5B8CFF).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            isEditing ? '✏️' : '➕',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEditing ? 'Edit Client' : 'Add New Client',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildField(
                                  'Client Name *',
                                  _nameController,
                                  validator: (v) =>
                                  v?.isEmpty == true ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildField(
                                  'Email *',
                                  _emailController,
                                  validator: (v) => v?.isEmpty == true
                                      ? 'Required'
                                      : v?.contains('@') == false
                                      ? 'Invalid email'
                                      : null,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(child: _buildField('Phone', _phoneController)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildField('Contact Person', _contactPersonController)),
                            ],
                          ),

                          const SizedBox(height: 16),
                          _buildField('Company', _companyController),

                          const SizedBox(height: 16),
                          _buildField('Address', _addressController, maxLines: 2),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Payment Terms',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: DropdownButton<String>(
                                        value: _paymentTerms,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF1A1F2E),
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                        style: const TextStyle(color: Colors.white),
                                        items: const [
                                          DropdownMenuItem(value: 'net_15_days', child: Text('Net 15 days')),
                                          DropdownMenuItem(value: 'net_30_days', child: Text('Net 30 days')),
                                          DropdownMenuItem(value: 'net_45_days', child: Text('Net 45 days')),
                                          DropdownMenuItem(value: 'net_60_days', child: Text('Net 60 days')),
                                          DropdownMenuItem(value: 'due_on_receipt', child: Text('Due on receipt')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() => _paymentTerms = value);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Status',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      ),
                                      child: DropdownButton<String>(
                                        value: _status,
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF1A1F2E),
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                        style: const TextStyle(color: Colors.white),
                                        items: const [
                                          DropdownMenuItem(value: 'Active', child: Text('Active')),
                                          DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() => _status = value);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate()) {
                                      widget.onSave({
                                        'name': _nameController.text,
                                        'email': _emailController.text,
                                        'phone': _phoneController.text.isEmpty
                                            ? null
                                            : _phoneController.text,
                                        'contact_name': _contactPersonController.text.isEmpty
                                            ? null
                                            : _contactPersonController.text,
                                        'company': _companyController.text.isEmpty
                                            ? null
                                            : _companyController.text,
                                        'address': _addressController.text.isEmpty
                                            ? null
                                            : _addressController.text,
                                        'payment_terms': _paymentTerms,
                                        'status': _status,
                                      });
                                    }
                                  },
                                  child: Text(isEditing ? 'Update' : 'Save'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildField(String label, TextEditingController controller, {int maxLines = 1, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter ${label.replaceAll(' *', '').toLowerCase()}',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF5B8CFF), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }
}