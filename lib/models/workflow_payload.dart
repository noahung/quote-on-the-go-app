/// Compatibility boundary for saved workflows and library prefills.
/// Invalid structure is rejected instead of silently changing automation intent.
Map<String, dynamic> normalizeWorkflowPayload(Map<String, dynamic> input) {
  Map<String, dynamic> object(Object? value, String label) {
    if (value == null) return {};
    if (value is! Map || value.keys.any((key) => key is! String)) {
      throw FormatException('$label must be an object.');
    }
    return Map<String, dynamic>.from(value);
  }

  String text(Object? value, String label, [String fallback = '']) {
    if (value == null) return fallback;
    if (value is! String) throw FormatException('$label must be text.');
    return value;
  }

  int? integer(Object? value, String label, {int max = 365}) {
    if (value == null) return null;
    final number = value is num ? value : num.tryParse(value.toString());
    if (number == null || !number.isFinite || number != number.roundToDouble() || number < 0 || number > max) {
      throw FormatException('$label must be a whole number between 0 and $max.');
    }
    return number.toInt();
  }

  List<dynamic> list(Object? value, String label) {
    if (value == null) return [];
    if (value is! List) throw FormatException('$label must be a list.');
    return value;
  }

  final rawTrigger = input['trigger'];
  final trigger = rawTrigger is String ? <String, dynamic>{} : object(rawTrigger, 'Trigger');
  final type = text(trigger['type'] ?? trigger['event'] ?? input['triggerEvent'] ??
      (rawTrigger is String && rawTrigger.contains('_') ? rawTrigger : input['type']), 'Trigger');
  final conditions = list(trigger['conditions'] ?? input['conditions'], 'Conditions').map((raw) {
    final c = object(raw, 'Condition');
    final field = text(c['field'], 'Condition field');
    final operator = text(c['operator'], 'Condition operator', 'equals');
    if (field.trim().isEmpty || !['equals', 'not_equals', 'greater_than', 'less_than', 'contains'].contains(operator) ||
        c['value'] == null || c['value'] is Map || c['value'] is List) {
      throw const FormatException('Each condition needs a field, supported comparison and value.');
    }
    return {...c, 'field': field, 'operator': operator, 'value': c['value'].toString()};
  }).toList();
  final steps = list(input['steps'], 'Steps').asMap().entries.map((entry) {
    if (entry.value == null) throw const FormatException('A workflow step is missing.');
    final s = object(entry.value, 'Step');
    final kind = text(s['type'], 'Step type');
    final email = object(s['emailTemplate'], 'Email template');
    final notification = object(s['notificationConfig'], 'Notification');
    final delay = object(s['delay'], 'Delay');
    final unit = text(delay['type'], 'Delay unit', 'days');
    if (!['hours', 'days', 'business_days'].contains(unit)) throw const FormatException('Unsupported delay unit.');
    final delayValue = integer(delay['value'] ?? s['waitDays'], 'Delay');
    final subject = text(email['subject'] ?? notification['title'] ?? s['subject'] ?? s['title'], 'Subject');
    final body = text(email['textContent'] ?? notification['message'] ?? s['body'] ?? s['message'], 'Message');
    if (email['includeOriginalDocument'] != null && email['includeOriginalDocument'] is! bool) {
      throw const FormatException('The PDF attachment option must be true or false.');
    }
    return {
      ...s,
      'id': text(s['id'], 'Step ID', 'step_${entry.key}'),
      'name': text(s['name'], 'Step name'),
      'order': integer(s['order'], 'Step order', max: 10000) ?? entry.key,
      'type': kind == 'send_email' ? 'email' : kind,
      'subject': subject, 'body': body,
      'emailTemplate': kind == 'email' || kind == 'send_email' ? {
        ...email, 'subject': subject, 'textContent': body,
        'htmlContent': text(email['htmlContent'], 'Email HTML'),
        'includeOriginalDocument': email['includeOriginalDocument'] ?? false,
      } : null,
      'notificationConfig': notification,
      'waitDays': integer(s['waitDays'], 'Wait days'),
      'delay': delay.isNotEmpty || delayValue != null || kind == 'wait'
          ? {'type': unit, 'value': delayValue ?? 1} : null,
    };
  }).toList()..sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
  final active = input['isActive'];
  if (active != null && active is! bool) throw const FormatException('Active must be true or false.');
  return {
    ...input,
    'id': text(input['id'], 'Workflow ID'),
    'name': text(input['name'] ?? input['title'], 'Name'),
    'description': text(input['description'] ?? input['desc'], 'Description'),
    'companyId': text(input['companyId'], 'Company'),
    'type': text(input['type'], 'Workflow type', 'custom'),
    'trigger': {...trigger, 'type': type, 'conditions': conditions},
    'triggerEvent': type, 'conditions': conditions, 'steps': steps,
    'isActive': active ?? true,
    'maxRetries': integer(input['maxRetries'], 'Retries', max: 5),
    'retryDelaySeconds': integer(input['retryDelaySeconds'], 'Retry delay', max: 86400),
    'onFailureAction': input['onFailureAction'] == null ? null : text(input['onFailureAction'], 'Failure action'),
  };
}
