import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/workflow.dart';
import '../../providers/providers.dart';
import '../../widgets/widgets.dart';

class WorkflowsScreen extends ConsumerWidget {
  const WorkflowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflowsAsync = ref.watch(workflowsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Workflows',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create workflow - coming soon')),
              );
            },
          ),
        ],
      ),
      body: workflowsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (workflows) {
          if (workflows.isEmpty) {
            return AppEmptyState(
              icon: Icons.auto_fix_high,
              title: 'No workflows yet',
              subtitle: 'Automate your follow-ups and reminders.',
              actionLabel: 'Create Workflow',
              onAction: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Create workflow - coming soon')),
                );
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workflows.length,
            itemBuilder: (context, index) {
              final workflow = workflows[index];
              return _WorkflowCard(workflow: workflow);
            },
          );
        },
      ),
    );
  }
}

class _WorkflowCard extends ConsumerWidget {
  final WorkflowTemplate workflow;

  const _WorkflowCard({required this.workflow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workflow.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (workflow.description != null &&
                      workflow.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      workflow.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: workflow.isActive
                              ? colorScheme.tertiaryContainer
                              : colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          workflow.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: workflow.isActive
                                ? colorScheme.onTertiaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        workflow.type.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Switch(
              value: workflow.isActive,
              onChanged: (value) {
                final repo = ref.read(workflowRepositoryProvider);
                repo.toggleWorkflowStatus(workflow.id, value);
              },
            ),
          ],
        ),
      ),
    );
  }
}
