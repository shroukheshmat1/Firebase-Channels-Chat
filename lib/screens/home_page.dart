import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class ChatOrbitHomePage extends StatefulWidget {
  const ChatOrbitHomePage({super.key});

  @override
  State<ChatOrbitHomePage> createState() => _ChatOrbitHomePageState();
}

class _ChatOrbitHomePageState extends State<ChatOrbitHomePage> {
  String? activeChannel; // The active channel selected by the user

  final TextEditingController _messageController = TextEditingController();

  // ------------------------------------------------------------------------
  Future<void> _addChannel(
      String name, String description, String createdBy) async {
    await FirebaseFirestore.instance.collection('channels').add({
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp()
    });
  }

  Future<void> _removeChannel(String channelId) async {
    await FirebaseFirestore.instance
        .collection('channels')
        .doc(channelId)
        .delete();
  }

  Future<void> _subscribeToChannel(String channelId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.update({
        'subscriptions': FieldValue.arrayUnion([channelId]),
      });
    }
  }

  Future<void> _unsubscribeFromChannel(String channelId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.update({
        'subscriptions': FieldValue.arrayRemove([channelId]),
      });
    }
  }

  Stream<List<Map<String, dynamic>>> getChannels() {
    return FirebaseFirestore.instance
        .collection('channels')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<List<String>> getUserSubscriptions(String userId) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return List<String>.from(userDoc.data()?['subscriptions'] ?? []);
  }

  // ------------------------------------------------------------------------

  // Show dialog to add a new channel
  void _showAddChannelDialog(BuildContext context) {
    TextEditingController channelController = TextEditingController();
    TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Add Channel"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: channelController,
                decoration:
                    const InputDecoration(hintText: "Enter Channel Name"),
              ),
              const SizedBox(
                height: 8,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                    hintText: 'Enter Channel Description'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                String newChannelName = channelController.text.trim();
                String newChannelDescription =
                    descriptionController.text.trim();
                User? user = FirebaseAuth.instance.currentUser;

                if (newChannelName.isNotEmpty &&
                    newChannelDescription.isNotEmpty &&
                    user != null) {
                  _addChannel(newChannelName, newChannelDescription, user.uid);
                  Navigator.of(context).pop(); // Close the dialog
                } else {
                  // Show error message if the channel name is empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Please Enter Both Channel Name and Description, and Make Sure You'r Logged In")),
                  );
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // Show confirmation dialog for unsubscribing
  void _showUnsubscribeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Unsubscribe"),
          content: const Text(
              "Are You Sure You Want to Unsubscribe from this Channel?"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close Dialog
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () async {
                if (activeChannel != null) {
                  await _unsubscribeFromChannel(activeChannel!);
                }
                setState(() {
                  activeChannel = null; // Optionally, set activeChannel to null
                });
                Navigator.of(context).pop(); // Close Dialog
              },
              child: const Text("Yes"),
            ),
          ],
        );
      },
    );
  }

  void _sendMessage() async {
    String message = _messageController.text.trim();
    if (message.isEmpty || activeChannel == null) {
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You must be logged in to send messages')));
      return;
    }
    DatabaseReference messageRef =
        FirebaseDatabase.instance.ref("messages/${activeChannel!}").push();

    await messageRef.set({
      'text': message,
      'senderId': user.uid,
      'timestamp': ServerValue.timestamp
    });
    _messageController.clear();
  }

  Stream<List<Map<String, dynamic>>> getMessages(String channelId) {
    return FirebaseDatabase.instance
        .ref("messages/$channelId")
        .orderByChild("timestamp")
        .onValue
        .map((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>? ?? {};
      return data.entries.map((entry) {
        final key = entry.key as String;
        final value = Map<String, dynamic>.from(entry.value);
        return {...value, 'id': key};
      }).toList();
    });
  }

  // Widget for the subscription button
  Widget _subscriptionButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        padding: const EdgeInsets.all(16),
        child: TextButton(
          onPressed: () {
            _subscribeToChannel(activeChannel!);
          },
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFF1F2937),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Subscribe',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // Handle subscription to a channel

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: MediaQuery.of(context).size.width * 0.25,
            color: const Color(0xFF1F2937),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  child: Row(
                    children: [
                      const Text(
                        "Channels",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _showAddChannelDialog(
                              context); // Open dialog for adding a new channel
                        },
                      ),
                    ],
                  ),
                ),
                // List of channels
                Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: getChannels(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          var channels = snapshot.data ?? [];
                          return ListView.builder(
                            itemCount: channels.length,
                            itemBuilder: (context, index) {
                              var channelDoc = channels[index];
                              String channelId = channelDoc['id'];
                              String channelName = channelDoc['name'];
                              String channelDescription =
                                  channelDoc['description'];
                              bool isActive = activeChannel == channelId;

                              return ListTile(
                                leading: const Text(
                                  "#",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                                title: Text(
                                  channelName,
                                  style: TextStyle(
                                    color:
                                        isActive ? Colors.blue : Colors.white,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Text(
                                  channelDescription,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    activeChannel = channelId;
                                  });
                                },
                              );
                            },
                          );
                        })),
              ],
            ),
          ),

          // Main content area
          Expanded(
            child: Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: activeChannel == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "Welcome To ChatOrbit!",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            "Select a Channel or add one to start chatting!",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : StreamBuilder<DatabaseEvent>(
                        stream: FirebaseDatabase.instance
                            .ref('messages/$activeChannel')
                            .onValue,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Error: ${snapshot.error}'));
                          }

                          final data = snapshot.data?.snapshot.value
                                  as Map<dynamic, dynamic>? ??
                              {};
                          final messages = data.entries
                              .map((e) => {
                                    'id': e.key,
                                    ...Map<String, dynamic>.from(e.value)
                                  })
                              .toList();

                          return Column(
                            children: [
                              // Display active channel and messages
                              Container(
                                padding: const EdgeInsets.all(16),
                                color: const Color(0xFF1F2937),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.chat,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    StreamBuilder(
                                      stream: FirebaseFirestore.instance
                                          .collection('channels')
                                          .doc(activeChannel)
                                          .snapshots(),
                                      builder: (context, channelSnapshot) {
                                        if (channelSnapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return const CircularProgressIndicator();
                                        }

                                        if (channelSnapshot.hasError ||
                                            !channelSnapshot.hasData) {
                                          return const Text(
                                              'Channel not found');
                                        }
                                        final channelData =
                                            channelSnapshot.data!;
                                        final channelName =
                                            channelData['name'] ??
                                                'Unkown Channel';
                                        return Text(
                                          channelName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                    const Spacer(),
                                    PopupMenuButton(
                                      icon: const Icon(
                                        Icons.more_vert,
                                        color: Colors.white,
                                      ),
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: "unsubscribe",
                                          child: Text("Unsubscribe"),
                                        ),
                                      ],
                                      onSelected: (value) {
                                        if (value == "unsubscribe") {
                                          _showUnsubscribeDialog(context);
                                        }
                                      },
                                    )  
                                  ],
                                ),
                              ),
                              Expanded(
                                child: messages.isEmpty
                                ? const Center(child: Text("No Messages Yet."))
                                : ListView.builder(
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      return ListTile(
                                        title: Text(
                                          messages[index]['text'] ?? '',
                                          style: const TextStyle(
                                              color: Colors.black),
                                        ),
                                        subtitle: Text(
                                          'Sent by: ${messages[index]['senderId'] ?? 'Unknown'}',
                                          style: const TextStyle(color: Colors.grey),
                                        ),
                                      );
                                    },
                                  ),
                              ),
                              // Show the subscription button if not subscribed
                              
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: _subscriptionButton(),
                              ),
                              // Show message input field if subscribed
                              
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(
                                    hintText: "Type a message",
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (value) {
                                    _sendMessage(); // Call _sendMessage when the user presses 'Enter' or submits the message
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
