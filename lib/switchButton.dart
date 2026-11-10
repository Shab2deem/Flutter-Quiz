import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Switchbutton extends StatefulWidget {
  const Switchbutton({super.key});

  @override
  State<Switchbutton> createState() => _SwitchbuttonState();
}

class _SwitchbuttonState extends State<Switchbutton> {
  bool isToggled=false;
  String? myRadioButton="male";
  Color bgc=Colors.white;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgc,

      appBar: AppBar(),
      body: Column(
        children: [
          Switch(value: isToggled, onChanged: (boolean){
            setState(() {

              isToggled=boolean;
              // if(!boolean)bgc=Colors.white;
              bgc=Colors.black;
            });
            
          },activeTrackColor: Colors.blueAccent,),
          Text("Click this button if you're",style: TextStyle(color: Colors.black),),
          SizedBox(height: 20,),
          Text("Gay",style:TextStyle(color:Colors.white)),
          SizedBox(height: 20,),
          Radio(value: 'male' ,groupValue: myRadioButton, onChanged: (String? value){

            setState(() {
              myRadioButton = value;
            });


          }, ),Radio(value: 'female', groupValue: myRadioButton , onChanged: (String? value){
              setState(() {
                myRadioButton=value;
              });

          }, )

        ],
      ),
      
    );
  }
}
