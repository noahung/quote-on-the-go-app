import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(size * .3),
      child: Image.asset('assets/images/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true));
}
