// lib/screens/investment/investment_detail_modal.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/investment_models.dart';

class InvestmentDetailModal extends StatelessWidget {
  final Investment investment;
  final VoidCallback onRedeem;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const InvestmentDetailModal({
    super.key,
    required this.investment,
    required this.onRedeem,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildInvestmentHeader(),
                  const SizedBox(height: 20),
                  _buildInfoGrid(),
                  const SizedBox(height: 20),
                  if (investment.redemptions.isNotEmpty) _buildRedemptionHistory(),
                ],
              ),
            ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Investment Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(DateTime.parse(investment.date)),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getCategoryColor().withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _getCategoryIcon(),
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                investment.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (investment.subCategory != null)
                Text(
                  investment.subCategory!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: investment.owner == 'Hari'
                ? const Color(0xFF5B8CFF).withOpacity(0.2)
                : const Color(0xFF10B981).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            investment.owner,
            style: TextStyle(
              color: investment.owner == 'Hari'
                  ? const Color(0xFF5B8CFF)
                  : const Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          _buildInfoRow('Amount', '₹${_formatNumber(investment.amount)}'),
          const SizedBox(height: 12),
          _buildInfoRow('Current Value', '₹${_formatNumber(investment.currentValue)}',
              valueColor: const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildInfoRow('Redeemed', '₹${_formatNumber(investment.redeemedAmount)}',
              valueColor: const Color(0xFFEF4444)),
          const SizedBox(height: 12),
          _buildInfoRow('Payment Method', investment.paymentMethod.isNotEmpty
              ? investment.paymentMethod
              : 'Not specified'),
          if (investment.comments.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Notes',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              investment.comments,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRedemptionHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Redemption History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...investment.redemptions.map((redemption) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${_formatNumber(redemption.amount)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(redemption.date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                      if (redemption.notes.isNotEmpty)
                        Text(
                          redemption.notes,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, color: Color(0xFF5B8CFF), size: 18),
              label: const Text(
                'Edit',
                style: TextStyle(color: Color(0xFF5B8CFF)),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFF5B8CFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onRedeem,
              icon: const Icon(Icons.logout, color: Colors.white, size: 18),
              label: const Text(
                'Redeem',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryIcon() {
    if (investment.category.contains('Mutual')) return '📈';
    if (investment.category.contains('Stock')) return '📊';
    if (investment.category.contains('FD') || investment.category.contains('Fixed')) return '🏦';
    if (investment.category.contains('PPF')) return '🇮🇳';
    if (investment.category.contains('Gold')) return '🥇';
    if (investment.category.contains('Real Estate')) return '🏠';
    if (investment.category.contains('SIP')) return '🔄';
    if (investment.category.contains('Chit')) return '🤝';
    if (investment.category.contains('Insurance')) return '🛡️';
    if (investment.category.contains('NPS')) return '👴';
    if (investment.category.contains('Crypto')) return '₿';
    if (investment.category.contains('RD')) return '📅';
    if (investment.category.contains('SGB')) return '📜';
    if (investment.category.contains('EPF')) return '🏢';
    return '💰';
  }

  Color _getCategoryColor() {
    if (investment.category.contains('Mutual')) return const Color(0xFF5B8CFF);
    if (investment.category.contains('Stock')) return const Color(0xFF10B981);
    if (investment.category.contains('FD') || investment.category.contains('Fixed')) return const Color(0xFFF97316);
    if (investment.category.contains('Gold')) return const Color(0xFFEAB308);
    if (investment.category.contains('Real Estate')) return const Color(0xFF9333EA);
    if (investment.category.contains('Crypto')) return const Color(0xFFEF4444);
    if (investment.category.contains('PPF') || investment.category.contains('EPF')) return const Color(0xFF8B5CF6);
    return const Color(0xFF64748B);
  }

  String _formatNumber(double number) {
    if (number >= 10000000) {
      return '${(number / 10000000).toStringAsFixed(2)}Cr';
    } else if (number >= 100000) {
      return '${(number / 100000).toStringAsFixed(2)}L';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toStringAsFixed(0);
  }
}