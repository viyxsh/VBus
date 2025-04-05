import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final bool isConductor;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.isConductor,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSoundRecorder _soundRecorder = FlutterSoundRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  late User? _currentUser;
  late Stream<QuerySnapshot> _messagesStream;
  String? _recordingPath;
  bool _isRecording = false;
  bool _recorderInitialized = false;
  String? _currentlyPlayingId;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _setupMessagesStream();
    _markChatAsRead();
    _fetchUserPhone();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }

    await _soundRecorder.openRecorder();
    _recorderInitialized = true;
  }

  void _setupMessagesStream() {
    _messagesStream = _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  Future<void> _fetchUserPhone() async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(widget.otherUserId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _phoneNumber = userData['phone'] ?? '';
        });
      }
    } catch (e) {
      print('Error fetching user phone: $e');
    }
  }

  Future<void> _markChatAsRead() async {
    if (_currentUser != null) {
      await _firestore.collection('chats').doc(widget.chatId).update({
        'unread': false,
      });
    }
  }

  Future<void> _sendMessage({String? text, String? audioUrl}) async {
    if (_currentUser == null) return;

    if ((text == null || text.trim().isEmpty) && audioUrl == null) return;

    final String senderId = _currentUser!.uid;
    final String messageType = audioUrl != null ? 'audio' : 'text';
    final String messageContent = audioUrl ?? text!.trim();

    // Add message to the chat's message collection
    await _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .add({
      'senderId': senderId,
      'content': messageContent,
      'type': messageType,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update the chat document with latest message info
    await _firestore.collection('chats').doc(widget.chatId).update({
      'lastMessage': messageType == 'audio' ? '🎤 Voice message' : messageContent,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unread': true,
    });

    // Clear the text input
    _messageController.clear();

    // Scroll to the bottom after sending a message
    Timer(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startRecording() async {
    if (!_recorderInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recorder not initialized')),
      );
      return;
    }

    try {
      // Create a temporary file for recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/audio_message_${DateTime.now().millisecondsSinceEpoch}.aac';

      // Start recording
      await _soundRecorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _stopRecordingAndSend() async {
    try {
      if (_isRecording) {
        final recordingPath = await _soundRecorder.stopRecorder();
        setState(() {
          _isRecording = false;
        });

        if (recordingPath != null) {
          // Upload the audio file to Firebase Storage
          final file = File(recordingPath);
          final storageRef = _storage.ref().child(
              'audio_messages/${widget.chatId}/${DateTime.now().millisecondsSinceEpoch}.aac'
          );

          final uploadTask = storageRef.putFile(file);
          final snapshot = await uploadTask;

          // Get the download URL
          final downloadUrl = await snapshot.ref.getDownloadURL();

          // Send the message with the audio URL
          await _sendMessage(audioUrl: downloadUrl);
        }
      }
    } catch (e) {
      print('Error stopping recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _playAudio(String audioUrl, String messageId) async {
    try {
      if (_currentlyPlayingId == messageId) {
        // Stop if already playing this message
        await _audioPlayer.stop();
        setState(() {
          _currentlyPlayingId = null;
        });
      } else {
        // Stop any currently playing audio
        if (_currentlyPlayingId != null) {
          await _audioPlayer.stop();
        }

        // Play the new audio
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _currentlyPlayingId = messageId;
        });

        // Reset after playback completes
        _audioPlayer.onPlayerComplete.listen((_) {
          setState(() {
            _currentlyPlayingId = null;
          });
        });
      }
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  Future<void> _makePhoneCall() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number available')),
      );
      return;
    }

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: _phoneNumber,
    );

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch dialer')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_recorderInitialized) {
      _soundRecorder.closeRecorder();
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = widget.isConductor ? Colors.orange : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: primaryColor,
        actions: [
          if (_phoneNumber != null && _phoneNumber!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: _makePhoneCall,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                // Scroll to bottom on new messages
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (context, index) {
                    final message = snapshot.data!.docs[index];
                    final data = message.data() as Map<String, dynamic>;
                    final String messageId = message.id;
                    final String senderId = data['senderId'] ?? '';
                    final String content = data['content'] ?? '';
                    final String type = data['type'] ?? 'text';
                    final Timestamp? timestamp = data['timestamp'] as Timestamp?;

                    final bool isMe = _currentUser != null && senderId == _currentUser!.uid;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isMe ? primaryColor : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: type == 'audio'
                                  ? GestureDetector(
                                onTap: () => _playAudio(content, messageId),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _currentlyPlayingId == messageId
                                          ? Icons.stop
                                          : Icons.play_arrow,
                                      color: isMe ? Colors.white : primaryColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Voice Message',
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                                  : Text(
                                content,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timestamp != null
                                  ? DateFormat('HH:mm').format(timestamp.toDate())
                                  : '',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Voice recording button
                  GestureDetector(
                    onLongPress: _startRecording,
                    onLongPressEnd: (_) => _stopRecordingAndSend(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.red : Colors.grey.shade200,
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        color: _isRecording ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text input field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _isRecording ? 'Recording...' : 'Type a message',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isRecording,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  IconButton(
                    icon: Icon(Icons.send, color: primaryColor),
                    onPressed: () => _sendMessage(text: _messageController.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}