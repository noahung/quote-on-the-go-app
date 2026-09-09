import 'package:flutter_test/flutter_test.dart';
import 'package:qotg_mobile/models/workflow.dart';
import 'package:qotg_mobile/models/workflow_execution.dart';

void main() {
  test('web trigger, step identity and email survive a mobile round trip', () {
    final template = WorkflowTemplate.fromJson({
      'id': 'template', 'name': 'Follow-up', 'type': 'custom', 'isActive': true, 'companyId': 'company',
      'trigger': {'type': 'quotation_sent', 'conditions': []},
      'steps': [{'id': 'web-step', 'order': 0, 'type': 'email', 'emailTemplate': {'subject': 'Hello', 'textContent': 'Follow up'}}],
    }).toJson();
    expect(template['trigger']['type'], 'quotation_sent');
    expect(template['steps'][0], isA<Map>());
    expect(template['steps'][0]['id'], 'web-step');
    expect(template['steps'][0]['emailTemplate']['textContent'], 'Follow up');
  });
  test('execution dates use the scheduler ISO format with nested maps', () {
    final execution = WorkflowExecution(id: 'run', workflowTemplateId: 'template', targetDocumentId: 'quote',
      targetType: 'quotation', companyId: 'company', nextExecutionAt: DateTime.utc(2026, 9, 9),
      executionLog: [ExecutionLogEntry(stepId: 'step', status: 'success', action: 'wait')]).toJson();
    expect(execution['nextExecutionAt'], '2026-09-09T00:00:00.000Z');
    expect(execution['executionLog'][0], isA<Map>());
  });
}
