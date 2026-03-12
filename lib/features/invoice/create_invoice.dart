import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hflow/features/invoice/InvoiceSupabaseService.dart';

class CreateInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic>? invoiceToEdit;
  const CreateInvoiceScreen({super.key, this.invoiceToEdit});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  static const double _headerHeight = 56;

  String invoiceNumber = '';
  late DateTime issueDate;
  late DateTime dueDate;
  String invoiceStatus = 'DRAFT';

  String selectedClientId = '';
  String selectedClientName = '';
  double taxRate = 18.0;
  double discount = 0.0;
  bool discountIsPercent = false;

  List<Map<String, dynamic>> clients = [];
  bool _isLoadingClients = false;
  bool _isSaving = false;

  final List<Map<String, dynamic>> items = [];

  final TextEditingController notesController = TextEditingController();
  final SupabaseService _supabase = SupabaseService();

  // Focus nodes for better UX
  final FocusNode _descriptionFocusNode = FocusNode();
  final FocusNode _quantityFocusNode = FocusNode();
  final FocusNode _rateFocusNode = FocusNode();
  final TextEditingController gstController = TextEditingController(text: "18");
  final TextEditingController discountController = TextEditingController();

  // Calculate subtotal from items
  double get subtotal {
    if (items.isEmpty) return 0.0;
    return items.fold(0.0, (sum, item) {
      final quantity = (item['quantity'] as int?) ?? 0;
      final rate = (item['rate'] as double?) ?? 0.0;
      return sum + (quantity * rate);
    });
  }

  // Calculate tax amount
  double get taxAmount => subtotal * (taxRate / 100);

  // Calculate discount value
  double get discountValue {
    if (discountIsPercent) {
      return subtotal * (discount / 100);
    }
    return discount;
  }

  // Calculate total
  double get total => subtotal + taxAmount - discountValue;

  @override
  void initState() {
    super.initState();
    issueDate = DateTime.now();
    dueDate = issueDate;
    _loadClients();
    discountController.text = discount.toString();

    if (widget.invoiceToEdit != null) {
      _loadInvoiceForEdit();
    } else {
      _loadInvoiceNumber();
    }
  }

  Future<void> _loadInvoiceNumber() async {
    final value = await _generateInvoiceNumber();
    if (mounted) {
      setState(() {
        invoiceNumber = value;
      });
    }
  }

  @override
  void dispose() {
    notesController.dispose();
    gstController.dispose();
    discountController.dispose();
    _descriptionFocusNode.dispose();
    _quantityFocusNode.dispose();
    _rateFocusNode.dispose();
    super.dispose();
  }

  void _loadInvoiceForEdit() {
    final invoice = widget.invoiceToEdit!;
    invoiceNumber = invoice['id'] ?? '';
    issueDate = DateTime.parse(invoice['date_issued']);
    dueDate = DateTime.parse(invoice['due_date']);
    invoiceStatus = invoice['status']?.toString().toUpperCase() ?? 'DRAFT';
    selectedClientId = invoice['client_id']?.toString() ?? '';
    selectedClientName = invoice['client_name']?.toString() ?? '';
    taxRate = _toDouble(invoice['tax']) ?? 18.0;
    discount = 0.0;
    discountController.text = discount.toString();
    gstController.text = taxRate.toString();

    items.clear();
    if (invoice['items'] != null && invoice['items'] is List) {
      final invoiceItems = invoice['items'] as List;
      items.addAll(invoiceItems.map((item) {
        return {
          'description': item['description']?.toString() ?? 'New Item',
          'quantity': _toInt(item['quantity']) ?? 1,
          'rate': _toDouble(item['rate']) ?? 0.0,
        };
      }).toList());
    }

    notesController.text = invoice['notes']?.toString() ?? '';
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<void> _loadClients() async {
    setState(() => _isLoadingClients = true);
    try {
      final data = await _supabase.getClients();
      if (mounted) {
        setState(() {
          clients = List<Map<String, dynamic>>.from(data);
          _isLoadingClients = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClients = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading clients: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String> _generateInvoiceNumber() async {
    final year = DateTime.now().year;
    final invoices = await _supabase.getInvoices();

    int maxNumber = 0;

    for (var inv in invoices) {
      final id = inv['id']?.toString() ?? '';
      if (id.startsWith("INV-$year-")) {
        final parts = id.split('-');
        if (parts.length == 3) {
          final number = int.tryParse(parts[2]) ?? 0;
          if (number > maxNumber) {
            maxNumber = number;
          }
        }
      }
    }

    final nextNumber = maxNumber + 1;
    return "INV-$year-${nextNumber.toString().padLeft(4, '0')}";
  }

  String get formattedIssueDate {
    return DateFormat('dd MMM yyyy').format(issueDate);
  }

  String get formattedDueDate {
    return DateFormat('dd MMM yyyy').format(dueDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05060A),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B0F1A), Color(0xFF05060A)],
              ),
            ),
          ),

          // Decorative blobs
          Positioned(
            top: -120,
            left: -100,
            child: _liquidBlob(
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
              width: 380,
              height: 460,
              color: const Color(0xFF3B82F6),
              opacity: 0.26,
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isSaving
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF5B8CFF),
                    ),
                  )
                      : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        _buildTitle(),
                        const SizedBox(height: 16),
                        _buildInvoiceDetails(),
                        const SizedBox(height: 20),
                        _buildClientInformation(),
                        const SizedBox(height: 20),
                        _buildLineItems(),
                        const SizedBox(height: 20),
                        _buildAdditionalInfo(),
                        const SizedBox(height: 20),
                        _buildInvoiceSummary(),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
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
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.12),
          ),
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
              if (_isSaving) return;
              Navigator.of(context).maybePop();
            },
          ),
          Expanded(
            child: Text(
              widget.invoiceToEdit != null ? "Edit Invoice" : "Create New Invoice",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF5B8CFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF5B8CFF).withOpacity(0.3),
                ),
              ),
              child: Text(
                widget.invoiceToEdit != null ? "EDIT" : "NEW",
                style: const TextStyle(
                  color: Color(0xFF5B8CFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.invoiceToEdit != null ? "Edit Invoice" : "Create New Invoice",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Fill in the details to generate a professional invoice",
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceDetails() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.description_outlined,
            title: "Invoice Details",
          ),
          const SizedBox(height: 16),

          // Invoice Number (Read-only)
          _buildLabel(
            label: "INVOICE NUMBER",
            isRequired: false,
            badge: "Auto-generated",
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  "# ",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                Expanded(
                  child: Text(
                    invoiceNumber.isEmpty ? "Generating..." : invoiceNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Issue Date and Due Date
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  label: "ISSUE DATE",
                  date: formattedIssueDate,
                  onTap: _selectIssueDate,
                  isRequired: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  label: "DUE DATE",
                  date: formattedDueDate,
                  onTap: _selectDueDate,
                  isRequired: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDueDateQuickButtons(),
        ],
      ),
    );
  }

  Widget _buildDueDateQuickButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _dueBadge("7 Days", () {
            setState(() {
              dueDate = issueDate.add(const Duration(days: 7));
            });
          }),
          _dueBadge("15 Days", () {
            setState(() {
              dueDate = issueDate.add(const Duration(days: 15));
            });
          }),
          _dueBadge("30 Days", () {
            setState(() {
              dueDate = issueDate.add(const Duration(days: 30));
            });
          }),
          _dueBadge("3 Months", () {
            setState(() {
              dueDate = DateTime(
                issueDate.year,
                issueDate.month + 3,
                issueDate.day,
              );
            });
          }),
          _dueBadge("Custom", () {
            _selectDueDate();
          }),
        ],
      ),
    );
  }

  Widget _dueBadge(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF5B8CFF).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF5B8CFF).withOpacity(0.35),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5B8CFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientInformation() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.people_outline,
            title: "Client Information",
          ),
          const SizedBox(height: 16),

          // Client Selection
          _buildLabel(label: "SELECT CLIENT", isRequired: true),
          const SizedBox(height: 4),
          InkWell(
            onTap: _showClientSelectionDialog,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selectedClientId.isNotEmpty
                      ? const Color(0xFF5B8CFF).withOpacity(0.3)
                      : Colors.white.withOpacity(0.10),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: selectedClientId.isNotEmpty
                        ? const Color(0xFF5B8CFF)
                        : Colors.white.withOpacity(0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedClientId.isNotEmpty ? selectedClientName : "Select Client",
                      style: TextStyle(
                        color: selectedClientId.isNotEmpty ? Colors.white : Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: selectedClientId.isNotEmpty
                        ? const Color(0xFF5B8CFF)
                        : Colors.white.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItems() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                icon: Icons.receipt_outlined,
                title: "Line Items",
              ),
              _buildAddItemButton(),
            ],
          ),
          const SizedBox(height: 18),

          // Items List
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 48,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "No items added yet",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAddItemButton(isFullWidth: false),
                ],
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> item = entry.value;
              double itemTotal = (item['quantity'] ?? 0) * (item['rate'] ?? 0.0);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Column(
                  children: [
                    // Description Field
                    _buildItemDescriptionField(index, item),
                    const SizedBox(height: 12),

                    // Quantity, Rate, Total Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildItemQuantityField(index, item),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: _buildItemRateField(index, item),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: _buildItemTotalDisplay(itemTotal),
                        ),
                        const SizedBox(width: 4),
                        _buildItemDeleteButton(index),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfo() {
    return _buildGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.note_outlined,
            title: "Additional Information",
          ),
          const SizedBox(height: 12),

          // Notes Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            child: TextField(
              controller: notesController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Add any additional notes, terms, or payment instructions...",
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceSummary() {
    return _buildGlassCard(
      child: Column(
        children: [
          // Subtotal
          _buildSummaryRow(
            label: "Subtotal",
            value: "₹${subtotal.toStringAsFixed(2)}",
          ),
          const SizedBox(height: 12),

          // GST Row
          _buildTaxRow(),
          const SizedBox(height: 12),

          // Discount Row
          _buildDiscountRow(),
          const SizedBox(height: 8),

          // Discount Type Toggle
          _buildDiscountToggle(),
          const SizedBox(height: 8),

          // Mark as Paid
          _buildMarkAsPaidToggle(),
          const SizedBox(height: 16),

          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),

          // Total Amount
          _buildTotalRow(),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF05060A).withOpacity(0.95),
            ],
          ),
        ),
        child: Row(
          children: [
            // Save as Draft Button
            Expanded(
              child: _buildGlassButton(
                onPressed: _isSaving ? null : _saveAsDraft,
                icon: Icons.save_outlined,
                label: "Save Draft",
                isDisabled: _isSaving,
              ),
            ),
            const SizedBox(width: 12),

            // Create/Update Invoice Button
            Expanded(
              child: _buildPrimaryButton(
                onPressed: _isSaving ? null : _saveInvoice,
                icon: widget.invoiceToEdit != null ? Icons.update : Icons.add,
                label: widget.invoiceToEdit != null ? "Update Invoice" : "Create Invoice",
                isDisabled: _isSaving,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== Helper Methods ==============

  void _showClientSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
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
                border: Border.all(
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          "Select Client",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isLoadingClients)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Color(0xFF5B8CFF)),
                    )
                  else if (clients.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        "No clients found. Add clients first.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: clients.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final client = clients[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  selectedClientId = client['id'].toString();
                                  selectedClientName = client['name']?.toString() ?? '';
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white.withOpacity(0.05),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.business_center,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            client['name']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            client['email']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                          ),
                          child: const Text("Cancel"),
                        ),
                      ],
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

  void _addItem() {
    setState(() {
      items.add({
        'description': '',
        'quantity': 1,
        'rate': 0.0,
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _descriptionFocusNode.requestFocus();
    });
  }

  void _removeItem(int index) {
    setState(() {
      items.removeAt(index);
    });
  }

  Future<void> _saveInvoice() async {
    if (selectedClientId.isEmpty) {
      _showErrorSnackBar('Please select a client');
      return;
    }

    if (items.isEmpty) {
      _showErrorSnackBar('Please add at least one item');
      return;
    }

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item['description'] == null || item['description'].toString().trim().isEmpty) {
        _showErrorSnackBar('Please enter description for item ${i + 1}');
        return;
      }
      if ((item['quantity'] as int?) == null || (item['quantity'] as int) <= 0) {
        _showErrorSnackBar('Please enter valid quantity for item ${i + 1}');
        return;
      }
      if ((item['rate'] as double?) == null || (item['rate'] as double) <= 0) {
        _showErrorSnackBar('Please enter valid rate for item ${i + 1}');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final invoiceData = <String, dynamic>{
        'id': invoiceNumber,
        'client_id': selectedClientId,
        'client_name': selectedClientName,
        'amount': total,
        'subtotal': subtotal,
        'tax': taxAmount,
        'discount': discountValue,
        'discount_type': discountIsPercent ? 'percentage' : 'fixed',
        'date_issued': DateFormat('yyyy-MM-dd').format(issueDate),
        'due_date': DateFormat('yyyy-MM-dd').format(dueDate),
        'status': invoiceStatus,
        'items': items.map((item) => {
          'description': item['description']?.toString().trim() ?? 'Item',
          'quantity': item['quantity'] as int? ?? 1,
          'rate': item['rate'] as double? ?? 0.0,
        }).toList(),
        'notes': notesController.text.trim(),
      };

      if (widget.invoiceToEdit != null) {
        await _supabase.updateInvoice(widget.invoiceToEdit!['id'].toString(), invoiceData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice updated successfully'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
        }
      } else {
        await _supabase.createInvoice(invoiceData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice created successfully'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error saving invoice: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveAsDraft() async {
    setState(() {
      invoiceStatus = 'DRAFT';
    });
    await _saveInvoice();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectIssueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: issueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5B8CFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != issueDate) {
      setState(() {
        issueDate = picked;

        // Automatically sync due date with issue date
        dueDate = picked;
      });
    }
  }

  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: issueDate,
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5B8CFF),
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != dueDate) {
      setState(() {
        dueDate = picked;
      });
    }
  }
  // ============== Helper Widgets ==============

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel({required String label, bool isRequired = false, String? badge}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        if (isRequired)
          const Text(
            " *",
            style: TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 11,
            ),
          ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required String date,
    required VoidCallback onTap,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label: label, isRequired: isRequired),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.5)),
                const SizedBox(width: 8),
                Text(
                  date,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassInput({
    required Widget child,
    double height = 44,
  }) {
    return Container(
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: child,
    );
  }

  Widget _buildAmountBadge(String value) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF5B8CFF).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF5B8CFF).withOpacity(0.35),
        ),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Color(0xFF5B8CFF),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildAddItemButton({bool isFullWidth = false}) {
    return InkWell(
      onTap: _addItem,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isFullWidth ? 16 : 12,
          vertical: 8,
        ),
        width: isFullWidth ? double.infinity : null,
        decoration: BoxDecoration(
          color: const Color(0xFF5B8CFF).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFF5B8CFF).withOpacity(0.35),
          ),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 16, color: Color(0xFF5B8CFF)),
            const SizedBox(width: 6),
            Text(
              isFullWidth ? "Add First Item" : "Add Item",
              style: const TextStyle(
                color: Color(0xFF5B8CFF),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDescriptionField(int index, Map<String, dynamic> item) {
    return _buildGlassInput(
      height: 46,
      child: TextFormField(
        initialValue: item['description'] ?? "",
        onChanged: (v) {
          setState(() {
            items[index]['description'] = v;
          });
        },
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: "Item description",
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildItemQuantityField(int index, Map<String, dynamic> item) {
    return _buildGlassInput(
      child: TextFormField(
        initialValue: (item['quantity'] ?? 1).toString(),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Qty",
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
        onChanged: (v) {
          setState(() {
            items[index]['quantity'] = int.tryParse(v) ?? 1;
          });
        },
      ),
    );
  }

  Widget _buildItemRateField(int index, Map<String, dynamic> item) {
    return _buildGlassInput(
      child: TextFormField(
        initialValue: (item['rate'] ?? 0).toString(),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Rate",
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 13,
          ),
        ),
        onChanged: (v) {
          setState(() {
            items[index]['rate'] = double.tryParse(v) ?? 0.0;
          });
        },
      ),
    );
  }

  Widget _buildItemTotalDisplay(double total) {
    return _buildAmountBadge("₹${total.toStringAsFixed(2)}");
  }

  Widget _buildItemDeleteButton(int index) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
      onPressed: () => _removeItem(index),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildSummaryRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 15,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            "GST",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildGlassInput(
            height: 40,
            child: TextFormField(
              controller: gstController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                suffixText: '%',
                suffixStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              onChanged: (v) {
                setState(() {
                  taxRate = double.tryParse(v) ?? 0.0;
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            "₹${taxAmount.toStringAsFixed(2)}",
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            discountIsPercent ? "Discount %" : "Discount (₹)",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: _buildGlassInput(
            height: 40,
            child: TextFormField(
              controller: discountController,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                suffixText: discountIsPercent ? '%' : '₹',
                suffixStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 14,
                ),
                border: InputBorder.none,
              ),
              onChanged: (v) {
                setState(() {
                  discount = double.tryParse(v) ?? 0.0;
                });
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            "- ₹${discountValue.toStringAsFixed(2)}",
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.redAccent.shade200,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountToggle() {
    return Row(
      children: [
        Transform.scale(
          scale: 0.8,
          child: Checkbox(
            value: discountIsPercent,
            activeColor: const Color(0xFF5B8CFF),
            checkColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            onChanged: (v) {
              setState(() {
                discountIsPercent = v!;
                discount = 0.0;
                discountController.text = '0';
              });
            },
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "Apply discount in %",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildMarkAsPaidToggle() {
    return Row(
      children: [
        Transform.scale(
          scale: 0.8,
          child: Checkbox(
            value: invoiceStatus == "PAID",
            activeColor: const Color(0xFF22C55E),
            checkColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            onChanged: (v) {
              setState(() {
                invoiceStatus = v! ? "PAID" : "PENDING";
              });
            },
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "Mark as Paid",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Total Amount",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF5B8CFF).withOpacity(0.2),
                const Color(0xFF5B8CFF).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFF5B8CFF).withOpacity(0.3),
            ),
          ),
          child: Text(
            "₹${total.toStringAsFixed(2)}",
            style: const TextStyle(
              color: Color(0xFF5B8CFF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool isDisabled,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPressed,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isDisabled
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isDisabled
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
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

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required bool isDisabled,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5B8CFF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          disabledBackgroundColor: const Color(0xFF5B8CFF).withOpacity(0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _liquidBlob({
    required double width,
    required double height,
    required Color color,
    required double opacity,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 140, sigmaY: 140),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}