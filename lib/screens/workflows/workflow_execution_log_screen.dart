import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../components/curved_header.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import '../../utils/feedback_controller.dart';

class WorkflowExecutionLogScreen extends ConsumerStatefulWidget {
  final String? workflowTemplateId;

  const WorkflowExecutionLogScreen({
    super.key,
    this.workflowTemplateId,
  });

  @override
  ConsumerState<WorkflowExecutionLogScreen> createState() =>
      _WorkflowExecutionLogScreenState();
}

class _WorkflowExecutionLogScreenState
    extends ConsumerState<WorkflowExecutionLogScreen> {
  String _filter = 'all';
  final Set<String> _expandedIds = {};

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;

    final executions = widget.workflowTemplateId != null
        ? ref.watch(workflowExecutionsForTemplateProvider(widget.workflowTemplateId!))
        : ref.watch(workflowExecutionsProvider);

    final filtered = _filter == 'all'
        ? executions
        : executions.where((e) => e.status == _filter).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(
            title: 'Execution Log',
            showBackButton: true,
            actions: [
              if (widget.workflowTemplateId != null)
                IconButton(
                  icon: const Icon(LucideIcons.play),
                  tooltip: 'Run workflow',
                  onPressed: () => _showRunWorkflowSheet(context),
                ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildFilterChips(colorScheme, isDark),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  _buildEmptyState(context)
                else
                  ...filtered.map((execution) => _buildExecutionCard(
                        context,
                        execution,
                        semanticColors,
                        isDark,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getFilterLabel(String filter) {
    if (filter == 'all') return 'All';
    if (filter == 'active') return 'Active';
    if (filter == 'success') return 'Success';
    if (filter == 'completed') return 'Completed';
    if (filter == 'failed') return 'Failed';
    if (filter == 'cancelled') return 'Cancelled';
    if (filter == 'stopped') return 'Stopped';
    if (filter == 'error') return 'Error';
    return filter[0].toUpperCase() + filter.substring(1);
  }

  Widget _buildFilterChips(ColorScheme colorScheme, bool isDark) {
    final filters = ['all', 'active', 'success', 'completed', 'failed', 'cancelled', 'stopped', 'error'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((status) {
          final selected = _filter == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                _getFilterLabel(status),
                style: TextStyle(
                  color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: selected,
              selectedColor: const Color(0xFFF4781F),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
              shape: const StadiumBorder(),
              side: BorderSide.none,
              onSelected: (_) => setState(() => _filter = status),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildExecutionCard(
    BuildContext context,
    WorkflowExecution execution,
    SemanticColors colors,
    bool isDark,
  ) {
    final isExpanded = _expandedIds.contains(execution.id);
    final statusColor = _statusColor(execution.status, colors);
    final dateFormat = DateFormat('d MMM, HH:mm');

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() {
          if (isExpanded) {
            _expandedIds.remove(execution.id);
          } else {
            _expandedIds.add(execution.id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusBadge(status: execution.status, colors: colors),
                  if (execution.retryCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Retries: ${execution.retryCount}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  _DocumentChip(
                    type: execution.targetType,
                    number: execution.targetDocumentNumber,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                execution.workflowName ?? 'Untitled Workflow',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(LucideIcons.user, size: 14, color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      execution.targetCustomerName ?? 'Unknown customer',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (execution.lastError != null && execution.lastError!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.alertTriangle, size: 14, color: colors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          execution.lastError!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Started ${execution.startedAt != null ? dateFormat.format(execution.startedAt!.toLocal()) : '-'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black45,
                    ),
                  ),
                  if (execution.status == 'active' && execution.nextExecutionAt != null)
                    Text(
                      'Next ${dateFormat.format(execution.nextExecutionAt!.toLocal())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                _buildLogTimeline(execution, colors, isDark),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (execution.status == 'active')
                      TextButton.icon(
                        onPressed: () => _stopExecution(context, execution.id),
                        icon: Icon(LucideIcons.square, size: 16, color: colors.error),
                        label: Text(
                          'Stop',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () => _deleteExecution(context, execution.id),
                      icon: Icon(LucideIcons.trash2, size: 16, color: colors.error),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogTimeline(
    WorkflowExecution execution,
    SemanticColors colors,
    bool isDark,
  ) {
    final entries = execution.executionLog;
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 18, color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black45),
            const SizedBox(width: 12),
            Text(
              'No steps have run yet.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: entries.asMap().entries.map((entry) {
        final index = entry.key;
        final log = entry.value;
        final isLast = index == entries.length - 1;
        final color = _statusColor(log.status, colors);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.stepName ?? log.action,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (log.details != null && log.details!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.details!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                  if (log.error != null && log.error!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      log.error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(LucideIcons.workflow, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No executions yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Run a workflow from a template to see the execution history here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status, SemanticColors colors) {
    switch (status) {
      case 'active':
        return Colors.blue;
      case 'completed':
      case 'success':
        return colors.success;
      case 'stopped':
      case 'cancelled':
        return Colors.orange;
      case 'error':
      case 'failed':
        return colors.error;
      default:
        return Colors.grey;
    }
  }

  Future<void> _stopExecution(BuildContext context, String executionId) async {
    try {
      await ref.read(workflowExecutionRepositoryProvider).stopExecution(executionId);
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Execution stopped');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to stop: $e');
      }
    }
  }

  Future<void> _deleteExecution(BuildContext context, String executionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete execution?'),
        content: const Text('This removes the execution log permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(workflowExecutionRepositoryProvider).deleteExecution(executionId);
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Execution deleted');
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Failed to delete: $e');
      }
    }
  }

  void _showRunWorkflowSheet(BuildContext context) {
    if (widget.workflowTemplateId == null) return;
    showRunWorkflowSheet(context, widget.workflowTemplateId!);
  }
}

void showRunWorkflowSheet(BuildContext context, String templateId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => RunWorkflowSheet(templateId: templateId),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final SemanticColors colors;

  const _StatusBadge({required this.status, required this.colors});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'active' => (Colors.blue, 'Active'),
      'completed' || 'success' => (colors.success, 'Success'),
      'stopped' || 'cancelled' => (Colors.orange, 'Cancelled'),
      'error' || 'failed' => (colors.error, 'Failed'),
      _ => (Colors.grey, status[0].toUpperCase() + status.substring(1)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DocumentChip extends StatelessWidget {
  final String type;
  final String? number;
  final bool isDark;

  const _DocumentChip({
    required this.type,
    required this.number,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final icon = type == 'quotation' ? LucideIcons.fileText : LucideIcons.receipt;
    final color = type == 'quotation' ? const Color(0xFFF4781F) : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            number ?? type[0].toUpperCase() + type.substring(1),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class RunWorkflowSheet extends ConsumerWidget {
  final String templateId;

  const RunWorkflowSheet({super.key, required this.templateId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final template = ref.watch(workflowTemplateProvider(templateId));
    final targets = ref.watch(workflowTargetDocumentsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Material(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 20,
              right: 20,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white30 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Run ${template?.name ?? 'Workflow'}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a quotation or invoice to run this workflow against.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: targets.isEmpty
                      ? _buildNoTargets(context)
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: targets.length,
                          itemBuilder: (context, index) {
                            final target = targets[index];
                            return _TargetTile(
                              target: target,
                              onTap: () => _startExecution(context, ref, template, target),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoTargets(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(LucideIcons.fileX, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No quotations or invoices available',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a quotation or invoice first.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startExecution(
    BuildContext context,
    WidgetRef ref,
    WorkflowTemplate? template,
    WorkflowTargetDocument target,
  ) async {
    final companyId = ref.read(companyIdProvider);
    if (companyId == null || template == null) return;

    Navigator.pop(context);

    try {
      await ref.read(workflowExecutionRepositoryProvider).startExecution(
            templateId: template.id,
            targetDocumentId: target.id,
            targetType: target.type,
            companyId: companyId,
            workflowName: template.name,
            targetDocumentNumber: target.number,
            targetCustomerName: target.customerName,
            steps: template.steps,
          );
      if (context.mounted) {
        ref.read(feedbackControllerProvider).success(
              context,
              'Workflow started for ${target.number}',
            );
      }
    } catch (e) {
      if (context.mounted) {
        ref.read(feedbackControllerProvider).error(
              context,
              'Failed to start workflow: $e',
            );
      }
    }
  }
}

class _TargetTile extends StatelessWidget {
  final WorkflowTargetDocument target;
  final VoidCallback onTap;

  const _TargetTile({required this.target, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final icon = target.type == 'quotation' ? LucideIcons.fileText : LucideIcons.receipt;
    final color = target.type == 'quotation' ? const Color(0xFFF4781F) : Colors.blue;
    final currency = NumberFormat.currency(symbol: '£', decimalDigits: 0);

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.number,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      target.customerName,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(target.total),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    target.status,
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
