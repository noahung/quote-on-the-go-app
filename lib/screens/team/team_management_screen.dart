import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../models/models.dart';
import '../../providers/providers.dart';

// Stream all users in the same company
final teamMembersProvider = StreamProvider<List<UserProfile>>((ref) {
  final companyId = ref.watch(companyIdProvider);
  if (companyId == null) return Stream.value([]);
  return FirebaseFirestore.instance
      .collection('users')
      .where('companyId', isEqualTo: companyId)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => UserProfile.fromFirestore(d)).toList());
});

class TeamManagementScreen extends ConsumerWidget {
  const TeamManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentUser = ref.watch(userProfileProvider);
    final teamAsync = ref.watch(teamMembersProvider);

    final isOwner =
        currentUser?.role == 'owner' || currentUser?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Team Management',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Invite member',
              onPressed: () => _showInviteDialog(context, ref),
            ),
        ],
      ),
      body: teamAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (members) {
          if (members.isEmpty) {
            return _EmptyTeam(
                isOwner: isOwner,
                onInvite: () => _showInviteDialog(context, ref));
          }

          // Sort: owners first, then admins, then members
          final sorted = [...members]..sort((a, b) {
              const order = {'owner': 0, 'admin': 1, 'member': 2};
              return (order[a.role] ?? 3).compareTo(order[b.role] ?? 3);
            });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Card(
                elevation: 0,
                color: colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.group_outlined,
                          color: colorScheme.primary, size: 32),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${members.length} Team Member${members.length == 1 ? '' : 's'}',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '${members.where((m) => m.role == 'owner' || m.role == 'admin').length} admin(s)',
                            style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withOpacity(0.75)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (isOwner)
                        FilledButton.tonal(
                          onPressed: () => _showInviteDialog(context, ref),
                          child: const Text('Invite'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Member list
              ...sorted.map((member) => _MemberTile(
                    member: member,
                    isCurrentUser: member.uid == currentUser?.uid,
                    canManage: isOwner && member.uid != currentUser?.uid,
                    onRoleChange: (newRole) =>
                        _updateRole(context, ref, member.uid, newRole),
                    onRemove: () => _confirmRemove(context, ref, member),
                  )),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context, WidgetRef ref) async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedRole = 'member';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite Team Member',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('They\'ll receive an email invitation to join.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              StatefulBuilder(builder: (ctx2, setState2) {
                return DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.manage_accounts_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Member')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) =>
                      setState2(() => selectedRole = v ?? 'member'),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(ctx);
                      final email = emailController.text.trim();
                      final companyId = ref.read(companyIdProvider);
                      final currentUser = ref.read(userProfileProvider);
                      final inviterName = currentUser?.displayName ??
                          currentUser?.email ??
                          'Admin';

                      if (companyId == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Company not found')),
                          );
                        }
                        return;
                      }

                      try {
                        const apiUrl =
                            'https://app.quoteonthego.co.uk/api/invite-team-member';
                        final response = await http.post(
                          Uri.parse(apiUrl),
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            'companyId': companyId,
                            'email': email,
                            'role': selectedRole,
                            'inviterName': inviterName,
                          }),
                        );
                        final result =
                            jsonDecode(response.body) as Map<String, dynamic>;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['success'] == true
                                    ? 'Invitation sent to $email'
                                    : 'Error: ${result['error'] ?? 'Unknown error'}',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error sending invitation: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Send Invitation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateRole(
      BuildContext context, WidgetRef ref, String uid, String newRole) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'role': newRole});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Role updated successfully')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, UserProfile member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Remove ${member.displayName ?? member.email ?? 'this member'} from your team?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed — coming soon')),
      );
    }
  }
}

class _MemberTile extends StatelessWidget {
  final UserProfile member;
  final bool isCurrentUser;
  final bool canManage;
  final void Function(String) onRoleChange;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.canManage,
    required this.onRoleChange,
    required this.onRemove,
  });

  String get _initials {
    final name = member.displayName ?? member.email ?? '';
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  Color _roleColor(ColorScheme cs) {
    switch (member.role) {
      case 'owner':
        return cs.primary;
      case 'admin':
        return cs.secondary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  Color _roleBg(ColorScheme cs) {
    switch (member.role) {
      case 'owner':
        return cs.primaryContainer;
      case 'admin':
        return cs.secondaryContainer;
      default:
        return cs.surfaceContainerHighest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color:
          isCurrentUser ? colorScheme.surfaceContainerLow : colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colorScheme.primaryContainer,
          child: Text(_initials,
              style: TextStyle(
                  color: colorScheme.primary, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.displayName ?? member.email ?? 'Unknown',
                style:
                    textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('You',
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant)),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (member.email != null)
              Text(member.email!,
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _roleBg(colorScheme),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                member.role.substring(0, 1).toUpperCase() +
                    member.role.substring(1),
                style: textTheme.labelSmall?.copyWith(
                    color: _roleColor(colorScheme),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'remove') {
                    onRemove();
                  } else {
                    onRoleChange(value);
                  }
                },
                itemBuilder: (_) => [
                  if (member.role != 'admin')
                    const PopupMenuItem(
                        value: 'admin', child: Text('Make Admin')),
                  if (member.role != 'member')
                    const PopupMenuItem(
                        value: 'member', child: Text('Make Member')),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _EmptyTeam extends StatelessWidget {
  final bool isOwner;
  final VoidCallback onInvite;
  const _EmptyTeam({required this.isOwner, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add_outlined,
                size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text('No team members yet',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Invite colleagues to collaborate on quotes and invoices.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant)),
            if (isOwner) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Invite Member'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
