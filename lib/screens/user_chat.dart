import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class UserChatPage extends StatefulWidget {
  final String ticketId;
  final String ticketSubject;

  const UserChatPage(
      {Key? key, required this.ticketId, required this.ticketSubject})
      : super(key: key);

  @override
  State<UserChatPage> createState() => _UserChatPageState();
}

class _UserChatPageState extends State<UserChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({String? text, String? imageUrl}) async {
    // ... (This logic remains the same)
    if ((text == null || text.trim().isEmpty) &&
        (imageUrl == null || imageUrl.isEmpty)) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You must be logged in to send messages.')),
      );
      return;
    }
    try {
      Map<String, dynamic> messageData = {
        'timestamp': FieldValue.serverTimestamp(),
        'senderRole': 'user',
        'senderId': user.uid,
      };
      if (text != null && text.isNotEmpty) {
        messageData['type'] = 'text';
        messageData['text'] = text;
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        messageData['type'] = 'image';
        messageData['imageUrl'] = imageUrl;
      }
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _sendImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile == null) return;
      if (!mounted) return;

      setState(() {
        _isUploading = true;
      });

      final fileName = '${const Uuid().v4()}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(widget.ticketId)
          .child(fileName);

      // Platform-aware upload logic
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        await storageRef.putData(
            bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await storageRef.putFile(File(pickedFile.path));
      }

      final String downloadUrl = await storageRef.getDownloadURL();
      await _sendMessage(imageUrl: downloadUrl);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Widget _buildStatusChip(String status) {
    // DARK THEME: Using desaturated colors for a more pleasant dark UI
    Color bgColor;
    Color fgColor;
    switch (status.toLowerCase()) {
      case 'open':
        bgColor = Colors.green.shade900;
        fgColor = Colors.green.shade200;
        break;
      case 'in-progress':
        bgColor = Colors.orange.shade900;
        fgColor = Colors.orange.shade200;
        break;
      case 'closed':
        bgColor = Colors.red.shade900;
        fgColor = Colors.red.shade200;
        break;
      default:
        bgColor = Colors.grey.shade800;
        fgColor = Colors.grey.shade300;
    }
    return Chip(
      label: Text(status.toUpperCase(),
          style: TextStyle(color: fgColor, fontWeight: FontWeight.bold)),
      backgroundColor: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      labelPadding: EdgeInsets.zero,
      side: BorderSide.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    // DARK THEME: Define a color palette for a consistent look
    const pageBackgroundColor = Color(0xFF121212);
    const appBarColor = Color(0xFF1F1F1F);
    final accentColor = Theme.of(context).colorScheme.primary;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketId)
          .snapshots(),
      builder: (context, ticketSnapshot) {
        if (!ticketSnapshot.hasData) {
          return Scaffold(
              backgroundColor: pageBackgroundColor,
              appBar: AppBar(
                title: Text(widget.ticketSubject),
                backgroundColor: appBarColor,
              ),
              body: const Center(child: CircularProgressIndicator()));
        }

        final ticketData = ticketSnapshot.data!.data() as Map<String, dynamic>?;
        final status = ticketData?['status'] ?? 'unknown';
        final bool isTicketClosed = status == 'closed';

        return Scaffold(
          // DARK THEME: Set the main background color
          backgroundColor: pageBackgroundColor,
          appBar: AppBar(
            title: Text(widget.ticketSubject),
            backgroundColor: appBarColor,
            // DARK THEME: Ensure text and icons on the app bar are white
            foregroundColor: Colors.white,
            elevation: 0, // A flatter look is often better for dark themes
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(child: _buildStatusChip(status)),
              )
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tickets')
                      .doc(widget.ticketId)
                      .collection('messages')
                      .orderBy('timestamp', descending: false)
                      .snapshots(),
                  builder: (context, messageSnapshot) {
                    // ... (stream handling logic is unchanged)
                    if (messageSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (messageSnapshot.hasError) {
                      return const Center(
                          child: Text("An error occurred.",
                              style: TextStyle(color: Colors.white70)));
                    }
                    if (!messageSnapshot.hasData ||
                        messageSnapshot.data!.docs.isEmpty) {
                      return const Center(
                          child: Text("Send a message to start.",
                              style: TextStyle(color: Colors.white70)));
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController
                            .jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });
                    final messages = messageSnapshot.data!.docs;
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(10.0),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final messageDoc = messages[index];
                        final data = messageDoc.data() as Map<String, dynamic>;
                        return MessageBubble(
                          text: data['text'],
                          imageUrl: data['imageUrl'],
                          timestamp: data['timestamp'] as Timestamp?,
                          isFromAdmin: data['senderRole'] == 'admin',
                        );
                      },
                    );
                  },
                ),
              ),
              if (_isUploading)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.grey.shade800,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              _buildBottomSection(isTicketClosed),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSection(bool isTicketClosed) {
    if (isTicketClosed) {
      return _buildTicketClosedMessage();
    }
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tickets')
            .doc(widget.ticketId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildMessageInput();
          }
          final lastMessage =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          if (lastMessage['senderRole'] == 'user') {
            return _buildWaitingForReplyMessage();
          } else {
            return _buildMessageInput();
          }
        });
  }

  Widget _buildTicketClosedMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      color: const Color(0xFF1F1F1F), // Dark background for the bottom bar
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          // DARK THEME: Desaturated red for a less harsh look
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, color: Colors.red.shade300),
            const SizedBox(width: 8),
            Text(
              'This query is closed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.red.shade300, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForReplyMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      color: const Color(0xFF1F1F1F), // Dark background
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1), // Neutral dark container
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Text(
          'Our support staff will contact you soon. The chat will reopen once they reply.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.white.withOpacity(0.7)),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F), // Dark color for the input area
        // DARK THEME: Use a border instead of a shadow for better visual separation
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: _isUploading ? null : _sendImage,
            color: Theme.of(context).colorScheme.primary,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(
                  color: Colors.white), // DARK THEME: White text for input
              decoration: InputDecoration.collapsed(
                hintText: 'Type your reply...',
                // DARK THEME: Lighter hint text
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (text) {
                if (text.trim().isNotEmpty) {
                  _sendMessage(text: text.trim());
                  _messageController.clear();
                }
              },
            ),
          ),
          IconButton(
            icon:
                Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
            onPressed: _isUploading
                ? null
                : () {
                    if (_messageController.text.trim().isNotEmpty) {
                      _sendMessage(text: _messageController.text.trim());
                      _messageController.clear();
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final String? text;
  final String? imageUrl;
  final Timestamp? timestamp;
  final bool isFromAdmin;

  const MessageBubble({
    Key? key,
    this.text,
    this.imageUrl,
    required this.timestamp,
    required this.isFromAdmin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment =
        isFromAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end;

    // DARK THEME: Define colors for admin and user bubbles
    final color =
        isFromAdmin ? const Color(0xFF2A2A2A) : theme.colorScheme.primary;
    final textColor = isFromAdmin
        ? Colors.white.withOpacity(0.87)
        : theme.colorScheme.onPrimary;
    final timeStr =
        timestamp != null ? DateFormat.jm().format(timestamp!.toDate()) : '';
    final bool isImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          padding: isImage
              ? const EdgeInsets.all(4.0)
              : const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16.0), // A more rounded look
          ),
          child: isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.network(
                    imageUrl!,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Icon(Icons.error_outline, color: Colors.red),
                    ),
                  ),
                )
              : Text(
                  text ?? '',
                  style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          // DARK THEME: Lighter grey for the timestamp to be visible
          child: Text(timeStr,
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withOpacity(0.5))),
        )
      ],
    );
  }
}
