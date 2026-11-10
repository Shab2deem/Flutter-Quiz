import 'package:flutter/material.dart';
import 'package:quiz/component.dart';
import 'package:quiz/details.dart';

final List<Product> products = [
  Product(
    name: "Smart Watch",
    price: "120.0",
    icon: Icons.watch,
    rate: "4.5",
  ),
  Product(
    name: "Headphones",
    price: "80.0",
    icon: Icons.headphones,
    rate: "4.2",
  ),
  Product(name: "Laptop", price: "950.0", icon: Icons.laptop, rate: "4.8"),
  Product(
    name: "Camera",
    price: "400.0",
    icon: Icons.camera_alt,
    rate: "4.3",
  ),
  Product(
    name: "ٍSmartPhone",
    price: "500.0",
    icon: Icons.phone_android,
    rate: "4.1",
  ),
  Product(name: "Tablet", price: "400.0", icon: Icons.tablet, rate: "4.3"),
];
class HomePage extends StatelessWidget {


  new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        title: Text("Homepage page", style: TextStyle(color: Colors.white)),
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
        ),
        itemBuilder: (context, index) => MyWidget(product: products[index]),
        itemCount: products.length,
      ),
      bottomNavigationBar: FloatingActionButton(onPressed: (){Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Details()),
      );}),
    );
  }
}