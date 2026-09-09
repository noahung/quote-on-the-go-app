import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import 'job_detail_screen.dart';
import 'create_job_screen.dart';

class JobEditScreen extends ConsumerWidget {
  final String id;
  const JobEditScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(jobDetailProvider(id))
      .when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => Scaffold(
            appBar: AppBar(title: const Text('Edit job')),
            body: Center(
                child: FilledButton(
                    onPressed: () => ref.invalidate(jobDetailProvider(id)),
                    child: const Text('Could not load job. Retry')))),
        data: (event) =>
            event == null || event.companyId != ref.watch(companyIdProvider)
                ? Scaffold(
                    appBar: AppBar(title: const Text('Edit job')),
                    body: const Center(child: Text('This job is unavailable.')))
                : CreateJobScreen(event: event),
      );
}
