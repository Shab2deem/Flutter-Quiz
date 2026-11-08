import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz/signuppage.dart';

class MyLoginPage extends StatelessWidget {
   MyLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    var usernameController= TextEditingController();
    var passwordController= TextEditingController();
    return Scaffold(
      body: Container(
        width: .infinity,
        child: Column(
          mainAxisAlignment: .center,
          crossAxisAlignment: .center,
          children: [
            Text("Welcome Back",style: TextStyle(fontSize: 28,fontWeight: FontWeight.bold),),
            SizedBox(height: 2,),
            Text("Enter your credential to login"),
            SizedBox(height: 20,),
            MyCustomTextBox(icon: Icon(Icons.person_outline), text: "Username", controller: usernameController),
            SizedBox(height: 10,),

            MyCustomTextBox(icon: Icon(Icons.lock_outline), text: "Password", controller: passwordController,isSecure: true,),
            SizedBox(height: 10,),
            Container(width: 250,height: 45,child: ElevatedButton(onPressed: (){},style: ElevatedButton.styleFrom(backgroundColor: Colors.purple), child: Text("Login",style: TextStyle(color: Colors.white,fontWeight: .bold),))),
            SizedBox(height: 20,),
            Text("Forgot password?",style: TextStyle(fontWeight: .bold,fontSize: 18,color: Colors.purpleAccent),),
            SizedBox(height: 20,),
            Row(
              mainAxisAlignment: .center,
              children: [
                Text("Don't have an account?",style: TextStyle(fontSize: 15),),
                TextButton(onPressed: (){Navigator.push(context, MaterialPageRoute(builder: (context) => SignUp(),));}, child:Text("Sign Up",style: TextStyle(color: Colors.deepPurple),) )
              ],
            )

          ],
        ),
      ),

    );
  }
}
