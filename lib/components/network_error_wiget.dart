import 'package:flutter/material.dart';

import 'app_style.dart';

Widget networkError(){
  return Scaffold(
    backgroundColor: blackColor,
    body: Center(child: Text("Network error", style: TextStyle(fontSize: fo20,fontWeight: w500, color: whiteColor ),
    ),
    ),
  );
}