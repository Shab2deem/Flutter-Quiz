import 'package:flutter/material.dart';
import 'package:quiz/component.dart' show Product;
import 'package:quiz/homepage.dart';

class Details extends StatelessWidget {

  const Details({ super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        title: Text("Details page", style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Card(


          child: ListView.builder(
            itemCount: products.length,
            itemBuilder:(context, index) {
              if(products[index].isAdded) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurpleAccent.withValues(
                        alpha: 0.1),
                    child: Icon(products[index].icon, color: Colors.deepPurple),
                  ),
                  title: Text(products[index].name),
                  subtitle: Text("\$${products[index].price}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.deepPurple),
                      SizedBox(width: 10),
                      Text(products[index].rate),
                    ],
                  ),
                );
              }
              else{
                return SizedBox();
              }


            },
          ),
        ),
      ),
    );
  }
}