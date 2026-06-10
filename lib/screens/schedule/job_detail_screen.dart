import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/models.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../components/curved_header.dart';
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
import '../team/team_management_screen.dart' show teamMembersProvider;

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
      loading: () => const MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              CurvedHeader(title: 'Job Detail'),
              Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => MeshBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              const CurvedHeader(title: 'Job Detail'),
              Expanded(
                child: Center(child: Text('Error: $e')),
              ),
            ],
          ),
        ),
      ),
      data: (job) {
        if (job == null) {
          return const MeshBackground(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Column(
                children: [
                  CurvedHeader(title: 'Job Detail'),
                  Expanded(
                    child: Center(child: Text('Job not found')),
                  ),
                ],
              ),
            ),
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
  int _currentTabIndex = 0;

  static const _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Quotes'),
    Tab(text: 'Invoices'),
    Tab(text: 'Expenses'),
    Tab(text: 'Materials'),
    Tab(text: 'Signature'),
    Tab(text: 'Media'),
    Tab(text: 'Notes'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
  }

  void _showSignaturePad() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SignaturePadSheet(
        jobId: widget.job.id,
        companyId: widget.job.companyId,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brandGradientColors = isDark
        ? const [
            Color(0xFFBA6935), // Deep dark brand orange
            Color(0xFF9A5228), // Sunset amber dark
          ]
        : const [
            Color(0xFFF4781F), // Bright brand orange
            Color(0xFFFF9845), // Peach glow brand orange
          ];

    final hasSignature = widget.job.signatureUrl != null &&
        widget.job.signatureUrl!.isNotEmpty;

    return MeshBackground(
        child: Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _currentTabIndex == 0 && !hasSignature
          ? FloatingActionButton.extended(
              onPressed: _showSignaturePad,
              backgroundColor: const Color(0xFFF4781F),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.draw_outlined),
              label: const Text(
                'Get Signature',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor:
                isDark ? const Color(0xFFBA6935) : const Color(0xFFF4781F),
            foregroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
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
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/schedule');
                }
              },
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
                    colors: brandGradientColors,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(32),
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
              preferredSize: const Size.fromHeight(56),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: const Color(0xFFF4781F),
                    unselectedLabelColor: Colors.white,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tabs: _tabs,
                  ),
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
            _MaterialsTab(job: widget.job),
            _SignatureTab(job: widget.job),
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
class _OverviewTab extends ConsumerStatefulWidget {
  final CalendarEvent job;
  const _OverviewTab({required this.job});

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> {
  String _formatDuration(Duration d) {
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Future<void> _completeJob() async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.job.id)
          .update({'status': 'Completed'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing job: $e')),
        );
      }
    }
  }

  bool _uploading = false;
  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _uploading = true);
    try {
      final repo = ref.read(jobMediaRepositoryProvider);
      final file = File(picked.path);
      final companyId = widget.job.companyId.isNotEmpty
          ? widget.job.companyId
          : (ref.read(companyIdProvider) ?? '');

      await repo.uploadMedia(
        jobId: widget.job.id,
        companyId: companyId,
        createdBy: user.uid,
        file: file,
        filename: picked.name,
        mimeType: 'image/jpeg',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // Checklist Helpers
  List<Map<String, dynamic>> get _checklist {
    if (widget.job.checklist != null && widget.job.checklist!.isNotEmpty) {
      return widget.job.checklist!.map((item) {
        final m = Map<String, dynamic>.from(item as Map);
        // Normalise 'checked' — Firestore may return null for old documents
        m['checked'] = (m['checked'] as bool?) ?? false;
        return m;
      }).toList();
    }
    return [
      {'title': 'Site Survey', 'checked': false},
      {'title': 'Foundation Setup', 'checked': false},
      {'title': 'Wall Construction', 'checked': false},
      {'title': 'Inspection', 'checked': false},
    ];
  }

  Future<void> _updateChecklist(List<Map<String, dynamic>> list) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.job.id)
          .update({'checklist': list});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save checklist: $e')),
        );
      }
    }
  }

  void _toggleChecklistItem(int index, bool checked) {
    final list = _checklist;
    list[index]['checked'] = checked;
    _updateChecklist(list);
  }

  void _addChecklistItem(String title) {
    final list = _checklist;
    list.add({'title': title, 'checked': false});
    _updateChecklist(list);
  }

  void _deleteChecklistItem(int index) {
    final list = _checklist;
    list.removeAt(index);
    _updateChecklist(list);
  }

  void _editChecklistItem(int index, String newTitle) {
    final list = _checklist;
    list[index]['title'] = newTitle;
    _updateChecklist(list);
  }

  void _showAddItemDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Checklist Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter task title...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addChecklistItem(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(int index, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Checklist Item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter task title...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _editChecklistItem(index, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showManageTeamSheet() {
    final allMembers = ref.read(teamMembersProvider).valueOrNull ?? [];
    final currentAssigned = List<String>.from(widget.job.assignedUserIds ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setState2) {
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx3, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Text(
                        'Assign Team Members',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: allMembers.length,
                          itemBuilder: (context, i) {
                            final member = allMembers[i];
                            final isAssigned = currentAssigned.contains(member.uid);
                            return CheckboxListTile(
                              title: Text(member.displayName ?? member.email ?? 'Unknown'),
                              subtitle: Text(member.role),
                              value: isAssigned,
                              onChanged: (val) {
                                setState2(() {
                                  if (val == true) {
                                    currentAssigned.add(member.uid);
                                  } else {
                                    currentAssigned.remove(member.uid);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('events')
                                .doc(widget.job.id)
                                .update({'assignedUserIds': currentAssigned});
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: const Text('Save Assignments'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final start = DateTime.tryParse(widget.job.start);
    final end = DateTime.tryParse(widget.job.end);
    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    // Project value: sum of linked quotes
    final allQuotes = ref.watch(quotationsStreamProvider).valueOrNull ?? [];
    final linkedQuotes = allQuotes.where((q) => q.jobId == widget.job.id).toList();

    // Invoices list
    final allInvoices = ref.watch(invoicesStreamProvider).valueOrNull ?? [];
    final linkedInvoices = allInvoices.where((i) => i.jobId == widget.job.id).toList();

    final status = widget.job.status ?? 'Draft';

    final teamAsync = ref.watch(teamMembersProvider);
    final assignedIds = widget.job.assignedUserIds ?? [];
    final allMembers = teamAsync.valueOrNull ?? [];
    final assignedMembers = allMembers.where((m) => assignedIds.contains(m.uid)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      children: [
        // Summary Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.job.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (widget.job.customerName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Client: ${widget.job.customerName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.24),
                ),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Job Schedule Card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule & Details',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              // Date Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.calendar_month, color: colorScheme.outline, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          start != null ? '${dateFormat.format(start)}, ${timeFormat.format(start)}' : widget.job.start,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (start != null && end != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Estimated duration: ${_formatDuration(end.difference(start))}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Assigned Personnel Row with Avatars
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.group, color: colorScheme.outline, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                assignedMembers.isEmpty
                                    ? 'No team members assigned'
                                    : assignedMembers.map((m) => m.displayName ?? m.email ?? 'Unknown').join(', '),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: _showManageTeamSheet,
                            ),
                          ],
                        ),
                        if (assignedMembers.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 32,
                            child: Stack(
                              children: List.generate(assignedMembers.length, (idx) {
                                final member = assignedMembers[idx];
                                final name = member.displayName ?? member.email ?? '';
                                final initials = name.isNotEmpty
                                    ? (name.split(' ').length >= 2
                                        ? '${name.split(' ')[0][0]}${name.split(' ')[1][0]}'
                                        : name[0])
                                    : '?';
                                return Positioned(
                                  left: idx * 24.0,
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colorScheme.primaryContainer,
                                    child: Text(
                                      initials.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (widget.job.customerAddress != null && widget.job.customerAddress!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.job.customerAddress!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MapEmbed(address: widget.job.customerAddress!),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Checklist Timeline Card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Task Checklist',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showAddItemDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Task', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _checklist.length,
                itemBuilder: (context, index) {
                  final item = _checklist[index];
                  final isChecked = (item['checked'] as bool?) ?? false;

                  // Determine status:
                  // 1. Is it completed? (checked == true)
                  // 2. Is it active? (the first unchecked item)
                  // 3. Is it pending?
                  final isFirstUnchecked = !isChecked && _checklist.take(index).every((e) => e['checked'] == true);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // Custom checkbox button
                        InkWell(
                          onTap: () => _toggleChecklistItem(index, !isChecked),
                          borderRadius: BorderRadius.circular(100),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isChecked
                                  ? Colors.green
                                  : Colors.transparent,
                              border: Border.all(
                                color: isChecked
                                    ? Colors.green
                                    : (isFirstUnchecked ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.5)),
                                width: 2,
                              ),
                            ),
                            child: isChecked
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : (isFirstUnchecked
                                    ? Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                      )
                                    : null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${index + 1}. ${item['title']}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isFirstUnchecked ? FontWeight.w700 : FontWeight.w500,
                              color: isChecked
                                  ? colorScheme.onSurface.withValues(alpha: 0.5)
                                  : (isFirstUnchecked ? colorScheme.primary : colorScheme.onSurface),
                              decoration: isChecked ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          onPressed: () => _showEditItemDialog(index, item['title'] as String),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          onPressed: () => _deleteChecklistItem(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Associated Documents Card
        if (linkedQuotes.isNotEmpty || linkedInvoices.isNotEmpty)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Associated Documents',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (linkedQuotes.isNotEmpty) ...[
                  ...linkedQuotes.map((q) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.request_quote, color: colorScheme.outline),
                        title: Text('Quote #${q.quotationNumber.replaceFirst('Q-', '')}'),
                        subtitle: Text(NumberFormat.currency(symbol: '£').format(q.total)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/quotations/${q.id}'),
                      )),
                ],
                if (linkedInvoices.isNotEmpty) ...[
                  if (linkedQuotes.isNotEmpty) Divider(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ...linkedInvoices.map((inv) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.receipt_long, color: colorScheme.outline),
                        title: Text('Invoice #${inv.invoiceNumber.replaceFirst('INV-', '')}'),
                        subtitle: Text(NumberFormat.currency(symbol: '£').format(inv.total)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/invoices/${inv.id}'),
                      )),
                ],
              ],
            ),
          ),
        const SizedBox(height: 24),

        // Bottom Actions
        if (status != 'Completed') ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: _completeJob,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text(
                'Complete Job',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
                side: BorderSide(
                  color: colorScheme.outline,
                  width: 1.5,
                ),
              ),
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_a_photo, size: 18),
              label: const Text(
                'Upload Site Photos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ],
    );
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
// TAB 5: Materials Tracker
// ─────────────────────────────────────────────────────────────────
class _MaterialsTab extends ConsumerStatefulWidget {
  final CalendarEvent job;
  const _MaterialsTab({required this.job});

  @override
  ConsumerState<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends ConsumerState<_MaterialsTab> {
  List<Map<String, dynamic>> get _materials {
    final raw = widget.job.materials;
    if (raw != null && raw.isNotEmpty) {
      return List<Map<String, dynamic>>.from(
        raw.map((item) => Map<String, dynamic>.from(item as Map)),
      );
    }
    return [];
  }

  Future<void> _saveMaterials(List<Map<String, dynamic>> list) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.job.id)
          .update({'materials': list});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }

  void _showAddMaterialSheet() {
    final nameController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final unitController = TextEditingController();
    final costController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add Material',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Material Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: unitController,
                      decoration: InputDecoration(
                        labelText: 'Unit (e.g. kg, m)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: costController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cost (£)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  final list = _materials;
                  list.add({
                    'name': name,
                    'quantity': double.tryParse(qtyController.text) ?? 1,
                    'unit': unitController.text.trim(),
                    'cost': double.tryParse(costController.text.trim()) ?? 0,
                    'used': false,
                  });
                  _saveMaterials(list);
                  Navigator.pop(ctx);
                },
                child: const Text('Add Material'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleUsed(int index, bool used) {
    final list = _materials;
    list[index]['used'] = used;
    _saveMaterials(list);
  }

  void _deleteMaterial(int index) {
    final list = _materials;
    list.removeAt(index);
    _saveMaterials(list);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final materials = _materials;
    final totalCost = materials.fold<double>(
        0, (sum, m) => sum + ((m['cost'] as num?) ?? 0).toDouble() * ((m['quantity'] as num?) ?? 1).toDouble());

    return Scaffold(
      body: materials.isEmpty
          ? _EmptyState(
              icon: Icons.inventory_2_outlined,
              color: Colors.teal,
              label: 'No materials listed yet',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Total cost header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Material Cost',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withValues(alpha: 0.7))),
                      Text(
                        '£${totalCost.toStringAsFixed(2)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: colorScheme.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(materials.length, (index) {
                  final m = materials[index];
                  final isUsed = m['used'] == true;
                  return GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isUsed,
                          activeColor: Colors.teal,
                          onChanged: (v) =>
                              _toggleUsed(index, v ?? false),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['name'] as String? ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  decoration: isUsed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isUsed
                                      ? colorScheme.onSurface
                                          .withValues(alpha: 0.4)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Qty: ${m['quantity']} ${m['unit'] ?? ''}  •  £${((m['cost'] as num?) ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () => _deleteMaterial(index),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMaterialSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add Material'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TAB 6: Signature Capture
// ─────────────────────────────────────────────────────────────────
class _SignatureTab extends ConsumerStatefulWidget {
  final CalendarEvent job;
  const _SignatureTab({required this.job});

  @override
  ConsumerState<_SignatureTab> createState() => _SignatureTabState();
}

class _SignatureTabState extends ConsumerState<_SignatureTab> {
  String? get _signatureUrl => widget.job.signatureUrl;

  Future<void> _clearSignature() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Signature'),
        content: const Text(
            'Remove the existing signature? The client will need to sign again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.job.id)
          .update({'signatureUrl': FieldValue.delete()});
    }
  }

  void _showSignaturePad() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SignaturePadSheet(
        jobId: widget.job.id,
        companyId: widget.job.companyId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Client Sign-off',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture the client\'s signature to confirm job completion.',
                    style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 16),
                  if (_signatureUrl != null && _signatureUrl!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color:
                                colorScheme.outline.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _signatureUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Signed by client',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _clearSignature,
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colorScheme.error),
                            foregroundColor: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.3),
                            style: BorderStyle.solid),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.draw_outlined,
                              size: 48, color: colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            'No signature yet',
                            style: TextStyle(color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF4781F),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _showSignaturePad,
                        icon: const Icon(Icons.draw_outlined),
                        label: const Text('Capture Signature',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignaturePadSheet extends ConsumerStatefulWidget {
  final String jobId;
  final String companyId;
  const _SignaturePadSheet(
      {required this.jobId, required this.companyId});

  @override
  ConsumerState<_SignaturePadSheet> createState() =>
      _SignaturePadSheetState();
}

class _SignaturePadSheetState extends ConsumerState<_SignaturePadSheet> {
  final List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  bool _isSaving = false;

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _currentStroke = [d.localPosition];
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _currentStroke.add(d.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    setState(() {
      _strokes.add(List.from(_currentStroke));
      _currentStroke = [];
    });
  }

  void _clear() => setState(() {
        _strokes.clear();
        _currentStroke.clear();
      });

  bool get _hasSignature =>
      _strokes.isNotEmpty || _currentStroke.isNotEmpty;

  Future<void> _save() async {
    if (!_hasSignature) return;
    setState(() => _isSaving = true);

    try {
      // Render signature to PNG bytes using a RepaintBoundary
      final recorder = _SignatureRecorder(_strokes);
      final bytes = await recorder.toPng(300, 150);

      final storageRef = FirebaseStorage.instance
          .ref('signatures/${widget.companyId}/${widget.jobId}.png');
      await storageRef.putData(bytes,
          SettableMetadata(contentType: 'image/png'));
      final url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.jobId)
          .update({
        'signatureUrl': url,
        'signedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signature saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving signature: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sign Here',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Draw your signature above',
            style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4781F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: (_hasSignature && !_isSaving) ? _save : null,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Confirm & Save Signature',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  final List<Offset?> currentStroke;

  _SignaturePainter({required this.strokes, required this.currentStroke});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset?> points) {
      for (int i = 0; i < points.length - 1; i++) {
        final a = points[i];
        final b = points[i + 1];
        if (a != null && b != null) {
          canvas.drawLine(a, b, paint);
        }
      }
    }

    for (final stroke in strokes) {
      drawStroke(stroke);
    }
    drawStroke(currentStroke);
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}

class _SignatureRecorder {
  final List<List<Offset?>> strokes;
  _SignatureRecorder(this.strokes);

  Future<Uint8List> toPng(double width, double height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        Rect.fromLTWH(0, 0, width, height));

    // White background
    canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = Colors.white);

    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        final a = stroke[i];
        final b = stroke[i + 1];
        if (a != null && b != null) {
          canvas.drawLine(a, b, paint);
        }
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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
