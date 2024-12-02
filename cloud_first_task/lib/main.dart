import 'package:cloud_first_task/firebase_options.dart';
import 'package:cloud_first_task/helpers/globals.dart';
import 'package:cloud_first_task/pages/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void foregroundNotificationHanlder(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final title = message.notification?.title ?? 'No Title';
    final body = message.notification?.body ?? 'No Body';

    var snackBar = SnackBar(
      content: Text('Title: $title and Body: $body'),
    );

    BuildContext? con = navigatorKey.currentState?.overlay?.context;
    if (con != null) {
      if (con.mounted) {
        ScaffoldMessenger.of(con).showSnackBar(snackBar);
      }
    }
  } catch (e) {
    print(e.toString());
  }
}

@pragma('vm:entry-point')
Future<void> backgroundNotificationHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print(e.toString());
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  String? token = await FirebaseMessaging.instance.getToken();
  print('Token: $token');

  FirebaseMessaging.onMessage.listen(foregroundNotificationHanlder);
  FirebaseMessaging.onBackgroundMessage(backgroundNotificationHandler);
  await readSubscribedList();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      home: const SafeArea(child: HomeScreen()),
    );
  }
}
