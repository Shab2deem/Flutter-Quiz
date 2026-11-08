import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz/loginpage.dart';

class SignUp extends StatelessWidget {
   SignUp({super.key});
   var CustomBoxController1= TextEditingController();
   var CustomBoxController2= TextEditingController();
   var CustomBoxController3= TextEditingController();
   var formkey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
width: .infinity,
        child: Column(
        mainAxisAlignment: .center,
          crossAxisAlignment: .center,
          children: [
            Form(

                key: formkey,
              child: Column(
                children: [
                Text("Sign Up",style: TextStyle(fontSize: 28,fontWeight: FontWeight.bold),),
                SizedBox(height: 2,),
                Text("Create your account"),
                SizedBox(height: 20,),
                MyCustomTextBox(icon: Icon(Icons.person_outline), text: "Username", controller: CustomBoxController1),
                SizedBox(height: 10,),
                MyCustomTextBox(icon: Icon(Icons.email_outlined), text: "Email", controller: CustomBoxController2),
                SizedBox(height: 10,),
                MyCustomTextBox(icon: Icon(Icons.lock_outline), text: "Password", controller: CustomBoxController3,isSecure: true,),
                SizedBox(height: 10,),
                MyCustomTextBox(icon: Icon(Icons.lock_outline), text: "Confirm Password", controller: CustomBoxController3,isSecure: true,),
                SizedBox(height: 20,),
                Container(width: 250,height: 45,child: ElevatedButton(onPressed: (){ if(formkey.currentState!.validate())print("Hello");},style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: Text("Sign Up",style: TextStyle(color: Colors.white,fontWeight: .bold),))),
                SizedBox(height: 20,),
                Container(width: .infinity,child: Row( mainAxisAlignment:.center,children: [Text("----------",style: TextStyle(fontSize: 18)),SizedBox(width: 5,),Text("Or",style: TextStyle(fontSize: 18)),SizedBox(width: 5,),Text("----------",style: TextStyle(fontSize: 18)),])),
                SizedBox(height: 20,),
                Container(width: 250,height: 45,child: ElevatedButton(onPressed: (){},style: ElevatedButton.styleFrom(backgroundColor: Colors.white,shape:RoundedRectangleBorder(borderRadius:  BorderRadius.circular(30),side: BorderSide(color:Colors.black))), child: Text("Sign in with Google",style: TextStyle(color: Colors.deepPurple,fontWeight: .bold),))),
                SizedBox(height: 20,),
                Row(
                  mainAxisAlignment: .center,
                  children: [
                    Text("Already have an account?",style: TextStyle(fontSize: 15),),
                    TextButton(onPressed: (){Navigator.push(context, MaterialPageRoute(builder: (context) => MyLoginPage(),));}, child:Text("Login",style: TextStyle(color: Colors.deepPurple),) )
                  ],

                ),
        ]
              )

            ),
          ],
        ),
      ),

    );
  }
}
class MyCustomTextBox extends StatelessWidget {
  Icon icon;
  String text;
  TextEditingController controller;
  bool isSecure;
  double width;
   MyCustomTextBox({super.key,required this.icon,required this.text,required this.controller,this.isSecure=false,this.width=250});

  @override
  Widget build(BuildContext context) {
    return  Container(
      decoration: BoxDecoration(
        color: Colors.purple[100],
        borderRadius: BorderRadius.circular(30),
      ),
      width: width,
      height: 50,
      child: TextFormField(

        obscureText: isSecure,
        controller: controller,
        decoration: InputDecoration(
border: OutlineInputBorder(borderRadius: .circular(30)),
          prefixIcon: icon,
          prefixIconColor: Colors.deepPurple,
          labelText: text,

          suffixIcon: (isSecure)? Icon(Icons.remove_red_eye_outlined,color: Colors.deepPurple,):null,
        ),

      ),
    );
  }
}

