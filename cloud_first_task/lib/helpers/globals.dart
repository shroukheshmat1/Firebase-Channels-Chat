// import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

import 'package:path_provider/path_provider.dart';

List<String> subscribedList = [];
List<String> topics = ['Sports', 'Politics', 'Economics'];

Future<void> readSubscribedList() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/my_file.txt');
    subscribedList = await file.readAsLines();
  } catch (e) {
    print("Couldn't read file");
  }
}

Future<void> saveSubscribedList() async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/my_file.txt');
  
  // Combine all topics into a single string with newlines.
  final content = subscribedList.join('\n');
  
  // Write the content to the file, overwriting any previous data.
  await file.writeAsString(content, mode: FileMode.write);
}

