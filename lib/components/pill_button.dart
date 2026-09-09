import 'package:flutter/material.dart';

/// Primary action with native focus, disabled state and accessibility semantics.
class PillButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  final IconData? icon;
  const PillButton({super.key, required this.text, this.onTap, this.isLoading = false, this.icon});
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: isLoading ? null : onTap,
    style: FilledButton.styleFrom(minimumSize: const Size(48, 52),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: const StadiumBorder()),
    child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (isLoading) ...[
        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
      ] else if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 10)],
      Flexible(child: Text(isLoading ? '$text…' : text, textAlign: TextAlign.center)),
    ]),
  );
}
