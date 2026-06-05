import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';

class InvoicePortalScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoicePortalScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoice = ref.watch(invoiceProvider(invoiceId));

    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return MeshBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          _PortalAppBar(invoice: invoice),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _CompanyHeader(invoice: invoice),
                const SizedBox(height: 16),
                _InvoiceMetaCard(invoice: invoice),
                const SizedBox(height: 16),
                _ClientAddressCard(invoice: invoice),
                const SizedBox(height: 16),
                _ItemsCard(invoice: invoice),
                const SizedBox(height: 16),
                if (invoice.notes != null && invoice.notes!.isNotEmpty)
                  _NotesCard(notes: invoice.notes!),
                if (invoice.notes != null && invoice.notes!.isNotEmpty)
                  const SizedBox(height: 16),
                if (invoice.status == 'Paid')
                  _StatusBanner(
                    icon: Icons.check_circle_outline,
                    message: 'This invoice has been paid.',
                    color: Theme.of(context).colorScheme.tertiary,
                    bgColor: Theme.of(context).colorScheme.tertiaryContainer,
                  ),
                if (invoice.status == 'Overdue')
                  _StatusBanner(
                    icon: Icons.warning_amber_outlined,
                    message: 'This invoice is overdue.',
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
  final Invoice invoice;
  const _PortalAppBar({required this.invoice});

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
            context.go('/invoices/${invoice.id}');
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invoice.invoiceNumber,
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
        _StatusChip(status: invoice.status),
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
      case 'Paid':
        bg = colorScheme.tertiaryContainer;
        fg = colorScheme.tertiary;
      case 'Overdue':
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
  final Invoice invoice;
  const _CompanyHeader({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final company = invoice.company;

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

class _InvoiceMetaCard extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceMetaCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          _MetaRow(label: 'Invoice Number', value: invoice.invoiceNumber),
          const Divider(height: 20),
          _MetaRow(label: 'Issue Date', value: invoice.date),
          const Divider(height: 20),
          _MetaRow(label: 'Due Date', value: invoice.dueDate),
          if (invoice.quotationNumber != null) ...[
            const Divider(height: 20),
            _MetaRow(label: 'From Quotation', value: invoice.quotationNumber!),
          ],
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
  final Invoice invoice;
  const _ClientAddressCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill To',
              style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(invoice.customerName,
              style:
                  textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(invoice.customerEmail,
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant)),
          if (invoice.customerPhone != null) ...[
            const SizedBox(height: 2),
            Text(invoice.customerPhone!,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
          if (invoice.customerAddress != null) ...[
            const SizedBox(height: 2),
            Text(invoice.customerAddress!,
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final Invoice invoice;
  const _ItemsCard({required this.invoice});

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
          ...invoice.items.map((item) => Padding(
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
              value: currency.format(invoice.subtotal),
              isTotal: false),
          if (invoice.taxRate != null && invoice.taxAmount != null) ...[
            const SizedBox(height: 6),
            _TotalRow(
                label: 'Tax (${invoice.taxRate!.toStringAsFixed(0)}%)',
                value: currency.format(invoice.taxAmount),
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
                  currency.format(invoice.total),
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
