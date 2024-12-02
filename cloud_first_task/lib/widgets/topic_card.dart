import 'package:cloud_first_task/helpers/globals.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class TopicCard extends StatefulWidget {
  const TopicCard({super.key, required this.topic});
  final String topic;

  @override
  State<TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<TopicCard> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(widget.topic),
        Checkbox(
          value: subscribedList.contains(widget.topic),
          onChanged: (bool? isChecked) async {
            if (isChecked != null) {
              if (isChecked) {
                await FirebaseMessaging.instance.subscribeToTopic(widget.topic);
                subscribedList.add(widget.topic);
              } else {
                await FirebaseMessaging.instance
                    .unsubscribeFromTopic(widget.topic);
                subscribedList.remove(widget.topic);
              }
              await saveSubscribedList();
              setState(() {});
            }
          },
        ),
      ],
    );
  }
}
