import 'package:flutter/material.dart';

class TopPanel extends StatelessWidget{
  const TopPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent)
      ),
      child: Column(

      ),
    );
  }
}