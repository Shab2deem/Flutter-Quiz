import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz/component.dart';

class customButton extends StatefulWidget {
  bool isPressed;
  final Product product;
   customButton({super.key,this.isPressed=false,required this.product});

  @override
  State<customButton> createState() => _customButtonState();
}

class _customButtonState extends State<customButton> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: (){setState(() {
      widget.isPressed=!widget.isPressed;
widget.product.isAdded=widget.isPressed;
    });},style: ElevatedButton.styleFrom(backgroundColor:widget.isPressed?Colors.red:Colors.green) ,child: widget.isPressed?Text("Added ✔",style: TextStyle(color:Colors.white),):Text("Add to Cart",style: TextStyle(color:Colors.white)));
  }
}
