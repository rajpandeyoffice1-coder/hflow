import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/client_model.dart';
import 'package:hflow/features/invoice/invoice_detail.dart';

class ClientJourneyWidget extends StatefulWidget {
  final ClientModel client;
  final List<Map<String, dynamic>> timeline;

  const ClientJourneyWidget({
    super.key,
    required this.client,
    required this.timeline,
  });

  @override
  State<ClientJourneyWidget> createState() => _ClientJourneyWidgetState();
}

class _ClientJourneyWidgetState extends State<ClientJourneyWidget> {
  String _selectedRange = '6M';
  final List<String> _dateRanges = ['3M', '6M', '1Y', 'Custom'];

  // Cache for processed data
  Map<String, dynamic> _cachedMonthlyData = {};
  DateTime _lastCacheUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _processMonthlyData();
  }

  @override
  void didUpdateWidget(ClientJourneyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeline != widget.timeline ||
        oldWidget.client != widget.client) {
      _processMonthlyData();
    }
  }

  void _processMonthlyData() {
    _cachedMonthlyData = _getMonthlyData();
    _lastCacheUpdate = DateTime.now();
  }

  Map<String, dynamic> _getMonthlyData() {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (_selectedRange) {
      case '3M':
        startDate = DateTime(now.year, now.month - 2, 1);
        break;
      case '6M':
        startDate = DateTime(now.year, now.month - 5, 1);
        break;
      case '1Y':
        startDate = DateTime(now.year - 1, now.month, 1);
        break;
      case 'Custom':
        startDate = DateTime(now.year - 1, now.month, 1);
        break;
      default:
        startDate = DateTime(now.year, now.month - 5, 1);
    }

    // Initialize monthly stats for the last 12 months
    Map<String, Map<String, dynamic>> monthlyStats = {};

    for (int i = 0; i < 12; i++) {
      DateTime monthDate = DateTime(now.year, now.month - i, 1);
      String monthKey = DateFormat('yyyy-MM').format(monthDate);
      monthlyStats[monthKey] = {
        'revenue': 0.0,
        'invoices': 0,
        'paidInvoices': 0,
        'pendingInvoices': 0,
        'overdueInvoices': 0,
        'totalAmount': 0.0,
        'paidAmount': 0.0,
        'month': monthDate,
        'displayMonth': DateFormat('MMM yyyy').format(monthDate),
      };
    }

    // Process timeline events
    Set<String> processedInvoiceIds = {}; // Prevent double counting

    for (var event in widget.timeline) {
      try {
        String eventType = event['type']?.toString() ?? '';
        String eventId =
            event['id']?.toString() ??
                event['number']?.toString() ??
                event['invoice_number']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString();

        DateTime eventDate;
        if (event['date'] != null) {
          eventDate = DateTime.parse(event['date'].toString());
        } else if (event['created_at'] != null) {
          eventDate = DateTime.parse(event['created_at'].toString());
        } else {
          continue;
        }

        String monthKey = DateFormat('yyyy-MM').format(eventDate);

        if (monthlyStats.containsKey(monthKey)) {

          double amount = 0.0;

          if (event['amount'] != null) {
            amount = double.tryParse(event['amount'].toString()) ?? 0;
          } else if (event['total'] != null) {
            amount = (event['total'] as num).toDouble();
          }

          String eventStatus = event['status']?.toString().toLowerCase() ?? '';

          switch (eventType) {

            case 'invoice_created':
              monthlyStats[monthKey]!['invoices'] =
                  (monthlyStats[monthKey]!['invoices'] as int) + 1;

              monthlyStats[monthKey]!['totalAmount'] =
                  (monthlyStats[monthKey]!['totalAmount'] as double) + amount;

              if (eventStatus == 'pending') {
                monthlyStats[monthKey]!['pendingInvoices'] =
                    (monthlyStats[monthKey]!['pendingInvoices'] as int) + 1;
              }
              break;

            case 'invoice_paid':
              monthlyStats[monthKey]!['paidInvoices'] =
                  (monthlyStats[monthKey]!['paidInvoices'] as int) + 1;

              monthlyStats[monthKey]!['paidAmount'] =
                  (monthlyStats[monthKey]!['paidAmount'] as double) + amount;

              monthlyStats[monthKey]!['revenue'] =
                  (monthlyStats[monthKey]!['revenue'] as double) + amount;
              break;

            case 'invoice_overdue':
              monthlyStats[monthKey]!['overdueInvoices'] =
                  (monthlyStats[monthKey]!['overdueInvoices'] as int) + 1;
              break;
          }
        }
      } catch (e) {
        debugPrint('Error processing event: $e');
        continue;
      }
    }

    // Filter and sort data based on selected range
    List<Map<String, dynamic>> chartData = [];
    List<String> sortedMonths = monthlyStats.keys.toList()..sort();

    for (var monthKey in sortedMonths) {
      var monthData = monthlyStats[monthKey]!;
      DateTime monthDate = monthData['month'];

      if (monthDate.isAfter(startDate) ||
          (monthDate.year == startDate.year && monthDate.month == startDate.month)) {
        chartData.add({
          'month': monthData['displayMonth'],
          'monthKey': monthKey,
          'revenue': monthData['revenue'],
          'invoices': monthData['invoices'],
          'paidInvoices': monthData['paidInvoices'],
          'pendingInvoices': monthData['pendingInvoices'],
          'overdueInvoices': monthData['overdueInvoices'],
          'totalAmount': monthData['totalAmount'],
          'paidAmount': monthData['paidAmount'],
          'date': monthDate,
        });
      }
    }

    // Calculate growth metrics
    double totalRevenue = 0;
    double previousTotalRevenue = 0;
    int midPoint = chartData.length ~/ 2;

    for (int i = 0; i < chartData.length; i++) {
      if (i < midPoint) {
        previousTotalRevenue += chartData[i]['revenue'];
      } else {
        totalRevenue += chartData[i]['revenue'];
      }
    }

    double growthPercentage = previousTotalRevenue > 0
        ? ((totalRevenue - previousTotalRevenue) / previousTotalRevenue) * 100
        : 0;

    // Calculate invoice metrics
    int totalInvoices = 0;
    int paidInvoices = 0;
    int pendingInvoices = 0;
    int overdueInvoices = 0;

    for (var data in chartData) {
      totalInvoices += data['invoices'] as int;
      paidInvoices += data['paidInvoices'] as int;
      pendingInvoices += data['pendingInvoices'] as int;
      overdueInvoices += data['overdueInvoices'] as int;
    }

    return {
      'data': chartData,
      'growth': growthPercentage,
      'totalRevenue': totalRevenue,
      'previousRevenue': previousTotalRevenue,
      'totalInvoices': totalInvoices,
      'paidInvoices': paidInvoices,
      'pendingInvoices': pendingInvoices,
      'overdueInvoices': overdueInvoices,
      'averageInvoiceValue': totalInvoices > 0 ? totalRevenue / totalInvoices : 0,
      'paymentRate': totalInvoices > 0 ? (paidInvoices / totalInvoices) * 100 : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    // Calculate client totals from actual data
    double calculatedTotalAmount = 0;
    int calculatedTotalInvoices = 0;

    for (var event in widget.timeline) {
      if (event['type'] == 'invoice_created') {
        calculatedTotalInvoices++;
        if (event['amount'] != null) {
          calculatedTotalAmount +=
              double.tryParse(event['amount'].toString()) ?? 0;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(currencyFormat, calculatedTotalInvoices, calculatedTotalAmount),
          if (widget.timeline.isEmpty)
            _buildEmptyState()
          else
            _buildContent(currencyFormat),
        ],
      ),
    );
  }

  Widget _buildHeader(NumberFormat currencyFormat, int calculatedInvoices, double calculatedAmount) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF5B8CFF).withOpacity(0.2),
                  const Color(0xFF5B8CFF).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text('📊', style: TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.client.name}\'s Journey',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$calculatedInvoices invoices • ${currencyFormat.format(calculatedAmount)} total',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.timeline_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'No journey events yet',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(NumberFormat currencyFormat) {
    return Column(
      children: [
        _buildDateRangeSelector(),
        _buildSummaryCards(currencyFormat),
        _buildMonthlyRevenueChart(currencyFormat),
        _buildPerformanceTrend(currencyFormat),
        _buildInvoiceChart(currencyFormat),
        _buildTimelineList(currencyFormat),
      ],
    );
  }

  Widget _buildSummaryCards(NumberFormat currencyFormat) {
    Map<String, dynamic> monthlyData = _cachedMonthlyData;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'Invoices',
              '${monthlyData['totalInvoices'] ?? 0}',
              Icons.receipt_outlined,
              const Color(0xFF5B8CFF),
            ),
          ),
          Expanded(
            child: _buildSummaryCard(
              'Paid',
              '${monthlyData['paidInvoices'] ?? 0}',
              Icons.check_circle_outlined,
              const Color(0xFF22C55E),
            ),
          ),
          Expanded(
            child: _buildSummaryCard(
              'Pending',
              '${monthlyData['pendingInvoices'] ?? 0}',
              Icons.pending_outlined,
              const Color(0xFFF59E0B),
            ),
          ),
          Expanded(
            child: _buildSummaryCard(
              'Overdue',
              '${monthlyData['overdueInvoices'] ?? 0}',
              Icons.warning_amber_outlined,
              const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          const Text(
            'Time Range:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _dateRanges.map((range) {
                  bool isSelected = _selectedRange == range;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRange = range;
                        _processMonthlyData();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF5B8CFF)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        range,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyRevenueChart(NumberFormat currencyFormat) {
    Map<String, dynamic> monthlyData = _cachedMonthlyData;
    List<Map<String, dynamic>> chartData = monthlyData['data'] ?? [];

    if (chartData.isEmpty) return const SizedBox.shrink();

    double maxRevenue = chartData
        .map((e) => (e['revenue'] as num).toDouble())
        .fold(0.0, (max, value) => value > max ? value : max);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly Revenue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Payment received per month',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Received: \n${currencyFormat.format(monthlyData['totalRevenue'] ?? 0)}',
                      style: const TextStyle(
                        color: Color(0xFF22C55E),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: chartData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final revenue = (data['revenue'] as num).toDouble();
                final double height = maxRevenue > 0 ? (revenue / maxRevenue) * 160.0 : 0.0;

                return Expanded(
                  child: Tooltip(
                    message: '${data['month']}: ${currencyFormat.format(revenue)}',
                    child: Container(
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: 4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  const Color(0xFF22C55E),
                                  const Color(0xFF16A34A),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['month'].toString().split(' ')[0],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '${(revenue / 1000).toStringAsFixed(1)}k',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrend(NumberFormat currencyFormat) {
    Map<String, dynamic> monthlyData = _cachedMonthlyData;
    double growth = monthlyData['growth'] ?? 0;
    double totalRevenue = monthlyData['totalRevenue'] ?? 0;
    double previousRevenue = monthlyData['previousRevenue'] ?? 0;
    double paymentRate = monthlyData['paymentRate'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revenue',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(totalRevenue),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Growth',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            growth >= 0 ? Icons.trending_up : Icons.trending_down,
                            color: growth >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${growth.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: growth >= 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
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
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Payment Rate',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${paymentRate.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Avg. Invoice',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currencyFormat.format(monthlyData['averageInvoiceValue'] ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceChart(NumberFormat currencyFormat) {
    final invoiceEvents = widget.timeline.where((e) =>
    e['type'] == 'invoice_created' || e['type'] == 'invoice_paid'
    ).toList();

    if (invoiceEvents.isEmpty) return const SizedBox.shrink();

    double maxAmount = invoiceEvents
        .map((e) {
      if (e['amount'] != null) return (e['amount'] as num).toDouble();
      if (e['total'] != null) return (e['total'] as num).toDouble();
      return 0.0;
    })
        .fold(0.0, (max, value) => value > max ? value : max);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invoice History',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: invoiceEvents.asMap().entries.map((entry) {
                final index = entry.key;
                final event = entry.value;

                double amount = 0;
                if (event['amount'] != null) {
                  amount = double.tryParse(event['amount'].toString()) ?? 0;
                } else if (event['total'] != null) {
                  amount = (event['total'] as num).toDouble();
                }

                final double height = maxAmount > 0 ? (amount / maxAmount) * 160.0 : 0.0;
                final isPaid = event['type'] == 'invoice_paid';
                final invoiceNumber = event['number'] ?? event['invoice_number'] ?? '#';

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _showInvoiceDetails(context, event, currencyFormat),
                    child: Container(
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: 4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: height,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isPaid
                                    ? [const Color(0xFF22C55E), const Color(0xFF16A34A)]
                                    : [const Color(0xFF5B8CFF), const Color(0xFF3B82F6)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            invoiceNumber.toString().split('-').last,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '${(amount / 1000).toStringAsFixed(1)}k',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineList(NumberFormat currencyFormat) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      itemCount: widget.timeline.length,
      itemBuilder: (context, index) {
        final event = widget.timeline[index];
        final isLast = index == widget.timeline.length - 1;
        return _buildTimelineEvent(context, event, isLast, currencyFormat);
      },
    );
  }

  Widget _buildTimelineEvent(
      BuildContext context,
      Map<String, dynamic> event,
      bool isLast,
      NumberFormat currencyFormat,
      ) {
    final type = event['type']?.toString() ?? 'invoice';

    DateTime date;
    try {
      date = event['date'] != null
          ? DateTime.parse(event['date'].toString())
          : event['created_at'] != null
          ? DateTime.parse(event['created_at'].toString())
          : DateTime.now();
    } catch (e) {
      date = DateTime.now();
    }

    double amount = 0;
    if (event['amount'] != null) {
      amount = (event['amount'] as num).toDouble();
    } else if (event['total'] != null) {
      amount = (event['total'] as num).toDouble();
    }

    final status = event['status']?.toString().toLowerCase() ?? '';
    final invoiceNumber = event['number'] ?? event['invoice_number'] ?? '';

    IconData icon;
    Color color;
    String title;

    switch (type) {
      case 'invoice_created':
        icon = Icons.description_outlined;
        color = const Color(0xFF5B8CFF);
        title = 'Invoice Created';
        break;

      case 'invoice_paid':
        icon = Icons.check_circle_outlined;
        color = const Color(0xFF22C55E);
        title = 'Payment Received';
        break;

      case 'invoice_overdue':
        icon = Icons.warning_amber_outlined;
        color = const Color(0xFFEF4444);
        title = 'Invoice Overdue';
        break;

      case 'client_created':
        icon = Icons.person_add_outlined;
        color = const Color(0xFF8B5CF6);
        title = 'Client Added';
        break;

      default:
        icon = Icons.event_outlined;
        color = Colors.white54;
        title = 'Event';
    }

    return GestureDetector(
      onTap: () {
        if (type == 'invoice_created' || type == 'invoice_paid') {
          try {
            final invoice = widget.client.invoices.firstWhere(
                  (inv) =>
              inv['id'] == invoiceNumber ||
                  inv['number'] == invoiceNumber ||
                  inv['id'] == event['id'],
              orElse: () => {},
            );

            if (invoice.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailScreen(invoice: invoice),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error navigating to invoice: $e');
          }
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 60,
                    color: Colors.white.withOpacity(0.1),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, size: 16, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d, yyyy • h:mm a').format(date),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (amount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'paid'
                                ? const Color(0xFF22C55E).withOpacity(0.15)
                                : status == 'overdue'
                                ? const Color(0xFFEF4444).withOpacity(0.15)
                                : color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            currencyFormat.format(amount),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: status == 'paid'
                                  ? const Color(0xFF22C55E)
                                  : status == 'overdue'
                                  ? const Color(0xFFEF4444)
                                  : color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (invoiceNumber.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Invoice #$invoiceNumber',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                          size: 16,
                        )
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceDetails(BuildContext context, Map<String, dynamic> event, NumberFormat currencyFormat) {
    double amount = 0;
    if (event['amount'] != null) {
      amount = double.tryParse(event['amount'].toString()) ?? 0;
    } else if (event['total'] != null) {
      amount = (event['total'] as num).toDouble();
    }

    String status = event['status']?.toString().toLowerCase() ?? 'draft';
    String invoiceNumber = event['number'] ?? event['invoice_number'] ?? '#';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B8CFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.receipt_long, color: Color(0xFF5B8CFF), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invoice #$invoiceNumber',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMMM d, yyyy').format(
                              DateTime.parse(event['date'] ?? event['created_at'] ?? DateTime.now().toString())
                          ),
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            currencyFormat.format(amount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Amount',
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: status == 'paid'
                                  ? const Color(0xFF22C55E).withOpacity(0.15)
                                  : status == 'overdue'
                                  ? const Color(0xFFEF4444).withOpacity(0.15)
                                  : const Color(0xFFF59E0B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: status == 'paid'
                                    ? const Color(0xFF22C55E)
                                    : status == 'overdue'
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFFF59E0B),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Status',
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B8CFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}