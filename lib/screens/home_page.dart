import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:task2_chat_rooms/screens/login_page.dart';

class ChatOrbitHomePage extends StatefulWidget {
  const ChatOrbitHomePage({super.key});

  @override
  State<ChatOrbitHomePage> createState() => _ChatOrbitHomePageState();
}

class _ChatOrbitHomePageState extends State<ChatOrbitHomePage> {
  String? activeChannel; // The active channel selected by the user
  bool isSubscribed = false;

  final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  final TextEditingController _messageController = TextEditingController();

  // ------------------------------------------------------------------------
  Future<void> _checkSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && activeChannel != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final subscriptions =
          List<String>.from(userDoc.data()?['subscriptions'] ?? []);
      setState(() {
        isSubscribed = subscriptions.contains(activeChannel);
      });
    }
  }

  Future<void> unsubscribeAllUsers(String channelId) async {
    final querySnapshot = await FirebaseFirestore.instance.collection('users').get();

    for (var doc in querySnapshot.docs) {
      final userId = doc.id;
      final userSubscriptions = List<String>.from(doc['subscriptions'] ?? []);

      // Check if the channelId exists in the subscriptions array
      if (userSubscriptions.contains(channelId)) {
        userSubscriptions.remove(channelId);

        // Update the subscriptions array for the user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'subscriptions': userSubscriptions});
      }
    }
  }

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
    bool confirm = await _showConfirmationDialog(
        title: "Remove Channel",
        message: "Are you sure you want to remove this channel?");

    if (confirm) {
      final messagesRef =
          FirebaseDatabase.instance.ref('messages').child(channelId);
      final messagesSnapshot = await messagesRef.get();

      if (messagesSnapshot.exists) {
        // Step 2: Delete each message from Realtime Database
        for (var message in messagesSnapshot.children) {
          await messagesRef.child(message.key!).remove(); // Remove each message
        }
      }
      unsubscribeAllUsers(channelId);
      await FirebaseFirestore.instance
          .collection('channels')
          .doc(channelId)
          .delete();
      if (activeChannel == channelId) {
        setState(() {
          activeChannel = null;
        });
      }
    }
  }

  Future<void> _subscribeToChannel(String channelId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.update({
        'subscriptions': FieldValue.arrayUnion([channelId]),
      });
      _checkSubscriptionStatus();

      await analytics.logEvent(
        name: 'channel_subscription',
        parameters: {'user_id': user.uid, 'action': 'subscribe', 'channel_id': channelId}
      );
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
      _checkSubscriptionStatus();

      await analytics.logEvent(
          name: 'channel_unsubscription',
          parameters: {'user_id': user.uid, 'action': 'unsubscribe', 'channel_id': channelId}
      );
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

  Future<String?> _getUsername(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return userDoc['email'] as String?;
    } catch (_) {
      return "Unknown";
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseAuth.instance.signOut();
      await analytics.logEvent(
          name: 'logout',
          parameters: {'user_id': user!.uid, 'action': 'logout'}
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout Failed: $e')));
    }
  }
  // ------------------------------------------------------------------------

  Widget _buildMessageList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: activeChannel != null ? getMessages(activeChannel!) : null,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final messages = snapshot.data ?? [];
        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return FutureBuilder<String?>(
              future: _getUsername(message['senderId']),
              builder: (context, usernameSnapshot) {
                String sender = usernameSnapshot.data ?? "Unknown";
                return Container(
                  margin:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sender,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(message['text'] ?? ""),
                      const SizedBox(height: 4),
                      Text(
                        DateTime.fromMillisecondsSinceEpoch(
                                message['timestamp'] as int)
                            .toLocal()
                            .toString(),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Type a message",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          IconButton(
            icon: const Icon(
              Icons.send,
              color: Color(0xFF1F2937),
            ),
            onPressed: () {
              if (activeChannel != null && isSubscribed) {
                _sendMessage();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("You must select and subscribe to a channel."),
                ));
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildChannelTile(Map<String, dynamic> channelData) {
    String channelId = channelData['id'];
    String channelName = channelData['name'];
    String channelDescription = channelData['description'];
    bool isActive = activeChannel == channelId;

    return ListTile(
      leading: const Icon(Icons.chat, color: Colors.white),
      title: Text(
        channelName,
        style: TextStyle(
          color: isActive ? Colors.blue : Colors.white,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        channelDescription,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 14,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () => _removeChannel(channelId),
      ),
      onTap: () {
        setState(() {
          activeChannel = channelId;
        });
        _checkSubscriptionStatus();
      },
    );
  }

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

  Future<bool> _showConfirmationDialog(
      {required String title, required String message}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("Confirm"),
              ),
            ],
          ),
        ) ??
        false;
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
  void initState() {
    super.initState();
    _checkSubscriptionStatus(); // Initialize subscription status
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: MediaQuery.of(context).size.width * 0.45,
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
                      IconButton(
                          icon: const Icon(Icons.logout),
                          color: Colors.white,
                          onPressed: () {
                            _logout(context);
                          }),
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

                          final channels = snapshot.data ?? [];
                          return ListView.builder(
                            itemCount: channels.length,
                            itemBuilder: (context, index) {
                              final channel = channels[index];
                              return _buildChannelTile(channel);
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
                    : Column(
                        children: [
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
                                      return const Text('Channel not found');
                                    }
                                    final channelData = channelSnapshot.data!;
                                    final channelName = channelData['name'] ??
                                        'Unknown Channel';
                                    final channelDescription =
                                        channelData['description'] ?? "";
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          channelName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: 4,
                                        ),
                                        Text(
                                          channelDescription,
                                          style: const TextStyle(
                                            color: Colors
                                                .white70, // Lighter color for description
                                            fontSize:
                                                14, // Smaller font size for subtitle
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const Spacer(),
                                if (isSubscribed)
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
                                  ),
                              ],
                            ),
                          ),
                          Expanded(child: _buildMessageList()),
                          if (isSubscribed) _buildMessageInput(),
                          if (!isSubscribed) _subscriptionButton(),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
