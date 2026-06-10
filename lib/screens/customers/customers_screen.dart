import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../../components/glass_card.dart';
import '../../components/curved_header.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCustomers = ref.watch(customersProvider);
    final isLoading = ref.watch(customersStreamProvider).isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final customers = _searchQuery.isEmpty
        ? allCustomers
        : allCustomers.where((c) =>
            c.name.toLowerCase().contains(_searchQuery) ||
            c.email.toLowerCase().contains(_searchQuery) ||
            (c.phone ?? '').toLowerCase().contains(_searchQuery)).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(
            title: 'Customers',
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () => context.push('/customers/new'),
              ),
            ],
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers…',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          return _CustomerCard(customer: customers[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            'No Customers Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first customer to get started',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;

  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push('/customers/${customer.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Premium Glowing Initials Avatar Badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4781F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFF4781F).withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF4781F),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        customer.phone!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
