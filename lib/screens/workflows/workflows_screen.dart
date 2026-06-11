import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/curved_header.dart';
import '../../models/workflow.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import 'create_workflow_screen.dart';

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
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFFF4781F),
                  labelColor: const Color(0xFFF4781F),
                  unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
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
          ],
        ],
      ),
    );
  }

  Widget _buildSequenceVisualizer(
    BuildContext context,
    WorkflowTemplate workflow,
    SemanticColors colors,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Automation Sequence Steps:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF4781F)),
        ),
        const SizedBox(height: 16),
        _buildStepNode(
          context,
          title: 'Trigger: Quote Sent',
          desc: 'Email initiated instantly to customer.',
          icon: LucideIcons.send,
          isFirst: true,
          colors: colors,
        ),
        _buildStepConnector('Wait: 3 Business Days'),
        _buildStepNode(
          context,
          title: 'Gentle Reminder Email',
          desc: 'Email: "Following up on your quotation".',
          icon: LucideIcons.mail,
          colors: colors,
        ),
        _buildStepConnector('Wait: 5 Business Days'),
        _buildStepNode(
          context,
          title: 'Final Offer SMS',
          desc: 'SMS Text reminder with 5% limited discount.',
          icon: LucideIcons.messageSquare,
          isLast: true,
          colors: colors,
        ),
      ],
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

  Widget _buildLibraryTab(BuildContext context, SemanticColors colors, bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildLibraryCard(
          context,
          colors,
          isDark,
          title: 'High-Value Client Sequence',
          desc: 'Special high-touch delay triggers and customized premium emails designed for corporate jobs.',
          trigger: 'QUOTE SENT > £5,000',
        ),
        _buildLibraryCard(
          context,
          colors,
          isDark,
          title: 'Invoice Overdue Automated Alert',
          desc: 'Triggers 3 emails and an SMS over 14 days when invoices pass the due date.',
          trigger: 'INVOICE OVERDUE 1 DAY',
        ),
        _buildLibraryCard(
          context,
          colors,
          isDark,
          title: 'Quick Feedback Collection',
          desc: 'Sends a polite satisfaction survey link 2 days after payment confirmation.',
          trigger: 'INVOICE PAID',
        ),
      ],
    );
  }

  Widget _buildLibraryCard(
    BuildContext context,
    SemanticColors colors,
    bool isDark, {
    required String title,
    required String desc,
    required String trigger,
  }) {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Trigger: $trigger',
                    style: TextStyle(color: colors.success, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton(
                  onPressed: () {},
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
