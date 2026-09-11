import 'package:flutter/material.dart';
import '../services/draft_session.dart';

class DraftStatusBanner extends StatelessWidget {
  const DraftStatusBanner(
      {super.key, required this.session, required this.onRestore});
  final DraftSession? session;
  final VoidCallback onRestore;
  @override
  Widget build(BuildContext context) {
    final state = session;
    final theme = Theme.of(context);
    final message = state == null
        ? 'Preparing your draft…'
        : state.error ??
            (!state.ready
                ? 'Checking for saved work…'
                : state.recovery != null
                    ? 'You have unfinished work saved on this device.'
                    : state.saving
                        ? 'Saving on this device…'
                        : state.saved
                            ? 'Saved on this device. Use Save draft to sync it.'
                            : 'Changes are saved on this device as you work.');
    return Semantics(
        liveRegion: true,
        child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(message, style: theme.textTheme.bodyMedium),
              if (state?.recovery != null)
                Wrap(spacing: 12, children: [
                  TextButton(
                      onPressed: onRestore, child: const Text('Restore draft')),
                  TextButton(
                      onPressed: state!.saving ? null : state.discardRecovery,
                      child: const Text('Start fresh')),
                ])
              else if (state?.error != null) ...[
                TextButton(
                    onPressed: () {
                      if (state!.ready) {
                        state.flush();
                      } else {
                        state.load();
                      }
                    },
                    child: const Text('Try again')),
                if (!state!.ready)
                  TextButton(
                    onPressed: state.saving
                        ? null
                        : () async {
                            final discard = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                      title: const Text(
                                          'Discard the saved draft?'),
                                      content: const Text(
                                          'The unreadable copy on this device will be removed. This cannot be undone.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Keep draft')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Discard draft'))
                                      ],
                                    ));
                            if (discard == true) await state.discardRecovery();
                          },
                    child: const Text('Discard unreadable draft'),
                  ),
              ],
            ])));
  }
}
