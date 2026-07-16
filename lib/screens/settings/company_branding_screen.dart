import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/pdf_preview_panel.dart';
import '../../models/company.dart';
import '../../providers/providers.dart';
import 'package:go_router/go_router.dart';
import '../../utils/feedback_controller.dart';
import '../../models/feedback_type.dart';

class CompanyBrandingScreen extends ConsumerStatefulWidget {
  const CompanyBrandingScreen({super.key});

  @override
  ConsumerState<CompanyBrandingScreen> createState() =>
      _CompanyBrandingScreenState();
}

class _CompanyBrandingScreenState extends ConsumerState<CompanyBrandingScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Company fields
  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _taxRateCtrl;

  // Bank account fields (first account)
  late TextEditingController _acctNameCtrl;
  late TextEditingController _bankNameCtrl;
  late TextEditingController _sortCodeCtrl;
  late TextEditingController _acctNumberCtrl;

  Company? _company;
  bool _initialised = false;

  // Logo state
  File? _newLogoFile;
  String? _existingLogoUrl;
  bool _removeLogo = false;

  // PDF state
  String? _selectedTemplateId;
  String? _selectedThemeColor;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _taxRateCtrl = TextEditingController();
    _acctNameCtrl = TextEditingController();
    _bankNameCtrl = TextEditingController();
    _sortCodeCtrl = TextEditingController();
    _acctNumberCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _addressCtrl,
      _emailCtrl,
      _phoneCtrl,
      _websiteCtrl,
      _taxRateCtrl,
      _acctNameCtrl,
      _bankNameCtrl,
      _sortCodeCtrl,
      _acctNumberCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFromCompany(Company company) {
    if (_initialised) return;
    _initialised = true;
    _nameCtrl.text = company.name;
    _addressCtrl.text = company.address;
    _emailCtrl.text = company.email ?? '';
    _phoneCtrl.text = company.phone ?? '';
    _websiteCtrl.text = company.website ?? '';
    _taxRateCtrl.text =
        company.defaultTaxRate != null ? '${company.defaultTaxRate}' : '';
    _existingLogoUrl = company.logoUrl;
    _selectedTemplateId = company.defaultPdfTemplateId ?? 'modern-orange';
    _selectedThemeColor = company.defaultPdfThemeColor ?? '';
    final bank = (company.bankAccounts?.isNotEmpty == true)
        ? company.bankAccounts!.first
        : null;
    if (bank != null) {
      _acctNameCtrl.text = bank.accountName;
      _bankNameCtrl.text = bank.bankName;
      _sortCodeCtrl.text = bank.sortCode;
      _acctNumberCtrl.text = bank.accountNumber;
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked != null) {
      setState(() {
        _newLogoFile = File(picked.path);
        _removeLogo = false;
      });
    }
  }

  void _clearLogo() {
    setState(() {
      _newLogoFile = null;
      _removeLogo = true;
    });
  }

  Widget _buildLogoPreview(ColorScheme colorScheme) {
    // New file selected — show local preview
    if (_newLogoFile != null) {
      return Image.file(_newLogoFile!, fit: BoxFit.cover);
    }
    // Existing URL and not marked for removal
    if (_existingLogoUrl != null && !_removeLogo) {
      return Image.network(
        _existingLogoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _logoPlaceholder(colorScheme),
      );
    }
    // No logo
    return _logoPlaceholder(colorScheme);
  }

  Widget _logoPlaceholder(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 32, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text('No logo',
            style:
                TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final company = _company;
    if (company == null) return;

    setState(() => _isSaving = true);
    try {
      // Handle logo upload / removal
      String? logoUrl = _existingLogoUrl;
      if (_newLogoFile != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('companies/${company.id}/logo.jpg');
          await ref.putFile(_newLogoFile!);
          logoUrl = await ref.getDownloadURL();
          setState(() {
            _existingLogoUrl = logoUrl;
            _newLogoFile = null;
          });
        } catch (_) {
          // Storage upload failed — skip logo change silently
        }
      } else if (_removeLogo) {
        try {
          await FirebaseStorage.instance
              .ref()
              .child('companies/${company.id}/logo.jpg')
              .delete();
        } catch (_) {}
        logoUrl = null;
        setState(() {
          _existingLogoUrl = null;
          _removeLogo = false;
        });
      }

      final taxRate = double.tryParse(_taxRateCtrl.text.trim());
      final hasBankDetails = _acctNameCtrl.text.trim().isNotEmpty ||
          _bankNameCtrl.text.trim().isNotEmpty;

      final List<Map<String, dynamic>> bankAccounts = [];
      if (hasBankDetails) {
        final existingId = company.bankAccounts?.isNotEmpty == true
            ? company.bankAccounts!.first.id
            : 'primary';
        bankAccounts.add({
          'id': existingId,
          'accountName': _acctNameCtrl.text.trim(),
          'bankName': _bankNameCtrl.text.trim(),
          'sortCode': _sortCodeCtrl.text.trim(),
          'accountNumber': _acctNumberCtrl.text.trim(),
        });
      }

      final Map<String, dynamic> updates = {
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'logoUrl': logoUrl,
        if (taxRate != null) 'defaultTaxRate': taxRate,
        if (bankAccounts.isNotEmpty) 'bankAccounts': bankAccounts,
        'defaultPdfTemplateId': _selectedTemplateId ?? 'modern-orange',
        'defaultPdfThemeColor': _selectedThemeColor ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(company.id)
          .update(updates);

      if (mounted) {
        await ref.read(feedbackControllerProvider).showCelebration(
          context: context,
          type: CelebrationType.sparkle,
          title: 'Branding Updated',
          subtitle: 'Your company profile has been saved',
          onDone: () => context.pop(),
        );
      }
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Error saving: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showPremiumDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Feature'),
          ],
        ),
        content: const Text(
          'Customising PDF layouts and accent colours is a Pro feature. Please upgrade your subscription on our web platform to unlock these styling features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final company = ref.watch(companyProvider);
    final userProfile = ref.watch(userProfileProvider);
    final role = userProfile?.role.toLowerCase();
    final canEdit = role == 'owner' || role == 'admin';
    final isPremiumUser = company?.tier == 'premium' ||
        company?.tier == 'individual' ||
        company?.tier == 'organisation';

    if (company != null) {
      _company = company;
      _populateFromCompany(company);
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings');
              }
            },
          ),
          title: const Text('Company Branding',
              style: TextStyle(fontWeight: FontWeight.w600)),
          actions: [
            if (canEdit)
              _isSaving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.check),
                      tooltip: 'Save',
                      onPressed: _save,
                    ),
          ],
        ),
        body: company == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (!canEdit)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16,
                                color: colorScheme.onSecondaryContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'As a member you can view but not edit company settings.',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSecondaryContainer),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Company Logo ──────────────────────────────────────
                    _SectionCard(
                      title: 'Company Logo',
                      icon: LucideIcons.image,
                      children: [
                        Text(
                          'Appears on your quotes and invoices.',
                          style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            // Logo preview
                            GestureDetector(
                              onTap: canEdit ? _pickLogo : null,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color:
                                          colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: _buildLogoPreview(colorScheme),
                                    ),
                                  ),
                                  if (canEdit)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(8),
                                            bottomRight: Radius.circular(11),
                                          ),
                                        ),
                                        child: Icon(
                                          LucideIcons.pencil,
                                          size: 14,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (canEdit)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _pickLogo,
                                      icon: const Icon(Icons.upload_outlined,
                                          size: 16),
                                      label: Text(
                                        _newLogoFile != null ||
                                                (_existingLogoUrl != null &&
                                                    !_removeLogo)
                                            ? 'Change Logo'
                                            : 'Upload Logo',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size(double.infinity, 40)),
                                    ),
                                    if (_newLogoFile != null ||
                                        (_existingLogoUrl != null &&
                                            !_removeLogo)) ...[
                                      const SizedBox(height: 8),
                                      TextButton.icon(
                                        onPressed: _clearLogo,
                                        icon: Icon(Icons.delete_outline,
                                            size: 16, color: colorScheme.error),
                                        label: Text('Remove Logo',
                                            style: TextStyle(
                                                color: colorScheme.error)),
                                        style: TextButton.styleFrom(
                                            minimumSize: const Size(
                                                double.infinity, 36)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── Company Info ──────────────────────────────────────
                    _SectionCard(
                      title: 'Company Details',
                      icon: LucideIcons.building2,
                      children: [
                        _Field(
                          label: 'Company Name',
                          controller: _nameCtrl,
                          enabled: canEdit,
                          required: true,
                          hint: 'Your Company Ltd.',
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Address',
                          controller: _addressCtrl,
                          enabled: canEdit,
                          required: true,
                          hint: '123 Main Street, London, SW1A 1AA',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Email',
                          controller: _emailCtrl,
                          enabled: canEdit,
                          hint: 'contact@yourco.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Phone',
                          controller: _phoneCtrl,
                          enabled: canEdit,
                          hint: '+44 123 456 7890',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Website',
                          controller: _websiteCtrl,
                          enabled: canEdit,
                          hint: 'https://yourcompany.com',
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Default Tax Rate (%)',
                          controller: _taxRateCtrl,
                          enabled: canEdit,
                          hint: '20',
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ── PDF Styling ──────────────────────────────────────
                    _SectionCard(
                      title: 'PDF Document Theme & Styling',
                      icon: LucideIcons.palette,
                      children: [
                        Text(
                          'Select a default template layout and custom accent colour for all generated quotations and invoices.',
                          style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Template Layout'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...[
                          {
                            'id': 'modern-orange',
                            'name': 'Modern Orange',
                            'desc': 'Orange highlights, clean spacing',
                            'isPremium': false,
                          },
                          {
                            'id': 'teal-header',
                            'name': 'Clean Teal',
                            'desc': 'Teal header, shaded sidebar card',
                            'isPremium': true,
                          },
                          {
                            'id': 'classic-minimal',
                            'name': 'Classic Minimal',
                            'desc': 'Classic serif typography, grid outline',
                            'isPremium': true,
                          },
                          {
                            'id': 'sleek-charcoal',
                            'name': 'Sleek Charcoal',
                            'desc': 'Deep charcoal header, corporate look',
                            'isPremium': true,
                          },
                          {
                            'id': 'emerald-professional',
                            'name': 'Emerald Pro',
                            'desc': 'Emerald accents, geometric sidebar',
                            'isPremium': true,
                          },
                          {
                            'id': 'royal-elegant',
                            'name': 'Royal Elegant',
                            'desc': 'Royal navy & gold, double thin borders',
                            'isPremium': true,
                          },
                        ].map((tpl) {
                          final String id = tpl['id'] as String;
                          final String name = tpl['name'] as String;
                          final String desc = tpl['desc'] as String;
                          final bool isPremiumTemplate = tpl['isPremium'] as bool;
                          final isSelected = _selectedTemplateId == id;
                          final isLocked = isPremiumTemplate && !isPremiumUser;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: InkWell(
                              onTap: !canEdit ? null : () {
                                if (isLocked) {
                                  _showPremiumDialog(context);
                                } else {
                                  setState(() {
                                    _selectedTemplateId = id;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isSelected
                                      ? colorScheme.primaryContainer.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14),
                                              ),
                                              if (isPremiumTemplate) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.star,
                                                          size: 10,
                                                          color: Colors.amber),
                                                      SizedBox(width: 2),
                                                      Text(
                                                        'PRO',
                                                        style: TextStyle(
                                                            fontSize: 8,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.amber),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            desc,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.check_circle,
                                          color: colorScheme.primary)
                                    else if (isLocked)
                                      Icon(Icons.lock_outline,
                                          size: 18, color: colorScheme.onSurfaceVariant),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        Text(
                          'Accent Colour'.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            {'name': 'Default', 'color': null, 'hex': ''},
                            {'name': 'Charcoal', 'color': const Color(0xff27272a), 'hex': '#27272a'},
                            {'name': 'Indigo', 'color': const Color(0xff4f46e5), 'hex': '#4f46e5'},
                            {'name': 'Blue', 'color': const Color(0xff2563eb), 'hex': '#2563eb'},
                            {'name': 'Teal', 'color': const Color(0xff0d9488), 'hex': '#0d9488'},
                            {'name': 'Emerald', 'color': const Color(0xff059669), 'hex': '#059669'},
                            {'name': 'Amber', 'color': const Color(0xffd97706), 'hex': '#d97706'},
                            {'name': 'Rose', 'color': const Color(0xffe11d48), 'hex': '#e11d48'},
                          ].map((colorItem) {
                            final String name = colorItem['name'] as String;
                            final Color? color = colorItem['color'] as Color?;
                            final String hex = colorItem['hex'] as String;
                            final isSelected = _selectedThemeColor == hex;
                            final isLocked = hex.isNotEmpty && !isPremiumUser;

                            return InkWell(
                              onTap: !canEdit ? null : () {
                                if (isLocked) {
                                  _showPremiumDialog(context);
                                } else {
                                  setState(() {
                                    _selectedThemeColor = hex;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  color: isSelected
                                      ? colorScheme.primaryContainer.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (color != null)
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: const BoxDecoration(
                                          gradient: SweepGradient(
                                            colors: [Colors.orange, Colors.teal, Colors.indigo, Colors.orange],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    const SizedBox(width: 6),
                                    Text(name, style: const TextStyle(fontSize: 12)),
                                    if (isLocked) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.lock_outline, size: 10),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    PdfPreviewPanel(
                      templateId: _selectedTemplateId ?? 'modern-orange',
                      themeColor: _selectedThemeColor ?? '',
                      companyName: _nameCtrl.text,
                      companyAddress: _addressCtrl.text,
                      logoUrl: _newLogoFile != null ? null : _existingLogoUrl,
                      email: _emailCtrl.text,
                      phone: _phoneCtrl.text,
                      website: _websiteCtrl.text,
                    ),

                    const SizedBox(height: 16),

                    // ── Bank Details ──────────────────────────────────────
                    _SectionCard(
                      title: 'Payment / Bank Details',
                      icon: LucideIcons.landmark,
                      children: [
                        Text(
                          'Appears on your invoices for customer payments.',
                          style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Account Holder Name',
                          controller: _acctNameCtrl,
                          enabled: canEdit,
                          hint: 'My Business Ltd',
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Bank Name',
                          controller: _bankNameCtrl,
                          enabled: canEdit,
                          hint: 'Monzo Bank',
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Sort Code',
                          controller: _sortCodeCtrl,
                          enabled: canEdit,
                          hint: '04-00-04',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        _Field(
                          label: 'Account Number',
                          controller: _acctNumberCtrl,
                          enabled: canEdit,
                          hint: '12345678',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    if (canEdit)
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GlassCard(
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool required;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    this.required = false,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
