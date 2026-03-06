import 'package:intl/intl.dart';

class ClientModel {
  final String? id;
  final String name;
  final String email;
  final String? phone;
  final String? contactName;
  final String? company;
  final String? address;
  final String paymentTerms;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int totalInvoices;
  final double totalAmount;
  final List<Map<String, dynamic>> invoices;

  ClientModel({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.contactName,
    this.company,
    this.address,
    this.paymentTerms = 'net30',
    this.createdAt,
    this.updatedAt,
    this.totalInvoices = 0,
    this.totalAmount = 0,
    this.invoices = const [],
  });

  String get initials => name.trim().isEmpty
      ? '??'
      : name.trim().split(' ').map((s) => s[0]).take(2).join().toUpperCase();

  DateTime? get lastInvoiceDate {
    DateTime? latest;
    for (final invoice in invoices) {
      final rawDate = invoice['date_issued'] ?? invoice['created_at'] ?? invoice['date'];
      final parsed = rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;
      if (parsed != null && (latest == null || parsed.isAfter(latest))) {
        latest = parsed;
      }
    }
    return latest;
  }

  bool get isVip => totalAmount > 500000;
  bool get isGold => totalAmount > 100000;
  bool get isNew => createdAt != null && DateTime.now().difference(createdAt!).inDays <= 30;
  bool get isActive => lastInvoiceDate != null && DateTime.now().difference(lastInvoiceDate!).inDays <= 90;

  String get statusLabel {
    if (isVip) return 'VIP Client';
    if (isGold) return 'Gold Client';
    if (isNew) return 'New';
    return isActive ? 'Active' : 'Inactive';
  }

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    final parsedInvoices = (json['invoices'] is List)
        ? List<Map<String, dynamic>>.from(json['invoices'])
        : <Map<String, dynamic>>[];

    final computedAmount = parsedInvoices.fold<double>(
      0,
      (sum, invoice) => sum + ((invoice['amount'] as num?)?.toDouble() ?? 0),
    );

    return ClientModel(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      contactName: json['contact_name']?.toString(),
      company: json['company']?.toString(),
      address: json['address']?.toString(),
      paymentTerms: json['payment_terms']?.toString() ?? 'net30',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      totalInvoices: json['total_invoices'] is num ? (json['total_invoices'] as num).toInt() : parsedInvoices.length,
      totalAmount: json['total_amount'] != null ? (json['total_amount'] as num).toDouble() : computedAmount,
      invoices: parsedInvoices,
    );
  }

  String get formattedRevenue => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(totalAmount);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'payment_terms': paymentTerms,
      'contact_name': contactName,
      'company': company,
      'total_invoices': totalInvoices,
      'total_amount': totalAmount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
