import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_style.dart';

class CommonButton extends StatelessWidget {
  final double? height;
  final VoidCallback onTap;
  final Color? color;
  final dynamic child;
  const CommonButton({super.key, this.height, required this.onTap, this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height??45,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: whiteColor,
          backgroundColor: color??greenColor,
        ),
        child: child,
      ),
    );
  }
}