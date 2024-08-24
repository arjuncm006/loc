import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loc/pages/map.dart';
import 'package:loc/search.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class SlidingUp extends StatelessWidget {
  const SlidingUp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Locator"), leading: Icon(Icons.location_searching),
      ),
      body: SlidingUpPanel(
        panel: Center(
          child: Sorch(),
        ),
        body: Center(
          child: Mapp()
        ),
      ),
    );;
  }
}
