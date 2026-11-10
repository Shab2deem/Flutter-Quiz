import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MyCounter extends StatefulWidget {
  Text teamName ;
  int value;
  int firstButtonValue;
  int secondButtonValue;
  int thirdButtonValue;

   MyCounter({super.key,required this.teamName,required this.value, this.firstButtonValue=1,this.secondButtonValue=2,this.thirdButtonValue=3});

  @override
  State<MyCounter> createState() => _MyCounterState();
}

class _MyCounterState extends State<MyCounter> {

  @override
  Widget build(BuildContext context) {
    return Container(

      width: 200,
      height: 240,
      child: Card(

        color: Colors.red,
        child: Column(
          mainAxisAlignment: .spaceEvenly,
          children: [
            SizedBox(height: 5,),
            widget.teamName,
            SizedBox(height: 20,),
            Text(widget.value.toString(),style: TextStyle(fontWeight: .bold,fontSize: 22),),
            SizedBox(height: 20,),
            ElevatedButton(onPressed: (){setState(() {
              widget.value+=widget.firstButtonValue;
            });}, child: Text("Add ${widget.firstButtonValue} Point"),),
            SizedBox(height: 10,),
            ElevatedButton(onPressed: (){
              setState(() {


              widget.value+=widget.secondButtonValue;
              });
            }, child: Text("Add ${widget.secondButtonValue} Point"),),
            SizedBox(height: 10,),

            ElevatedButton(onPressed: (){
              setState(() {


              widget.value+=widget.thirdButtonValue;
              });
            }, child: Text("Add ${widget.thirdButtonValue} Point"),),
            SizedBox(height: 5,),
            ElevatedButton(onPressed: (){}, child: Text("Reset"))
          ],
        ),
      ),
    );
  }
}
