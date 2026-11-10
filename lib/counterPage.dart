import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz/custom_counter.dart';

class myCounterPage extends StatelessWidget {
  const myCounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: .infinity,
        child: Row(
          crossAxisAlignment: .center,
          mainAxisAlignment: .center,
          children: [
            MyCounter(value:0,teamName: Text("Team A",style: TextStyle(fontWeight: .bold,fontSize: 24),)),
            SizedBox(width: 20,),
            MyCounter(value:0,teamName: Text("Team B",style: TextStyle(fontWeight: .bold,fontSize: 24),)),
          ],
        ),
      ),
    );
  }
}
