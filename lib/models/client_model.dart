// lib/models/client_model.dart
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
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int totalInvoices;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final double overdueAmount;
  final double avgInvoiceValue;
  final int paidInvoices;
  final int pendingInvoices;
  final int overdueInvoices;
  final DateTime? lastInvoiceDate;
  final DateTime? lastPaymentDate;
  final double lifetimeValue;
  final double paymentRate;
  final List<Map<String, dynamic>> invoices;

  String get displayId => id != null && id!.length >= 8 
      ? id!.substring(0, 8).toUpperCase() 
      : id?.toUpperCase() ?? '';
  
  String get initials => name.isNotEmpty 
      ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
      : '??';
  
  bool get isVip => totalAmount >= 150000;
  bool get isDormant => lastInvoiceDate != null 
      ? DateTime.now().difference(lastInvoiceDate!).inDays > 90
      : true;
  bool get hasOverdue => overdueAmount > 0;
  
  String get clientType {
    if (isVip && isDormant) return 'Dormant VIP';
    if (isVip) return 'VIP';
    if (isDormant) return 'Dormant';
    if (hasOverdue) return 'Overdue';
    return 'Regular';
  }
  
  String get formattedLastInvoice {
    if (lastInvoiceDate == null) return 'No invoices';
    final days = DateTime.now().difference(lastInvoiceDate!).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 30) return '$days days ago';
    if (days < 365) return '${(days / 30).floor()} months ago';
    return '${(days / 365).floor()} years ago';
  }
  
  double get collectionRate => totalAmount > 0 
      ? (paidAmount / totalAmount * 100) 
      : 0;

  ClientModel({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.contactName,
    this.company,
    this.address,
    this.paymentTerms = 'net_30_days',
    this.status = 'Active',
    this.createdAt,
    this.updatedAt,
    this.totalInvoices = 0,
    this.totalAmount = 0.0,
    this.paidAmount = 0.0,
    this.pendingAmount = 0.0,
    this.overdueAmount = 0.0,
    this.avgInvoiceValue = 0.0,
    this.paidInvoices = 0,
    this.pendingInvoices = 0,
    this.overdueInvoices = 0,
    this.lastInvoiceDate,
    this.lastPaymentDate,
    this.lifetimeValue = 0.0,
    this.paymentRate = 0.0,
    this.invoices = const [],
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> invoices = [];
    double totalAmount = 0;
    double paidAmount = 0;
    double pendingAmount = 0;
    double overdueAmount = 0;
    int paidInvoices = 0;
    int pendingInvoices = 0;
    int overdueInvoices = 0;
    DateTime? lastInvoiceDate;
    DateTime? lastPaymentDate;
    
    if (json['invoices'] != null && json['invoices'] is List) {
      invoices = List<Map<String, dynamic>>.from(json['invoices']);
      
      for (var invoice in invoices) {
        double amount = (invoice['amount'] as num?)?.toDouble() ?? 0;
        totalAmount += amount;
        
        String status = invoice['status']?.toString().toLowerCase() ?? '';
        DateTime? invoiceDate;
        
        if (invoice['date_issued'] != null) {
          try {
            invoiceDate = DateTime.parse(invoice['date_issued'].toString());
            if (lastInvoiceDate == null || 
                (invoiceDate.isAfter(lastInvoiceDate))) {
              lastInvoiceDate = invoiceDate;
            }
          } catch (e) {}
        }
        
        if (status == 'paid') {
          paidAmount += amount;
          paidInvoices++;
          if (invoiceDate != null && 
              (lastPaymentDate == null || invoiceDate.isAfter(lastPaymentDate))) {
            lastPaymentDate = invoiceDate;
          }
        } else if (status == 'pending') {
          pendingAmount += amount;
          pendingInvoices++;
        } else if (status == 'overdue') {
          overdueAmount += amount;
          overdueInvoices++;
        }
      }
    }
    
    return ClientModel(
      id: json['id']?.toString(),
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      contactName: json['contact_name']?.toString(),
      company: json['company']?.toString(),
      address: json['address']?.toString(),
      paymentTerms: json['payment_terms']?.toString() ?? 'net_30_days',
      status: json['status']?.toString() ?? 'Active',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      totalInvoices: json['total_invoices'] ?? invoices.length,
      totalAmount: json['total_amount'] != null 
          ? (json['total_amount'] as num).toDouble() 
          : totalAmount,
      paidAmount: paidAmount,
      pendingAmount: pendingAmount,
      overdueAmount: overdueAmount,
      avgInvoiceValue: invoices.isNotEmpty ? totalAmount / invoices.length : 0,
      paidInvoices: paidInvoices,
      pendingInvoices: pendingInvoices,
      overdueInvoices: overdueInvoices,
      lastInvoiceDate: lastInvoiceDate,
      lastPaymentDate: lastPaymentDate,
      lifetimeValue: totalAmount,
      paymentRate: totalAmount > 0 ? (paidAmount / totalAmount * 100) : 0,
      invoices: invoices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'contact_name': contactName,
      'company': company,
      'address': address,
      'payment_terms': paymentTerms,
      'status': status,
    };
  }
}