import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/company.dart';
import '../../providers/providers.dart';

class CompanyBrandingScreen extends ConsumerStatefulWidget {
  const CompanyBrandingScreen({super.key});

  @override
  ConsumerState<CompanyBrandingScreen> createState() =>
      _CompanyBrandingScreenState();
}

class _CompanyBrandingScreenState
    extends ConsumerState<CompanyBrandingScreen> {
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
      _nameCtrl, _addressCtrl, _emailCtrl, _phoneCtrl, _websiteCtrl,
      _taxRateCtrl, _acctNameCtrl, _bankNameCtrl, _sortCodeCtrl, _acctNumberCtrl,
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
    final bank =
        (company.bankAccounts?.isNotEmpty == true) ? company.bankAccounts!.first : null;
    if (bank != null) {
      _acctNameCtrl.text = bank.accountName;
      _bankNameCtrl.text = bank.bankName;
      _sortCodeCtrl.text = bank.sortCode;
      _acctNumberCtrl.text = bank.accountNumber;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final company = _company;
    if (company == null) return;

    setState(() => _isSaving = true);
    try {
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
        if (taxRate != null) 'defaultTaxRate': taxRate,
        if (bankAccounts.isNotEmpty) 'bankAccounts': bankAccounts,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(company.id)
          .update(updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company branding saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final company = ref.watch(companyProvider);
    final userProfile = ref.watch(userProfileProvider);
    final canEdit =
        userProfile?.role == 'owner' || userProfile?.role == 'admin';

    if (company != null) {
      _company = company;
      _populateFromCompany(company);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Company Branding',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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

                  // ── Company Info ──────────────────────────────────────
                  _SectionCard(
                    title: 'Company Details',
                    icon: Icons.business_outlined,
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
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Email',
                              controller: _emailCtrl,
                              enabled: canEdit,
                              hint: 'contact@yourco.com',
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              label: 'Phone',
                              controller: _phoneCtrl,
                              enabled: canEdit,
                              hint: '+44 123 456 7890',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Website',
                              controller: _websiteCtrl,
                              enabled: canEdit,
                              hint: 'https://yourcompany.com',
                              keyboardType: TextInputType.url,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              label: 'Default Tax Rate (%)',
                              controller: _taxRateCtrl,
                              enabled: canEdit,
                              hint: '20',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Bank Details ──────────────────────────────────────
                  _SectionCard(
                    title: 'Payment / Bank Details',
                    icon: Icons.account_balance_outlined,
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
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              label: 'Sort Code',
                              controller: _sortCodeCtrl,
                              enabled: canEdit,
                              hint: '04-00-04',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              label: 'Account Number',
                              controller: _acctNumberCtrl,
                              enabled: canEdit,
                              hint: '12345678',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
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
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
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
