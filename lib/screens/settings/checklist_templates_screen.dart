import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../components/glass_card.dart';
import '../../components/mesh_background.dart';
import '../../models/checklist_template.dart';
import '../../providers/providers.dart';
import '../../theme/semantic_colors.dart';
import '../../utils/feedback_controller.dart';

class ChecklistTemplatesScreen extends ConsumerStatefulWidget {
  final bool isTab;
  const ChecklistTemplatesScreen({super.key, this.isTab = false});

  @override
  ConsumerState<ChecklistTemplatesScreen> createState() => _ChecklistTemplatesScreenState();
}

class _ChecklistTemplatesScreenState extends ConsumerState<ChecklistTemplatesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final List<TextEditingController> _itemControllers = [];

  ChecklistTemplate? _editingTemplate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _addItemField();
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addItemField() {
    setState(() {
      _itemControllers.add(TextEditingController());
    });
  }

  void _removeItemField(int index) {
    if (_itemControllers.length <= 1) return;
    setState(() {
      _itemControllers[index].dispose();
      _itemControllers.removeAt(index);
    });
  }

  void _startCreate() {
    setState(() {
      _editingTemplate = null;
      _nameController.clear();
      for (final controller in _itemControllers) {
        controller.dispose();
      }
      _itemControllers.clear();
      _addItemField();
    });
  }

  void _startEdit(ChecklistTemplate template) {
    setState(() {
      _editingTemplate = template;
      _nameController.text = template.name;

      for (final controller in _itemControllers) {
        controller.dispose();
      }
      _itemControllers.clear();

      if (template.items.isEmpty) {
        _addItemField();
      } else {
        for (final item in template.items) {
          _itemControllers.add(TextEditingController(text: item));
        }
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final companyId = ref.read(companyIdProvider);
    if (companyId == null) return;

    final name = _nameController.text.trim();
    final items = _itemControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (items.isEmpty) {
      ref.read(feedbackControllerProvider).warning(context, 'Please add at least one checklist item');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(checklistTemplateRepositoryProvider);

      if (_editingTemplate != null) {
        // Update existing
        await repository.updateTemplate(_editingTemplate!.id, name, items);
        if (mounted) {
          ref.read(feedbackControllerProvider).success(context, 'Template updated successfully');
        }
      } else {
        // Create new
        await repository.createTemplate(
          companyId: companyId,
          name: name,
          items: items,
        );
        if (mounted) {
          ref.read(feedbackControllerProvider).success(context, 'Template created successfully');
        }
      }

      _startCreate();
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete(ChecklistTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Are you sure you want to delete "${template.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(checklistTemplateRepositoryProvider);
      await repository.deleteTemplate(template.id);

      if (_editingTemplate?.id == template.id) {
        _startCreate();
      }

      if (mounted) {
        ref.read(feedbackControllerProvider).success(context, 'Template deleted');
      }
    } catch (e) {
      if (mounted) {
        ref.read(feedbackControllerProvider).error(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final semanticColors = Theme.of(context).extension<SemanticColors>()!;
    final templatesAsync = ref.watch(checklistTemplatesProvider);
    final userProfile = ref.watch(userProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final role = userProfile?.role.toLowerCase();
    final canEdit = role == 'owner' || role == 'admin';

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Description
        Text(
          'Create and manage pre-defined checklist templates to quickly apply checklist tasks to scheduled jobs.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),

        // Templates List
        _buildTemplatesList(templatesAsync, colorScheme, semanticColors, isDark, canEdit),
        const SizedBox(height: 20),

        // Create/Edit Form
        _buildForm(colorScheme, semanticColors, isDark, canEdit),
      ],
    );

    if (widget.isTab) {
      return body;
    }

    return MeshBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/settings');
              }
            },
          ),
          title: const Text(
            'Checklist Templates',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: body,
      ),
    );
  }

  Widget _buildTemplatesList(
    AsyncValue<List<ChecklistTemplate>> templatesAsync,
    ColorScheme colorScheme,
    SemanticColors semanticColors,
    bool isDark,
    bool canEdit,
  ) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Saved Templates',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                templatesAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (templates) => Text(
                    '${templates.length} templates',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
          templatesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('Error: $e')),
            ),
            data: (templates) {
              if (templates.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.listChecks,
                        size: 48,
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No templates yet',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create your first template below',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: templates.map((template) {
                  return _TemplateTile(
                    template: template,
                    colorScheme: colorScheme,
                    isDark: isDark,
                    isEditing: _editingTemplate?.id == template.id,
                    canEdit: canEdit,
                    onEdit: () => _startEdit(template),
                    onDelete: () => _delete(template),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    ColorScheme colorScheme,
    SemanticColors semanticColors,
    bool isDark,
    bool canEdit,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingTemplate != null ? 'Edit Template' : 'Create New Template',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _editingTemplate != null
                  ? 'Update template properties'
                  : 'Add a template for your crew to reference',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),

            // Template Name
            TextFormField(
              controller: _nameController,
              enabled: canEdit,
              decoration: InputDecoration(
                labelText: 'Template Name',
                hintText: 'e.g., HVAC Inspection, Carpet Cleaning Setup',
                prefixIcon: const Icon(Icons.label_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Template name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Checklist Items
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Checklist Items',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (canEdit)
                  TextButton.icon(
                    onPressed: _addItemField,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Item'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Item fields
            ...List.generate(_itemControllers.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _itemControllers[index],
                        enabled: canEdit,
                        decoration: InputDecoration(
                          hintText: 'Checklist item ${index + 1}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    if (canEdit && _itemControllers.length > 1)
                      IconButton(
                        icon: Icon(Icons.delete_outline, color: semanticColors.error),
                        onPressed: () => _removeItemField(index),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 20),

            // Action Buttons
            if (canEdit)
              Row(
                children: [
                  if (_editingTemplate != null)
                    OutlinedButton(
                      onPressed: _startCreate,
                      child: const Text('Cancel'),
                    ),
                  if (_editingTemplate != null)
                    const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(_editingTemplate != null ? LucideIcons.save : LucideIcons.plus),
                      label: Text(_isSaving
                          ? 'Saving...'
                          : (_editingTemplate != null ? 'Save Changes' : 'Create Template')),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  final ChecklistTemplate template;
  final ColorScheme colorScheme;
  final bool isDark;
  final bool isEditing;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateTile({
    required this.template,
    required this.colorScheme,
    required this.isDark,
    required this.isEditing,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        color: isEditing ? colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      ),
      child: ExpansionTile(
        title: Text(
          template.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isEditing ? colorScheme.primary : null,
          ),
        ),
        subtitle: Text(
          '${template.items.length} items',
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      LucideIcons.pencil,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    onPressed: onDelete,
                  ),
                ],
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(
                  height: 1,
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                ),
                const SizedBox(height: 12),
                ...template.items.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.checkCircle,
                          size: 18,
                          color: colorScheme.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 14,
                              color: colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
