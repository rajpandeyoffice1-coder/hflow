class InvoiceModel {
  String id;
  String invoiceNumber;
  DateTime issueDate;
  DateTime dueDate;
  String client;
  bool isPaid;
  double taxRate;
  double discount;
  List<InvoiceItem> items;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.client,
    required this.isPaid,
    required this.taxRate,
    required this.discount,
    required this.items,
  });

  double get subtotal =>
      items.fold(0, (sum, e) => sum + e.total);

  double get tax => subtotal * (taxRate / 100);

  double get total => subtotal + tax - discount;
}

class InvoiceItem {
  String description;
  int qty;
  double rate;

  InvoiceItem({
    required this.description,
    required this.qty,
    required this.rate,
  });

  double get total => qty * rate;
}