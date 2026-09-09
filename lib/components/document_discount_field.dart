import 'package:flutter/material.dart';

class DocumentDiscountField extends StatefulWidget {
  final double value;
  final String type;
  final ValueChanged<double> onValueChanged;
  final ValueChanged<String> onTypeChanged;

  const DocumentDiscountField({super.key, required this.value, required this.type,
    required this.onValueChanged, required this.onTypeChanged});

  @override
  State<DocumentDiscountField> createState() => _DocumentDiscountFieldState();
}

class _DocumentDiscountFieldState extends State<DocumentDiscountField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value == 0 ? '' : widget.value.toString());

  @override
  void didUpdateWidget(covariant DocumentDiscountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((double.tryParse(_controller.text) ?? 0) != widget.value) {
      _controller.text = widget.value == 0 ? '' : widget.value.toString();
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: TextFormField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Discount', hintText: '0',
          suffixText: widget.type == 'percentage' ? '%' : 'GBP'),
        onChanged: (text) => widget.onValueChanged(double.tryParse(text) ?? 0),
      )),
      const SizedBox(width: 12),
      Expanded(child: DropdownButtonFormField<String>(
        key: ValueKey(widget.type),
        initialValue: widget.type,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Discount type'),
        items: const [DropdownMenuItem(value: 'percentage', child: Text('Percentage')),
          DropdownMenuItem(value: 'fixed', child: Text('Fixed amount'))],
        onChanged: (value) { if (value != null) widget.onTypeChanged(value); },
      )),
    ]),
  );
}
