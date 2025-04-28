import 'package:flutter/material.dart';
import 'package:videos_alarm_app/components/app_style.dart';

class LoaderWidget extends StatelessWidget {
  const LoaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: whiteColor,
      ),
    );
  }
}
