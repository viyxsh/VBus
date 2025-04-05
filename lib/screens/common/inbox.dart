import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vbuss/screens/common/chat_screen.dart';

class InboxScreen extends StatefulWidget {
  final bool isConductor;

  const InboxScreen({Key? key, required this.isConductor}) : super(key: key);

  @override
  _InboxScreenState createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late User? _currentUser;
  late Stream<QuerySnapshot> _chatsStream;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _initializeChatsStream();
  }

  void _initializeChatsStream() {
    if (_currentUser != null) {
      if (widget.isConductor) {
        // If user is conductor, fetch all chats where they are a participant
        _chatsStream = _firestore
            .collection('chats')
            .where('conductorId', isEqualTo: _currentUser!.uid)
            .snapshots();
      } else {
        // If user is student/faculty, fetch chats only with their bus conductor
        _chatsStream = _firestore
            .collection('chats')
            .where('participants', arrayContains: _currentUser!.uid)
            .snapshots();
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch dialer')),
      );
    }
  }

  Future<Map<String, dynamic>?> _getUserDetails(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching user details: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Center(child: Text('Please login to view messages'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        backgroundColor: widget.isConductor ? Colors.orange : Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No messages yet'),
                        if (widget.isConductor)
                          ElevatedButton(
                            onPressed: () {
                              _showNewChatDialog();
                            },
                            child: const Text('New Message'),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final chat = snapshot.data!.docs[index];
                    final data = chat.data() as Map<String, dynamic>;
                    final String chatId = chat.id;
                    final List<dynamic> participants = data['participants'] ?? [];

                    // Determine which participant to show (not the current user)
                    String otherUserId;
                    if (widget.isConductor) {
                      // For conductor, show the student/faculty
                      otherUserId = data['studentId'] ?? '';
                    } else {
                      // For student/faculty, show the conductor
                      otherUserId = data['conductorId'] ?? '';
                    }

                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getUserDetails(otherUserId),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return const ListTile(
                            leading: CircularProgressIndicator(),
                            title: Text('Loading...'),
                          );
                        }

                        final userData = userSnapshot.data;
                        final String userName = userData?['name'] ?? 'Unknown User';
                        final String phoneNumber = userData?['phone'] ?? '';
                        final String lastMessage = data['lastMessage'] ?? 'No messages yet';
                        final Timestamp lastMessageTime = data['lastMessageTime'] ?? Timestamp.now();
                        final bool hasUnread = data['unread'] != null && data['unread'] == true;

                        return Card(
                          elevation: hasUnread ? 3 : 1,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: widget.isConductor ? Colors.blue : Colors.orange,
                              child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : '?'),
                            ),
                            title: Text(
                              userName,
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTimestamp(lastMessageTime),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (phoneNumber.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.call, color: Colors.green),
                                    onPressed: () => _makePhoneCall(phoneNumber),
                                  ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatId: chatId,
                                    otherUserId: otherUserId,
                                    otherUserName: userName,
                                    isConductor: widget.isConductor,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isConductor
          ? FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.message),
      )
          : null,
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();

    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      // Today, show time
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (dateTime.year == now.year) {
      // This year, show month and day
      return '${dateTime.day}/${dateTime.month}';
    } else {
      // Different year, show date with year
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showNewChatDialog() async {
    if (!widget.isConductor) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Chat'),
          content: SizedBox(
            width: double.maxFinite,
            child: FutureBuilder<QuerySnapshot>(
              future: _firestore.collection('users').where('role', isEqualTo: 'student').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No students found'));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final user = snapshot.data!.docs[index];
                    final userData = user.data() as Map<String, dynamic>;
                    final String userId = user.id;
                    final String userName = userData['name'] ?? 'Unknown';

                    return ListTile(
                      title: Text(userName),
                      onTap: () async {
                        // Check if chat already exists
                        final existingChats = await _firestore
                            .collection('chats')
                            .where('conductorId', isEqualTo: _currentUser!.uid)
                            .where('studentId', isEqualTo: userId)
                            .get();

                        String chatId;
                        if (existingChats.docs.isNotEmpty) {
                          chatId = existingChats.docs.first.id;
                        } else {
                          // Create a new chat
                          final newChatRef = await _firestore.collection('chats').add({
                            'conductorId': _currentUser!.uid,
                            'studentId': userId,
                            'participants': [_currentUser!.uid, userId],
                            'createdAt': FieldValue.serverTimestamp(),
                            'lastMessage': '',
                            'lastMessageTime': FieldValue.serverTimestamp(),
                            'unread': false
                          });
                          chatId = newChatRef.id;
                        }

                        Navigator.pop(context); // Close dialog
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              chatId: chatId,
                              otherUserId: userId,
                              otherUserName: userName,
                              isConductor: true,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}