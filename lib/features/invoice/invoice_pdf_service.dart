import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class InvoicePdfService {

  static Future<void> viewInvoice(Map<String, dynamic> invoice) async {
    final pdf = await generate(invoice);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<pw.Document> generate(Map<String, dynamic> invoice) async {

    final pdf = pw.Document();

    final items = invoice['items'] as List? ?? [];
    final subtotal = (invoice['subtotal'] as num?)?.toDouble() ?? 0;
    final tax = (invoice['tax'] as num?)?.toDouble() ?? 0;
    final total = (invoice['amount'] as num?)?.toDouble() ?? 0;

    String currency(double v) {
      return "INR ${v.toStringAsFixed(2)}";
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "INVOICE",
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Invoice: ${invoice['id']}"),
                        pw.Text("Date: ${DateFormat('d MMM yyyy').format(DateTime.parse(invoice['date_issued']))}"),
                        pw.Text("Due: ${DateFormat('d MMM yyyy').format(DateTime.parse(invoice['due_date']))}"),
                      ],
                    )
                  ],
                ),

                pw.SizedBox(height: 30),

                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [

                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("FROM", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 6),
                          pw.Text("Your Company Name"),
                          pw.Text("Address Line"),
                          pw.Text("Phone"),
                          pw.Text("Email"),
                        ],
                      ),
                    ),

                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("BILLED TO", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 6),
                          pw.Text(invoice['client_name'] ?? ""),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 30),

                pw.Table(
                  border: pw.TableBorder(
                    bottom: pw.BorderSide(color: PdfColors.grey300),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                  },
                  children: [

                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Description"),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Qty", textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Unit Cost", textAlign: pw.TextAlign.right),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text("Amount", textAlign: pw.TextAlign.right),
                        ),
                      ],
                    ),

                    ...items.map((item) {

                      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
                      final rate = (item['rate'] as num?)?.toDouble() ?? 0;
                      final amount = qty * rate;

                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(item['description'] ?? ""),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(qty.toString(), textAlign: pw.TextAlign.right),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(currency(rate), textAlign: pw.TextAlign.right),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(currency(amount), textAlign: pw.TextAlign.right),
                          ),
                        ],
                      );

                    }).toList()
                  ],
                ),

                pw.SizedBox(height: 25),

                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 220,
                    child: pw.Column(
                      children: [

                        pw.Row(
                          children: [
                            pw.Text("Subtotal"),
                            pw.Spacer(),
                            pw.Text(currency(subtotal)),
                          ],
                        ),

                        pw.SizedBox(height: 6),

                        pw.Row(
                          children: [
                            pw.Text("Tax"),
                            pw.Spacer(),
                            pw.Text(currency(tax)),
                          ],
                        ),

                        pw.Divider(),

                        pw.Row(
                          children: [
                            pw.Text(
                              "TOTAL",
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                            ),
                            pw.Spacer(),
                            pw.Text(
                              currency(total),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                pw.SizedBox(height: 30),

                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "BANK ACCOUNT DETAILS",
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text("Account Name: Your Name"),
                    pw.Text("Account Type: Current Account"),
                    pw.Text("Account Number: XXXXXXXX"),
                    pw.Text("Bank Name: Your Bank"),
                    pw.Text("IFSC Code: XXXXX"),
                  ],
                ),

                pw.Spacer(),

                pw.Center(
                  child: pw.Text(
                    "Thank you for your business!",
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );

    return pdf;
  }
}