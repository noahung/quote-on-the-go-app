import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../components/curved_header.dart';
import '../../components/mesh_background.dart';
import '../../models/service.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MeshBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(
            title: 'Services',
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => context.push('/services/new'),
              ),
            ],
          ),
          Expanded(
            child: servicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (services) {
                final filtered = _searchQuery.isEmpty
                    ? services
                    : services.where((s) =>
                        s.name.toLowerCase().contains(_searchQuery) ||
                        (s.description?.toLowerCase().contains(_searchQuery) ?? false)).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase().trim()),
                        decoration: InputDecoration(
                          hintText: 'Search services...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? AppEmptyState(
                              icon: Icons.construction,
                              title: _searchQuery.isNotEmpty
                                  ? 'No services match "$_searchQuery"'
                                  : 'No services yet',
                              subtitle: _searchQuery.isEmpty
                                  ? 'Add your service offerings and pricing here.'
                                  : null,
                              actionLabel: _searchQuery.isEmpty ? 'Add Service' : null,
                              onAction: _searchQuery.isEmpty
                                  ? () => context.push('/services/new')
                                  : null,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) =>
                                  _ServiceCard(service: filtered[index]),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = NumberFormat.currency(symbol: '£', decimalDigits: 2);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/services/${service.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.build_outlined,
                    color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (service.description != null &&
                        service.description!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        service.description!,
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                currency.format(service.price),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
