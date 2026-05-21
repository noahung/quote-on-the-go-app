import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

/// A widget that displays a visual preview of a Quotation or Invoice
/// Similar to the "Web" preview in the Next.js web app
class DocumentPreview extends StatelessWidget {
  final dynamic document; // Quotation or Invoice
  final CompanyProfile? company;
  final bool isDraft;

  const DocumentPreview({
    super.key,
    required this.document,
    this.company,
    this.isDraft = true,
  });

  bool get isQuotation => document is Quotation;
  bool get isInvoice => document is Invoice;

  String get documentNumber {
    if (isQuotation) {
      return (document as Quotation).quotationNumber;
    } else {
      return (document as Invoice).invoiceNumber;
    }
  }

  String get customerName => document.customerName;
  String get customerEmail => document.customerEmail;
  String? get customerPhone => document.customerPhone;
  String? get customerAddress => document.customerAddress;
  String get date => document.date;
  String get secondaryDate {
    if (isQuotation) {
      return (document as Quotation).expiryDate;
    } else {
      return (document as Invoice).dueDate;
    }
  }

  String get secondaryDateLabel => isQuotation ? 'Expires' : 'Due';
  List<LineItem> get items => document.items;
  double get subtotal => document.subtotal;
  double? get taxRate => document.taxRate;
  double? get taxAmount => document.taxAmount;
  double get total => document.total;
  String? get notes => document.notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (document == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description_outlined,
              size: 64,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Fill in the details to see preview',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey[100],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(colorScheme),
              
              const Divider(height: 1),
              
              // Bill To & Dates
              _buildBillToAndDates(colorScheme),
              
              const Divider(height: 1),
              
              // Items Table
              _buildItemsTable(colorScheme),
              
              const Divider(height: 1),
              
              // Totals
              _buildTotals(colorScheme),
              
              // Notes
              if (notes != null && notes!.isNotEmpty)
                _buildNotes(colorScheme),
              
              // Footer
              _buildFooter(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Company Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (company?.logoUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Image.network(
                      company!.logoUrl!,
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                Text(
                  company?.name ?? 'Your Company',
                  style: GoogleFonts.headlandOne(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                if (company?.address != null)
                  Text(
                    company!.address!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (company?.email != null) 'Email: ${company!.email}',
                    if (company?.phone != null) 'Phone: ${company!.phone}',
                  ].join(' | '),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          
          // Document Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isQuotation ? 'QUOTE' : 'INVOICE',
                style: GoogleFonts.headlandOne(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                documentNumber,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDraft ? Colors.orange[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isDraft ? 'DRAFT PREVIEW' : 'OFFICIAL DOCUMENT',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDraft ? Colors.orange[700] : Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillToAndDates(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bill To
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BILLED TO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  customerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  customerEmail,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                if (customerPhone != null && customerPhone!.isNotEmpty)
                  Text(
                    customerPhone!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                if (customerAddress != null && customerAddress!.isNotEmpty)
                  Text(
                    customerAddress!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // Dates
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildDateRow('Date:', date),
              const SizedBox(height: 4),
              _buildDateRow('$secondaryDateLabel:', secondaryDate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow(String label, String dateStr) {
    final date = DateTime.tryParse(dateStr);
    final formattedDate = date != null
        ? DateFormat('d MMM, yyyy').format(date)
        : dateStr;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formattedDate,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsTable(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Item',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Qty',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Unit Price',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Item Rows
          ...items.map((item) => _buildItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildItemRow(LineItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.itemDetails != null && item.itemDetails!.isNotEmpty)
                  Text(
                    item.itemDetails!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              '£${item.unitPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              '£${item.total.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotals(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildTotalRow('Subtotal', subtotal, isBold: false),
                if (taxRate != null && taxRate! > 0 && taxAmount != null)
                  _buildTotalRow('VAT (${taxRate!.toStringAsFixed(0)}%)', taxAmount!, isBold: false),
                const Divider(height: 16),
                _buildTotalRow('Total', total, isBold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              color: isBold ? Colors.grey[800] : Colors.grey[600],
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            '£${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Colors.grey[900] : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotes(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 16),
          Text(
            'NOTES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            notes!,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    final secondaryDateValue = DateTime.tryParse(secondaryDate);
    final formattedSecondaryDate = secondaryDateValue != null
        ? DateFormat('d MMM, yyyy').format(secondaryDateValue)
        : secondaryDate;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        children: [
          Text(
            isQuotation
                ? 'Thank you for your business!'
                : 'Payment is due by $formattedSecondaryDate.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
          if (company?.website != null && company!.website!.isNotEmpty)
            Text(
              company!.website!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
        ],
      ),
    );
  }
}
