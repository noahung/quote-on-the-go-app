import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/models.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../providers/auth_provider.dart';
import '../../providers/job_note_provider.dart';
import '../../providers/job_media_provider.dart';
import '../../providers/quotation_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/customer_provider.dart';
import 'create_job_screen.dart';
import '../quotations/create_quotation_screen.dart';
import '../invoices/create_invoice_screen.dart';

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

class _JobDetailView extends ConsumerStatefulWidget {
  final CalendarEvent job;
  const _JobDetailView({required this.job});

  @override
  ConsumerState<_JobDetailView> createState() => _JobDetailViewState();
}

class _JobDetailViewState extends ConsumerState<_JobDetailView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Quotes'),
    Tab(text: 'Invoices'),
    Tab(text: 'Expenses'),
    Tab(text: 'Media'),
    Tab(text: 'Notes'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color get _jobColor {
    try {
      if (widget.job.color != null) {
        return Color(int.parse(widget.job.color!.replaceFirst('#', '0xff')));
      }
    } catch (_) {}
    return const Color(0xFFF4781F);
  }

  Future<void> _confirmDelete() async {
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
    if (confirmed == true && mounted) {
      try {
        await FirebaseFirestore.instance
            .collection('events')
            .doc(widget.job.id)
            .delete();
        if (mounted) context.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverAppBar(
              expandedHeight: 110,
              pinned: true,
              backgroundColor: _jobColor.withOpacity(0.85),
              foregroundColor: Colors.white,
              title: Text(
                widget.job.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CreateJobScreen(event: widget.job),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                iconColor: Colors.white,
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete();
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
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_jobColor, _jobColor.withAlpha(178)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.work_outline,
                        size: 60, color: Colors.white.withAlpha(38)),
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  indicator: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  tabs: _tabs,
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _OverviewTab(job: widget.job),
            _QuotesTab(jobId: widget.job.id, job: widget.job),
            _InvoicesTab(jobId: widget.job.id, job: widget.job),
            _ExpensesTab(jobId: widget.job.id, job: widget.job),
            _MediaTab(jobId: widget.job.id, companyId: widget.job.companyId),
            _NotesTab(jobId: widget.job.id, companyId: widget.job.companyId),
          ],
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 1: Overview
// ─────────────────────────────────────────────────────────────────
class _OverviewTab extends ConsumerWidget {
  final CalendarEvent job;
  const _OverviewTab({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final start = DateTime.tryParse(job.start);
    final end = DateTime.tryParse(job.end);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Project value: sum of linked quotes
    final allQuotes = ref.watch(quotationsStreamProvider).valueOrNull ?? [];
    final linkedQuotes = allQuotes.where((q) => q.jobId == job.id).toList();
    final projectValue =
        linkedQuotes.fold<double>(0, (acc, q) => acc + q.total);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status chip
        Row(
          children: [
            _StatusChip(status: job.status ?? 'Draft'),
            if (job.googleEventId != null) ...[
              const SizedBox(width: 8),
              Chip(
                avatar:
                    Icon(Icons.sync, size: 14, color: colorScheme.secondary),
                label: Text('Google Calendar',
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.secondary)),
                backgroundColor: colorScheme.secondaryContainer,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Project value card
        if (linkedQuotes.isNotEmpty)
          _InfoCard(
            icon: Icons.attach_money,
            title: 'Project Value',
            child: Text(
              NumberFormat.currency(symbol: r'$').format(projectValue),
              style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary, fontWeight: FontWeight.bold),
            ),
          ),
        if (linkedQuotes.isNotEmpty) const SizedBox(height: 12),

        // Customer info
        if (job.customerName != null)
          _InfoCard(
            icon: Icons.person_outline,
            title: 'Customer',
            child: Text(job.customerName!, style: textTheme.bodyMedium),
          ),
        if (job.customerName != null) const SizedBox(height: 12),

        // Schedule card
        _InfoCard(
          icon: Icons.schedule_outlined,
          title: 'Schedule',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'Date',
                value: start != null ? dateFormat.format(start) : job.start,
              ),
              if (job.allDay == true)
                const _DetailRow(label: 'Duration', value: 'All Day')
              else ...[
                if (start != null) ...[
                  const Divider(height: 12),
                  _DetailRow(label: 'Start', value: timeFormat.format(start)),
                ],
                if (end != null) ...[
                  const Divider(height: 12),
                  _DetailRow(label: 'End', value: timeFormat.format(end)),
                ],
                if (start != null && end != null) ...[
                  const Divider(height: 12),
                  _DetailRow(
                    label: 'Duration',
                    value: _formatDuration(end.difference(start)),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Description
        if (job.description != null && job.description!.isNotEmpty) ...[
          _InfoCard(
            icon: Icons.notes_outlined,
            title: 'Description',
            child: Text(job.description!,
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 12),
        ],

        // Site address + map
        if (job.customerAddress != null && job.customerAddress!.isNotEmpty) ...[
          _InfoCard(
            icon: Icons.location_on_outlined,
            title: 'Site Address',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.customerAddress!, style: textTheme.bodyMedium),
                const SizedBox(height: 12),
                _MapEmbed(address: job.customerAddress!),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 2: Quotes
// ─────────────────────────────────────────────────────────────────
class _QuotesTab extends ConsumerWidget {
  final String jobId;
  final CalendarEvent job;
  const _QuotesTab({required this.jobId, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final allQuotes = ref.watch(quotationsStreamProvider);

    return allQuotes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (quotes) {
        final linked = quotes.where((q) => q.jobId == jobId).toList();
        return Scaffold(
          body: linked.isEmpty
              ? _EmptyState(
                  icon: Icons.description_outlined,
                  color: colorScheme.primary,
                  label: 'No quotations yet',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: linked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final q = linked[i];
                    return _QuotationTile(
                        quotation: q,
                        onTap: () => context.push('/quotations/${q.id}'));
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Customer? customer;
              if (job.customerId != null) {
                final customers =
                    ref.read(customersStreamProvider).valueOrNull ?? [];
                customer = customers.cast<Customer?>().firstWhere(
                    (c) => c?.id == job.customerId,
                    orElse: () => null);
              }
              // Fallback: build a Customer from job fields if lookup failed
              customer ??= (job.customerName != null)
                  ? Customer(
                      id: job.customerId ?? '',
                      companyId: '',
                      name: job.customerName!,
                      email: '',
                      address: job.customerAddress,
                    )
                  : null;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CreateQuotationScreen(prefilledCustomer: customer),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('New Quote'),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 3: Invoices
// ─────────────────────────────────────────────────────────────────
class _InvoicesTab extends ConsumerWidget {
  final String jobId;
  final CalendarEvent job;
  const _InvoicesTab({required this.jobId, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final allInvoices = ref.watch(invoicesStreamProvider);

    return allInvoices.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (invoices) {
        final linked = invoices.where((i) => i.jobId == jobId).toList();
        return Scaffold(
          body: linked.isEmpty
              ? _EmptyState(
                  icon: Icons.receipt_outlined,
                  color: colorScheme.tertiary,
                  label: 'No invoices yet',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: linked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final inv = linked[i];
                    return _InvoiceTile(
                        invoice: inv,
                        onTap: () => context.push('/invoices/${inv.id}'));
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Customer? customer;
              if (job.customerId != null) {
                final customers =
                    ref.read(customersStreamProvider).valueOrNull ?? [];
                customer = customers.cast<Customer?>().firstWhere(
                    (c) => c?.id == job.customerId,
                    orElse: () => null);
              }
              // Fallback: build a Customer from job fields if lookup failed
              customer ??= (job.customerName != null)
                  ? Customer(
                      id: job.customerId ?? '',
                      companyId: '',
                      name: job.customerName!,
                      email: '',
                      address: job.customerAddress,
                    )
                  : null;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      CreateInvoiceScreen(prefilledCustomer: customer),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('New Invoice'),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 4: Expenses
// ─────────────────────────────────────────────────────────────────
class _ExpensesTab extends ConsumerWidget {
  final String jobId;
  final CalendarEvent job;
  const _ExpensesTab({required this.jobId, required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExpenses = ref.watch(expensesStreamProvider);

    return allExpenses.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (expenses) {
        final linked = expenses.where((e) => e.jobId == jobId).toList();
        return Scaffold(
          body: linked.isEmpty
              ? _EmptyState(
                  icon: Icons.payments_outlined,
                  color: Colors.orange,
                  label: 'No expenses yet',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: linked.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final exp = linked[i];
                    return _ExpenseTile(expense: exp);
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push(
              '/expenses/new',
              extra: {'jobId': jobId},
            ),
            icon: const Icon(Icons.add),
            label: const Text('Log Expense'),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 5: Media
// ─────────────────────────────────────────────────────────────────
class _MediaTab extends ConsumerStatefulWidget {
  final String jobId;
  final String companyId;
  const _MediaTab({required this.jobId, required this.companyId});

  @override
  ConsumerState<_MediaTab> createState() => _MediaTabState();
}

class _MediaTabState extends ConsumerState<_MediaTab> {
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                final f = await picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 85);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                final f = await picker.pickImage(
                    source: ImageSource.camera, imageQuality: 85);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () async {
                final f = await picker.pickVideo(source: ImageSource.camera);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      final repo = ref.read(jobMediaRepositoryProvider);
      final file = File(picked.path);
      final mimeType = picked.mimeType ??
          (picked.path.endsWith('.mp4') ? 'video/mp4' : 'image/jpeg');
      await repo.uploadMedia(
        jobId: widget.jobId,
        companyId: widget.companyId,
        createdBy: user.uid,
        file: file,
        filename: picked.name,
        mimeType: mimeType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteMedia(String mediaId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Media'),
        content: const Text('Remove this item permanently?'),
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
      await ref.read(jobMediaRepositoryProvider).deleteMedia(mediaId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaAsync = ref.watch(jobMediaStreamProvider(widget.jobId));

    return Scaffold(
      body: mediaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (mediaList) {
          if (mediaList.isEmpty) {
            return _EmptyState(
              icon: Icons.photo_library_outlined,
              color: colorScheme.secondary,
              label: 'No photos or videos yet',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: mediaList.length,
            itemBuilder: (_, i) {
              final m = mediaList[i];
              return GestureDetector(
                onLongPress: () => _deleteMedia(m.id),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: m.url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: colorScheme.surfaceContainerHigh),
                        errorWidget: (_, __, ___) => Container(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(Icons.broken_image,
                              color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      if (m.type == 'video')
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.play_arrow,
                                color: Colors.white, size: 20),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploading ? null : _pickAndUpload,
        child: _uploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.add_a_photo),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 6: Notes
// ─────────────────────────────────────────────────────────────────
class _NotesTab extends ConsumerStatefulWidget {
  final String jobId;
  final String companyId;
  const _NotesTab({required this.jobId, required this.companyId});

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  Future<void> _showAddNoteSheet() async {
    final controller = TextEditingController();
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Note',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write your note here...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    await ref.read(jobNoteRepositoryProvider).createNote(
                          jobId: widget.jobId,
                          companyId: widget.companyId,
                          content: text,
                          createdBy: user.uid,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Save Note'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteNote(String noteId) async {
    await ref.read(jobNoteRepositoryProvider).deleteNote(noteId);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final notesAsync = ref.watch(jobNotesStreamProvider(widget.jobId));

    return Scaffold(
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return _EmptyState(
              icon: Icons.sticky_note_2_outlined,
              color: Colors.amber.shade700,
              label: 'No notes yet',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final note = notes[i];
              return Dismissible(
                key: Key(note.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.delete_outline,
                      color: colorScheme.onErrorContainer),
                ),
                confirmDismiss: (_) => showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Note'),
                    content: const Text('Remove this note permanently?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ),
                onDismissed: (_) => _deleteNote(note.id),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.content, style: textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        note.createdAt != null
                            ? DateFormat('MMM d, yyyy h:mm a')
                                .format(note.createdAt!)
                            : '',
                        style: textTheme.labelSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteSheet,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────

class _MapEmbed extends StatefulWidget {
  final String address;
  const _MapEmbed({required this.address});

  @override
  State<_MapEmbed> createState() => _MapEmbedState();
}

class _MapEmbedState extends State<_MapEmbed> {
  late final WebViewController _controller;

  static const _mapsApiKey = 'AIzaSyB_1OUj1yUSw5JKyR3vdlB2MeyQK6S-FF8';

  @override
  void initState() {
    super.initState();
    final encoded = Uri.encodeComponent(widget.address);
    final embedUrl =
        'https://www.google.com/maps/embed/v1/place?key=$_mapsApiKey&q=$encoded';
    // Wrap in a minimal HTML page with an iframe — Embed API requires iframe context
    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body, html { width: 100%; height: 100%; overflow: hidden; }
  iframe { width: 100%; height: 100%; border: 0; display: block; }
</style>
</head>
<body>
<iframe
  src="$embedUrl"
  allowfullscreen
  loading="lazy"
  referrerpolicy="no-referrer-when-downgrade">
</iframe>
</body>
</html>''';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(html, baseUrl: 'https://www.google.com');
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 200,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _color(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (status) {
      case 'Completed':
        return Colors.green.shade600;
      case 'In Progress':
        return cs.primary;
      case 'Scheduled':
        return cs.secondary;
      case 'Cancelled':
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status,
          style:
              TextStyle(color: _color(context), fontWeight: FontWeight.w600)),
      backgroundColor: _color(context).withAlpha(26),
      side: BorderSide(color: _color(context).withAlpha(77)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _InfoCard(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
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
          child,
        ],
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _EmptyState(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withAlpha(77),
                  width: 1.5,
                  style: BorderStyle.solid),
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 16),
          Text(label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _QuotationTile extends StatelessWidget {
  final Quotation quotation;
  final VoidCallback onTap;
  const _QuotationTile({required this.quotation, required this.onTap});

  Color _statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (quotation.status) {
      case 'Accepted':
        return Colors.green.shade600;
      case 'Sent':
        return cs.primary;
      case 'Declined':
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.description_outlined,
              color: colorScheme.onPrimaryContainer, size: 20),
        ),
        title: Text(quotation.quotationNumber, style: textTheme.titleSmall),
        subtitle: Text(quotation.customerName,
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              NumberFormat.currency(symbol: r'$').format(quotation.total),
              style:
                  textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(quotation.status,
                style: textTheme.labelSmall
                    ?.copyWith(color: _statusColor(context))),
          ],
        ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  const _InvoiceTile({required this.invoice, required this.onTap});

  Color _statusColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (invoice.status) {
      case 'Paid':
        return Colors.green.shade600;
      case 'Overdue':
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.receipt_outlined,
              color: colorScheme.onTertiaryContainer, size: 20),
        ),
        title: Text(invoice.invoiceNumber, style: textTheme.titleSmall),
        subtitle: Text(invoice.customerName,
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              NumberFormat.currency(symbol: r'$').format(invoice.total),
              style:
                  textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(invoice.status,
                style: textTheme.labelSmall
                    ?.copyWith(color: _statusColor(context))),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  const _ExpenseTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.payments_outlined,
              color: Colors.orange, size: 20),
        ),
        title: Text(expense.merchant, style: textTheme.titleSmall),
        subtitle: Text(expense.category,
            style: textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant)),
        trailing: Text(
          NumberFormat.currency(symbol: r'$').format(expense.amount),
          style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
