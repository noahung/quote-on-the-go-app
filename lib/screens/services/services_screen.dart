import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../models/service.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesStreamProvider);

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
                context.go('/');
              }
            },
          ),
          title: const Text(
            'Services',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/services/new'),
            ),
          ],
        ),
        body: servicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (services) {
            if (services.isEmpty) {
              return AppEmptyState(
                icon: Icons.construction,
                title: 'No services yet',
                subtitle: 'Add your service offerings here.',
                actionLabel: 'Add Service',
                onAction: () => context.push('/services/new'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return _ServiceCard(service: service);
              },
            );
          },
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Service service;

  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        onTap: () => context.push('/services/${service.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  NumberFormat.currency(symbol: '£').format(service.price),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            if (service.description != null &&
                service.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                service.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
