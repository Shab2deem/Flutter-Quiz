import 'package:flutter/material.dart';
import 'package:quiz/details.dart';
import 'package:quiz/myButton.dart';


class Product {
  final String name;
  final String price;
  final String rate;
  final IconData icon;
  bool isAdded;

  Product({
    required this.name,
    required this.price,
    required this.rate,
    required this.icon,
    this.isAdded=false,
  });
}

class MyWidget extends StatelessWidget {
  final Product product;
  const MyWidget({required this.product, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Details()),
      ),
      child: Card(
        elevation: 5,
        margin: EdgeInsets.all(20),
        shadowColor: Colors.black,

        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(product.icon, color: Colors.deepPurple, size: 70),
              SizedBox(height: 10),
              Text(
                product.name,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                "\$${product.price}",
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
              SizedBox(height: 10,),
              customButton(product: product),
            ],
          ),
        ),
      ),
    );
  }
}