import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';

class QuotationPortalScreen extends ConsumerWidget {
  final String quotationId;

  const QuotationPortalScreen({super.key, required this.quotationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotation = ref.watch(quotationProvider(quotationId));

    if (quotation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quote')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return MeshBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          _PortalAppBar(quotation: quotation),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _CompanyHeader(quotation: quotation),
                const SizedBox(height: 16),
                _QuoteMetaCard(quotation: quotation),
                const SizedBox(height: 16),
                _ClientAddressCard(quotation: quotation),
                const SizedBox(height: 16),
                _ItemsCard(quotation: quotation),
                const SizedBox(height: 16),
                if (quotation.notes != null && quotation.notes!.isNotEmpty)
                  _NotesCard(notes: quotation.notes!),
                if (quotation.notes != null && quotation.notes!.isNotEmpty)
                  const SizedBox(height: 16),
                if (quotation.status == 'Sent')
                  _ActionButtons(
                      quotation: quotation, ref: ref, context: context),
                if (quotation.status == 'Sent') const SizedBox(height: 16),
                if (quotation.status == 'Accepted')
                  _StatusBanner(
                    icon: Icons.check_circle_outline,
                    message: 'You have accepted this quote.',
                    color: Theme.of(context).colorScheme.tertiary,
                    bgColor: Theme.of(context).colorScheme.tertiaryContainer,
                  ),
                if (quotation.status == 'Declined')
                  _StatusBanner(
                    icon: Icons.cancel_outlined,
                    message: 'You have declined this quote.',
                    color: Theme.of(context).colorScheme.error,
                    bgColor: Theme.of(context).colorScheme.errorContainer,
                  ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    ));
  }
}

class _PortalAppBar extends StatelessWidget {
  final Quotation quotation;
  const _PortalAppBar({required this.quotation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/quotations/${quotation.id}');
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quotation.quotationNumber,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            'Client View',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        _StatusChip(status: quotation.status),
        const SizedBox(width: 12),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    switch (status) {
      case 'Accepted':
        bg = colorScheme.tertiaryContainer;
        fg = colorScheme.tertiary;
      case 'Declined':
        bg = colorScheme.errorContainer;
        fg = colorScheme.error;
      case 'Sent':
        bg = colorScheme.secondaryContainer;
        fg = colorScheme.secondary;
      default:
        bg = colorScheme.surfaceContainerHighest;
        fg = colorScheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CompanyHeader extends StatelessWidget {
  final Quotation quotation;
  const _CompanyHeader({required this.quotation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final company = quotation.company;

    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          if (company?.logoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                company!.logoUrl!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _LogoFallback(name: company.name, colorScheme: colorScheme),
              ),
            )
          else
            _LogoFallback(name: company?.name ?? 'C', colorScheme: colorScheme),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company?.name ?? 'Company',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (company?.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    company!.email!,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
                if (company?.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    company!.phone!,
                    style: textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final String name;
  final ColorScheme colorScheme;
  const _LogoFallback({required this.name, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'C',
          style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _QuoteMetaCard extends StatelessWidget {
  final Quotation quotation;
  const _QuoteMetaCard({required this.quotation});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          _MetaRow(label: 'Quote Number', value: quotation.quotationNumber),
          const Divider(height: 20),
          _MetaRow(label: 'Issue Date', value: quotation.date),
          const Divider(height: 20),
          _MetaRow(label: 'Expiry Date', value: quotation.expiryDate),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        Text(value,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _ClientAddressCard extends StatelessWidget {
  final Quotation quotation;
  const _ClientAddressCard({required this.quotation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quote For',
              style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(quotation.customerName,
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(quotation.customerEmail,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          if (quotation.customerPhone != null) ...[
            const SizedBox(height: 2),
            Text(quotation.customerPhone!,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
          if (quotation.customerAddress != null) ...[
            const SizedBox(height: 2),
            Text(quotation.customerAddress!,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final Quotation quotation;
  const _ItemsCard({required this.quotation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currency = NumberFormat.currency(symbol: '£');

    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Services & Items',
              style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          ...quotation.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.description,
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          Text(
                            '${item.quantity} × ${currency.format(item.unitPrice)}',
                            style: textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      currency.format(item.total),
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
          const Divider(),
          const SizedBox(height: 8),
          _TotalRow(
              label: 'Subtotal',
              value: currency.format(quotation.subtotal),
              isTotal: false),
          if (quotation.taxRate != null && quotation.taxAmount != null) ...[
            const SizedBox(height: 6),
            _TotalRow(
                label: 'Tax (${quotation.taxRate!.toStringAsFixed(0)}%)',
                value: currency.format(quotation.taxAmount),
                isTotal: false),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onPrimaryContainer)),
                Text(
                  currency.format(quotation.total),
                  style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  const _TotalRow(
      {required this.label, required this.value, required this.isTotal});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: isTotal
                ? Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)
                : Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value,
            style: isTotal
                ? Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)
                : Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String notes;
  const _NotesCard({required this.notes});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes & Terms',
              style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(notes,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatefulWidget {
  final Quotation quotation;
  final WidgetRef ref;
  final BuildContext context;
  const _ActionButtons(
      {required this.quotation, required this.ref, required this.context});

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _loading = false;

  Future<void> _updateStatus(String status) async {
    setState(() => _loading = true);
    try {
      final repo = widget.ref.read(quotationRepositoryProvider);
      await repo.updateQuotationStatus(widget.quotation.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Quote $status'),
            backgroundColor: status == 'Accepted'
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.tertiary,
            foregroundColor: colorScheme.onTertiary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _loading ? null : () => _updateStatus('Accepted'),
          icon: const Icon(Icons.check_circle_outline),
          label:
              _loading ? const Text('Updating…') : const Text('Accept Quote'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _loading ? null : () => _updateStatus('Declined'),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Decline Quote'),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  final Color bgColor;
  const _StatusBanner(
      {required this.icon,
      required this.message,
      required this.color,
      required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
