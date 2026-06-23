import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/curved_header.dart';
import '../../models/workflow.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import 'create_workflow_screen.dart';
import 'workflow_execution_log_screen.dart';

class WorkflowsScreen extends ConsumerStatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  ConsumerState<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends ConsumerState<WorkflowsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _expandedWorkflowIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedWorkflowIds.contains(id)) {
        _expandedWorkflowIds.remove(id);
      } else {
        _expandedWorkflowIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final workflowsAsync = ref.watch(workflowsStreamProvider);
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          CurvedHeader(
            title: 'Workflows',
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.history, color: Colors.white),
                tooltip: 'Execution log',
                onPressed: () => context.push('/workflows/executions'),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateWorkflowScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
            const SizedBox(height: 16),
            // Tab Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: const Color(0xFFF4781F),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.white70 : Colors.black87,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Active Sequences'),
                    Tab(text: 'Template Library'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Active Sequences Tab
                  workflowsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                    data: (workflows) {
                      if (workflows.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: workflows.length,
                        itemBuilder: (context, index) {
                          final workflow = workflows[index];
                          final isExpanded = _expandedWorkflowIds.contains(workflow.id);
                          return _buildWorkflowCard(context, workflow, isExpanded, semanticColors, isDark);
                        },
                      );
                    },
                  ),

                  // Template Library Tab
                  _buildLibraryTab(context, semanticColors, isDark),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildWorkflowCard(
    BuildContext context,
    WorkflowTemplate workflow,
    bool isExpanded,
    SemanticColors colors,
    bool isDark,
  ) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              workflow.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (workflow.description != null && workflow.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    workflow.description!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: workflow.isActive
                            ? colors.success.withValues(alpha: 0.12)
                            : Colors.grey.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        workflow.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: workflow.isActive ? colors.success : Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      workflow.type.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: workflow.isActive,
                  activeThumbColor: const Color(0xFFF4781F),
                  onChanged: (value) {
                    ref.read(workflowRepositoryProvider).toggleWorkflowStatus(workflow.id, value);
                  },
                ),
                IconButton(
                  icon: Icon(isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown),
                  onPressed: () => _toggleExpanded(workflow.id),
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildSequenceVisualizer(context, workflow, colors, isDark),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/workflows/${workflow.id}/executions',
                      ),
                      icon: const Icon(LucideIcons.history, size: 16),
                      label: const Text('View Log'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12),
                        ),
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: workflow.isActive
                          ? () => showRunWorkflowSheet(context, workflow.id)
                          : null,
                      icon: const Icon(LucideIcons.play, size: 16),
                      label: const Text('Run Now'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF4781F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _stepIcon(String type) {
    switch (type) {
      case 'send_email':
        return LucideIcons.mail;
      case 'send_sms':
        return LucideIcons.messageSquare;
      case 'wait':
        return LucideIcons.clock;
      default:
        return LucideIcons.zap;
    }
  }

  String _stepTitle(WorkflowStep step) {
    switch (step.type) {
      case 'send_email':
        return step.subject != null && step.subject!.isNotEmpty
            ? 'Email: ${step.subject}'
            : 'Send Email';
      case 'send_sms':
        return step.subject != null && step.subject!.isNotEmpty
            ? 'SMS: ${step.subject}'
            : 'Send SMS';
      case 'wait':
        final d = step.waitDays ?? 1;
        return 'Wait $d ${d == 1 ? 'day' : 'days'}';
      default:
        return step.type.replaceAll('_', ' ');
    }
  }

  String _stepDesc(WorkflowStep step) {
    switch (step.type) {
      case 'send_email':
        return step.body != null && step.body!.isNotEmpty ? step.body! : 'Email message';
      case 'send_sms':
        return 'SMS notification to customer';
      case 'wait':
        return 'Pause before next action';
      default:
        return '';
    }
  }

  Widget _buildSequenceVisualizer(
    BuildContext context,
    WorkflowTemplate workflow,
    SemanticColors colors,
    bool isDark,
  ) {
    final steps = List<WorkflowStep>.from(workflow.steps)
      ..sort((a, b) => a.order.compareTo(b.order));

    if (steps.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No steps defined for this workflow.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final widgets = <Widget>[
      const Text(
        'Automation Sequence Steps:',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF4781F)),
      ),
      const SizedBox(height: 16),
    ];

    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      widgets.add(_buildStepNode(
        context,
        title: _stepTitle(step),
        desc: _stepDesc(step),
        icon: _stepIcon(step.type),
        isFirst: i == 0,
        isLast: i == steps.length - 1,
        colors: colors,
      ));
      if (step.type == 'wait' && i < steps.length - 1) {
        final d = step.waitDays ?? 1;
        widgets.add(_buildStepConnector('Wait: $d ${d == 1 ? 'day' : 'days'}'));
      } else if (i < steps.length - 1) {
        widgets.add(_buildStepConnector('then'));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildStepNode(
    BuildContext context, {
    required String title,
    required String desc,
    required IconData icon,
    bool isFirst = false,
    bool isLast = false,
    required SemanticColors colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4781F).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFFF4781F), size: 18),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(String delay) {
    return Padding(
      padding: const EdgeInsets.only(left: 17.0, top: 4, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 30,
            color: Colors.black12,
          ),
          const SizedBox(width: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              delay,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  static const List<Map<String, dynamic>> _kTemplates = [
    {
      'title': 'High-Value Client Sequence',
      'desc': 'Special high-touch delay triggers and customized premium emails designed for corporate jobs.',
      'trigger': 'QUOTE SENT > £5,000',
      'type': 'quotation_sent',
      'steps': [
        {'order': 0, 'type': 'send_email', 'subject': 'Your Quotation is Ready', 'body': 'Dear customer, please find your tailored quotation attached.'},
        {'order': 1, 'type': 'wait', 'waitDays': 3},
        {'order': 2, 'type': 'send_email', 'subject': 'Following Up on Your Quotation', 'body': 'Just checking in — we would love to help with your project.'},
        {'order': 3, 'type': 'wait', 'waitDays': 5},
        {'order': 4, 'type': 'send_sms', 'subject': 'Final reminder: your quote is still valid. Reply to confirm.'},
      ],
    },
    {
      'title': 'Invoice Overdue Automated Alert',
      'desc': 'Triggers 3 emails and an SMS over 14 days when invoices pass the due date.',
      'trigger': 'INVOICE OVERDUE 1 DAY',
      'type': 'invoice_overdue',
      'steps': [
        {'order': 0, 'type': 'send_email', 'subject': 'Invoice Overdue Reminder', 'body': 'Your invoice is now overdue. Please arrange payment at your earliest convenience.'},
        {'order': 1, 'type': 'wait', 'waitDays': 3},
        {'order': 2, 'type': 'send_email', 'subject': 'Second Overdue Notice', 'body': 'This is a second reminder that your invoice remains unpaid.'},
        {'order': 3, 'type': 'wait', 'waitDays': 7},
        {'order': 4, 'type': 'send_sms', 'subject': 'Urgent: Invoice overdue. Please contact us immediately.'},
        {'order': 5, 'type': 'wait', 'waitDays': 4},
        {'order': 6, 'type': 'send_email', 'subject': 'Final Overdue Notice', 'body': 'We have not received payment. This is our final notice before further action.'},
      ],
    },
    {
      'title': 'Quick Feedback Collection',
      'desc': 'Sends a polite satisfaction survey link 2 days after payment confirmation.',
      'trigger': 'INVOICE PAID',
      'type': 'invoice_paid',
      'steps': [
        {'order': 0, 'type': 'wait', 'waitDays': 2},
        {'order': 1, 'type': 'send_email', 'subject': 'How Did We Do?', 'body': 'Thank you for your payment! We would love your feedback — it only takes 1 minute.'},
      ],
    },
  ];

  Widget _buildLibraryTab(BuildContext context, SemanticColors colors, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: _kTemplates
          .map((t) => _buildLibraryCard(context, colors, isDark, template: t))
          .toList(),
    );
  }

  Widget _buildLibraryCard(
    BuildContext context,
    SemanticColors colors,
    bool isDark, {
    required Map<String, dynamic> template,
  }) {
    final title = template['title'] as String;
    final desc = template['desc'] as String;
    final trigger = template['trigger'] as String;
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Trigger: $trigger',
                      style: TextStyle(color: colors.success, fontSize: 9, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _useTemplate(context, template),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFF4781F)),
                    foregroundColor: const Color(0xFFF4781F),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Use Template'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _useTemplate(BuildContext context, Map<String, dynamic> template) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateWorkflowScreen(prefillTemplate: template),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_mode, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No active sequences',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a preconfigured template from the Library tab to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                _tabController.animateTo(1);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4781F),
              ),
              child: const Text('Browse Library'),
            ),
          ],
        ),
      ),
    );
  }
}
