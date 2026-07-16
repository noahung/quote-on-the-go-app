import 'package:flutter/material.dart';

class PdfPreviewPanel extends StatelessWidget {
  final String templateId;
  final String themeColor;
  final String companyName;
  final String companyAddress;
  final String? logoUrl;
  final String? email;
  final String? phone;
  final String? website;

  const PdfPreviewPanel({
    super.key,
    required this.templateId,
    required this.themeColor,
    required this.companyName,
    required this.companyAddress,
    this.logoUrl,
    this.email,
    this.phone,
    this.website,
  });

  Color _getThemeColor() {
    if (themeColor.isNotEmpty) {
      try {
        final hex = themeColor.replaceAll('#', '');
        return Color(int.parse('ff$hex', radix: 16));
      } catch (_) {}
    }
    // Fallback defaults based on template
    switch (templateId) {
      case 'teal-header':
        return const Color(0xff0d9488);
      case 'classic-minimal':
        return Colors.black;
      case 'sleek-charcoal':
        return const Color(0xff27272a);
      case 'emerald-professional':
        return const Color(0xff047857);
      case 'royal-elegant':
        return const Color(0xff1e3a8a);
      default:
        return const Color(0xfff97316); // modern-orange
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getThemeColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Real-Time styling preview'.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white60 : Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: AspectRatio(
            aspectRatio: 1 / 1.35, // A4 aspect ratio approximation
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _buildTemplateLayout(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTemplateLayout(Color color) {
    switch (templateId) {
      case 'teal-header':
        return _buildTealHeaderTemplate(color);
      case 'classic-minimal':
        return _buildClassicMinimalTemplate(color);
      case 'sleek-charcoal':
        return _buildSleekCharcoalTemplate(color);
      case 'emerald-professional':
        return _buildEmeraldProfessionalTemplate(color);
      case 'royal-elegant':
        return _buildRoyalElegantTemplate(color);
      default:
        return _buildModernOrangeTemplate(color);
    }
  }

  // ── Modern Orange Layout ───────────────────────────────────────────
  Widget _buildModernOrangeTemplate(Color color) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (logoUrl != null && logoUrl!.isNotEmpty)
                      _buildMiniLogo()
                    else
                      const SizedBox(height: 8),
                    Text(
                      companyName.isNotEmpty ? companyName : 'Your Company',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      companyAddress.isNotEmpty ? companyAddress : 'Address',
                      style: const TextStyle(fontSize: 8, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'QUOTATION',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xff111827),
                    ),
                  ),
                  Text(
                    '# QT-00001',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDivider(),
        Expanded(child: _buildCommonBody(color)),
      ],
    );
  }

  // ── Clean Teal Layout ──────────────────────────────────────────────
  Widget _buildTealHeaderTemplate(Color color) {
    return Column(
      children: [
        // Colored header block
        Container(
          width: double.infinity,
          color: color,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quotation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'No: QT-00001',
                    style: TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ],
              ),
              if (logoUrl != null && logoUrl!.isNotEmpty)
                _buildMiniLogo(bgColor: Colors.white24)
            ],
          ),
        ),
        // Company info bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                companyName.isNotEmpty ? companyName : 'Your Company',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff1f2937),
                ),
              ),
              Text(
                '${email ?? ""} | ${phone ?? ""}',
                style: const TextStyle(fontSize: 8, color: Colors.black54),
              ),
            ],
          ),
        ),
        _buildDivider(),
        Expanded(child: _buildCommonBody(color)),
      ],
    );
  }

  // ── Classic Minimal Layout ──────────────────────────────────────────
  Widget _buildClassicMinimalTemplate(Color color) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (logoUrl != null && logoUrl!.isNotEmpty)
                      _buildMiniLogo(),
                    Text(
                      (companyName.isNotEmpty ? companyName : 'Your Company').toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Serif',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      companyAddress.isNotEmpty ? companyAddress : 'Address',
                      style: const TextStyle(fontFamily: 'Serif', fontSize: 8, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'QUOTE',
                    style: TextStyle(
                      fontFamily: 'Serif',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '# QT-00001',
                    style: TextStyle(fontFamily: 'Serif', fontSize: 9, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            height: 1.5,
            color: Colors.black,
          ),
        ),
        Expanded(child: _buildCommonBody(color, isSerif: true)),
      ],
    );
  }

  // ── Sleek Charcoal Layout ──────────────────────────────────────────
  Widget _buildSleekCharcoalTemplate(Color color) {
    return Column(
      children: [
        // Charcoal colored top header block
        Container(
          width: double.infinity,
          color: color,
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (logoUrl != null && logoUrl!.isNotEmpty) ...[
                    _buildMiniLogo(bgColor: Colors.white24),
                    const SizedBox(width: 8),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName.isNotEmpty ? companyName : 'Your Company',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email ?? '',
                        style: const TextStyle(fontSize: 8, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'QUOTATION',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    '# QT-00001',
                    style: TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _buildCommonBody(color)),
      ],
    );
  }

  // ── Emerald Professional Layout ────────────────────────────────────
  Widget _buildEmeraldProfessionalTemplate(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 45,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (logoUrl != null && logoUrl!.isNotEmpty)
                            _buildMiniLogo(),
                          Text(
                            companyName.isNotEmpty ? companyName : 'Your Company',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xff111827),
                            ),
                          ),
                          Text(
                            companyAddress.isNotEmpty ? companyAddress : 'Address',
                            style: const TextStyle(fontSize: 8, color: Colors.black54),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Quotation',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    'No: QT-00001',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildDivider(),
        Expanded(child: _buildCommonBody(color)),
      ],
    );
  }

  // ── Royal Elegant Layout ───────────────────────────────────────────
  Widget _buildRoyalElegantTemplate(Color color) {
    return Column(
      children: [
        // Thin gold horizontal line at the very top
        Container(
          height: 2,
          color: const Color(0xffd97706),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (logoUrl != null && logoUrl!.isNotEmpty)
                      _buildMiniLogo(),
                    Text(
                      (companyName.isNotEmpty ? companyName : 'Your Company').toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Serif',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      companyAddress.isNotEmpty ? companyAddress : 'Address',
                      style: const TextStyle(fontFamily: 'Serif', fontSize: 8, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'QUOTATION',
                    style: TextStyle(
                      fontFamily: 'Serif',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 1,
                    ),
                  ),
                  const Text(
                    '# QT-00001',
                    style: TextStyle(
                      fontFamily: 'Serif',
                      fontSize: 9,
                      color: Color(0xffd97706),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            height: 1,
            color: color,
          ),
        ),
        Expanded(child: _buildCommonBody(color, isSerif: true, showSignature: true)),
      ],
    );
  }

  // Helper: Mini Logo
  Widget _buildMiniLogo({Color? bgColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Container(
        width: 32,
        height: 20,
        decoration: BoxDecoration(
          color: bgColor ?? Colors.grey.shade200,
          borderRadius: BorderRadius.circular(4),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.network(
            logoUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 12),
          ),
        ),
      ),
    );
  }

  // Helper: Divider
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Divider(height: 1, color: Colors.grey.shade200),
    );
  }

  // Helper: Shared Body layout simulator
  Widget _buildCommonBody(Color themeColor, {bool isSerif = false, bool showSignature = false}) {
    final style = TextStyle(fontFamily: isSerif ? 'Serif' : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Billed To & Dates side-by-side
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Billed To'.toUpperCase(),
                      style: TextStyle(
                        fontFamily: isSerif ? 'Serif' : null,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'John Doe',
                      style: TextStyle(
                        fontFamily: isSerif ? 'Serif' : null,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      '123 Maple Street\nLondon',
                      style: TextStyle(
                        fontFamily: isSerif ? 'Serif' : null,
                        fontSize: 8,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildMetaDate('Date:', '16 Jul 2026', isSerif),
                  const SizedBox(height: 2),
                  _buildMetaDate('Expires:', '15 Aug 2026', isSerif),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items table
          _buildMockTable(themeColor, isSerif),
          const SizedBox(height: 8),

          // Totals block
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 110,
                child: Column(
                  children: [
                    _buildTotalRow('Subtotal', '£1,630.00', isSerif),
                    const SizedBox(height: 2),
                    _buildTotalRow('VAT (20%)', '£326.00', isSerif),
                    const Divider(height: 6),
                    _buildTotalRow('Total', '£1,956.00', isSerif, isBold: true, highlightColor: themeColor),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Signature Option (Royal Elegant)
          if (showSignature) ...[
            Container(
              width: 140,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: themeColor, width: 0.5)),
              ),
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                'Client Signature',
                style: TextStyle(
                    fontFamily: 'Serif',
                    fontSize: 6,
                    fontWeight: FontWeight.bold,
                    color: themeColor),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Footer
          Center(
            child: Column(
              children: [
                if (showSignature)
                  Container(
                    height: 1,
                    color: const Color(0xffd97706),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Thank you for your business!',
                  style: style.copyWith(fontSize: 7, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
                ),
                if (website != null && website!.isNotEmpty)
                  Text(
                    website!,
                    style: style.copyWith(fontSize: 6, color: Colors.grey.shade400),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaDate(String label, String val, bool isSerif) {
    final style = TextStyle(fontFamily: isSerif ? 'Serif' : null, fontSize: 8);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: style.copyWith(color: Colors.black54)),
        Text(val, style: style.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildTotalRow(String label, String val, bool isSerif, {bool isBold = false, Color? highlightColor}) {
    final style = TextStyle(
      fontFamily: isSerif ? 'Serif' : null,
      fontSize: isBold ? 10 : 8,
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      color: highlightColor ?? (isBold ? Colors.black87 : Colors.black54),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(val, style: style),
      ],
    );
  }

  Widget _buildMockTable(Color themeColor, bool isSerif) {
    final headerStyle = TextStyle(
      fontFamily: isSerif ? 'Serif' : null,
      fontSize: 8,
      fontWeight: FontWeight.bold,
      color: templateId == 'teal-header' || templateId == 'emerald-professional' || templateId == 'royal-elegant'
          ? Colors.white
          : Colors.black87,
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: templateId == 'teal-header' || templateId == 'emerald-professional' || templateId == 'royal-elegant'
                ? themeColor
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(flex: 3, child: Text('Item Description', style: headerStyle)),
              Expanded(child: Text('Qty', style: headerStyle, textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text('Price', style: headerStyle, textAlign: TextAlign.right)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        _buildMockTableRow('Casement Window Installation', '3', '£450.00', isSerif),
        _buildDividerItem(),
        _buildMockTableRow('Fascia & Soffit Replacement', '1', '£280.00', isSerif),
        _buildDividerItem(),
      ],
    );
  }

  Widget _buildMockTableRow(String desc, String qty, String price, bool isSerif) {
    final style = TextStyle(fontFamily: isSerif ? 'Serif' : null, fontSize: 8, color: Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              desc,
              style: style.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(child: Text(qty, style: style, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text(price, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildDividerItem() {
    return Divider(height: 1, thickness: 0.5, color: Colors.grey.shade100);
  }
}
