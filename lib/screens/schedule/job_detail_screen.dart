import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/models.dart';
import 'create_event_screen.dart';

// Provider for a single calendar event by ID
final jobDetailProvider =
    StreamProvider.family<CalendarEvent?, String>((ref, id) {
  return FirebaseFirestore.instance
      .collection('events')
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? CalendarEvent.fromFirestore(doc) : null);
});

class JobDetailScreen extends ConsumerWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));

    return jobAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Job Detail')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Job Detail')),
        body: Center(child: Text('Error: $e')),
      ),
      data: (job) {
        if (job == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Job Detail')),
            body: const Center(child: Text('Job not found')),
          );
        }
        return _JobDetailView(job: job);
      },
    );
  }
}

class _JobDetailView extends ConsumerWidget {
  final CalendarEvent job;
  const _JobDetailView({required this.job});

  Color get _jobColor {
    try {
      if (job.color != null) {
        return Color(int.parse(job.color!.replaceFirst('#', '0xff')));
      }
    } catch (_) {}
    return const Color(0xFFF4781F);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final start = DateTime.tryParse(job.start);
    final end = DateTime.tryParse(job.end);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Coloured hero app bar
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _jobColor,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateEventScreen(event: job),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                iconColor: Colors.white,
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete(context, ref);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child:
                        Text('Delete Job', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                job.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _jobColor,
                      _jobColor.withOpacity(0.7),
                    ],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Icon(Icons.work_outline,
                        size: 80, color: Colors.white.withOpacity(0.15)),
                  ),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Date & Time card
                _DetailCard(
                  title: 'Schedule',
                  icon: Icons.schedule_outlined,
                  children: [
                    if (job.allDay == true)
                      _DetailRow(
                        label: 'Date',
                        value: start != null
                            ? dateFormat.format(start)
                            : job.start,
                      )
                    else ...[
                      _DetailRow(
                        label: 'Date',
                        value: start != null
                            ? dateFormat.format(start)
                            : job.start,
                      ),
                      if (start != null) ...[
                        const Divider(height: 16),
                        _DetailRow(
                          label: 'Start Time',
                          value: timeFormat.format(start),
                        ),
                      ],
                      if (end != null) ...[
                        const Divider(height: 16),
                        _DetailRow(
                          label: 'End Time',
                          value: timeFormat.format(end),
                        ),
                      ],
                      if (start != null && end != null) ...[
                        const Divider(height: 16),
                        _DetailRow(
                          label: 'Duration',
                          value: _formatDuration(end.difference(start)),
                        ),
                      ],
                    ],
                    if (job.allDay == true) ...[
                      const Divider(height: 16),
                      _DetailRow(label: 'Duration', value: 'All Day'),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                if (job.description != null && job.description!.isNotEmpty) ...[
                  _DetailCard(
                    title: 'Description',
                    icon: Icons.notes_outlined,
                    children: [
                      Text(job.description!,
                          style: textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Google Calendar sync status
                if (job.googleEventId != null) ...[
                  _DetailCard(
                    title: 'Integrations',
                    icon: Icons.sync_outlined,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18, color: colorScheme.secondary),
                          const SizedBox(width: 8),
                          Text('Synced with Google Calendar',
                              style: textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.secondary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Action buttons
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Mark complete — coming soon')),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Mark as Complete'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.push('/quotations/new'),
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Create Quotation for this Job'),
                ),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(job.id)
            .delete();
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _DetailCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

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
                  style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

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
