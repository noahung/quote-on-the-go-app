import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;

  const StatusChip({
    super.key,
    required this.status,
    this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accepted':
      case 'Paid':
        return Colors.green;
      case 'Sent':
        return Colors.blue;
      case 'Declined':
      case 'Overdue':
        return Colors.red;
      case 'Draft':
        return Colors.orange;
      case 'Amended':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
