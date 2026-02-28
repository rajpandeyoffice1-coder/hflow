// lib/widgets/client_journey_widget.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/client_model.dart';

class ClientJourneyWidget extends StatelessWidget {
  final ClientModel client;
  final List<Map<String, dynamic>> timeline;

  const ClientJourneyWidget({
    Key? key,
    required this.client,
    required this.timeline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                        '${client.name}\'s Journey',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${client.totalInvoices} invoices • ${currencyFormat.format(client.totalAmount)} total',
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
          ),
          
          if (timeline.isEmpty)
            const Padding(
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
            )
          else
            Column(
              children: [
                _buildChart(context, timeline, currencyFormat),
                _buildTimelineList(timeline, currencyFormat),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, List<Map<String, dynamic>> timeline, NumberFormat currencyFormat) {
    final invoiceEvents = timeline.where((e) => 
      e['type'] == 'invoice_created' || e['type'] == 'invoice_paid'
    ).toList();
    
    if (invoiceEvents.isEmpty) return const SizedBox.shrink();
    
    double maxAmount = invoiceEvents.map((e) => (e['amount'] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b);
    
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
                final amount = (event['amount'] as num?)?.toDouble() ?? 0;
                final height = maxAmount > 0 ? (amount / maxAmount) * 160 : 0;
                final isPaid = event['type'] == 'invoice_paid';
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _showInvoiceDetails(context, event, currencyFormat);
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: 4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: height as double,
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
                            event['number']?.toString().split('-').last ?? '#',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            currencyFormat.format(amount).replaceAll('₹', '') + 'k',
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

  Widget _buildTimelineList(List<Map<String, dynamic>> timeline, NumberFormat currencyFormat) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final event = timeline[index];
        final isLast = index == timeline.length - 1;
        return _buildTimelineEvent(event, isLast, currencyFormat);
      },
    );
  }

  Widget _buildTimelineEvent(
    Map<String, dynamic> event,
    bool isLast,
    NumberFormat currencyFormat,
  ) {
    final type = event['type']?.toString() ?? 'invoice';
    final date = event['date'] != null 
        ? DateTime.parse(event['date'].toString())
        : DateTime.now();
    final amount = (event['amount'] as num?)?.toDouble() ?? 0;
    final status = event['status']?.toString().toLowerCase() ?? '';
    
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
    
    return Row(
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
                if (event['number'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Invoice #${event['number']}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showInvoiceDetails(BuildContext context, Map<String, dynamic> event, NumberFormat currencyFormat) {
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
                          'Invoice #${event['number']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMMM d, yyyy').format(DateTime.parse(event['date'])),
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
                            currencyFormat.format(event['amount']),
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
                              color: event['status'] == 'paid'
                                  ? const Color(0xFF22C55E).withOpacity(0.15)
                                  : event['status'] == 'overdue'
                                      ? const Color(0xFFEF4444).withOpacity(0.15)
                                      : const Color(0xFFF59E0B).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              event['status']?.toString().toUpperCase() ?? 'DRAFT',
                              style: TextStyle(
                                color: event['status'] == 'paid'
                                    ? const Color(0xFF22C55E)
                                    : event['status'] == 'overdue'
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