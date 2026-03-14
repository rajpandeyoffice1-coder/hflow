// lib/features/invoice/models/invoice_model.dart
import 'package:intl/intl.dart';

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final String clientId;
  final String clientName;
  final String status;
  final double taxRate;
  final double discount;
  final List<InvoiceItem> items;
  final String notes;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.clientId,
    required this.clientName,
    required this.status,
    required this.taxRate,
    required this.discount,
    required this.items,
    this.notes = '',
  });

  double get subtotal =>
      items.fold(0.0, (sum, e) => sum + e.total);

  double get tax => subtotal * (taxRate / 100);

  double get total => subtotal + tax - discount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'client_id': clientId,
      'client_name': clientName,
      'amount': total,
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'tax_rate': taxRate,
      'date_issued': DateFormat('yyyy-MM-dd').format(issueDate),
      'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
      'status': status,
      'items': items.map((item) => item.toJson()).toList(),
      'notes': notes,
    };
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] ?? '',
      invoiceNumber: json['invoice_number'] ?? json['id'] ?? '',
      issueDate: DateTime.parse(json['date_issued'] ?? json['issue_date'] ?? DateTime.now().toIso8601String()),
      dueDate: DateTime.parse(json['due_date'] ?? DateTime.now().add(const Duration(days: 30)).toIso8601String()),
      clientId: json['client_id']?.toString() ?? '',
      clientName: json['client_name']?.toString() ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'DRAFT',
      taxRate: (json['tax_rate'] ?? 18.0).toDouble(),
      discount: (json['discount'] ?? 0.0).toDouble(),
      items: (json['items'] as List?)?.map((item) => InvoiceItem.fromJson(item)).toList() ?? [],
      notes: json['notes']?.toString() ?? '',
    );
  }
}

class InvoiceItem {
  String description;
  int quantity;
  double rate;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.rate,
  });

  double get total => quantity * rate;

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'quantity': quantity,
      'rate': rate,
    };
  }

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      description: json['description']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}