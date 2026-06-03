import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double padding;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 64,
    this.padding = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.healing_outlined,
        size: size,
        color: primaryColor,
      ),
    );
  }
}
