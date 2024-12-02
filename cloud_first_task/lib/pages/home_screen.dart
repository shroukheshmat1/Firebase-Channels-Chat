import 'package:cloud_first_task/helpers/globals.dart';
import 'package:cloud_first_task/widgets/topic_card.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home Screen"),
        backgroundColor: Colors.blue,
      ),
      body: ListView.builder(
        itemCount: topics.length,
        itemBuilder: (context, index) {
          return TopicCard(topic: topics[index]);
        },
      ),
    );
  }
}
