import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:intl/intl.dart';
import '../Controllers/SharedMessagesController.dart';
import 'ScreenHome.dart';

class ScreenHistory extends StatefulWidget {
  const ScreenHistory({super.key});

  @override
  State<ScreenHistory> createState() => _ScreenHistoryState();
}

class _ScreenHistoryState extends State<ScreenHistory> {
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy · h:mm a');
  Map<String, List<ChatMessage>> conversations = {};

  @override
  void initState() {
    super.initState();
    // Initialize with current conversations
    conversations = sharedMessagesController.conversations;

    // Listen for updates to conversations
    sharedMessagesController.conversationsStream.listen((updatedConversations) {
      setState(() {
        conversations = updatedConversations;
      });
    });
  }

  String _getConversationTitle(String id, List<ChatMessage> messages) {
    if (messages.isEmpty) return "Empty conversation";

    // Use the first user message as the title, or "New conversation" if none exists
    for (var message in messages) {
      if (message.user.id == "0") { // User ID
        // Truncate long messages
        String title = message.text;
        if (title.length > 40) {
          title = "${title.substring(0, 37)}...";
        }
        return title;
      }
    }

    return "New conversation";
  }

  String _getConversationDate(List<ChatMessage> messages) {
    if (messages.isEmpty) return "";

    // Get the timestamp of the most recent message
    DateTime mostRecent = messages.first.createdAt;
    return _dateFormat.format(mostRecent);
  }

  @override
  Widget build(BuildContext context) {
    // Sort conversations by most recent message
    List<MapEntry<String, List<ChatMessage>>> sortedConversations =
    conversations.entries.toList()
      ..sort((a, b) {
        // If either list is empty, put it at the end
        if (a.value.isEmpty) return 1;
        if (b.value.isEmpty) return -1;

        // Sort by the timestamp of the most recent message in descending order
        return b.value.first.createdAt.compareTo(a.value.first.createdAt);
      });

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text('Chat History'),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 22),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: sortedConversations.isEmpty
          ? Center(
        child: Text(
          'No chat history yet',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      )
          : ListView.builder(
        itemCount: sortedConversations.length,
        itemBuilder: (context, index) {
          final entry = sortedConversations[index];
          final conversationId = entry.key;
          final messages = entry.value;

          return Dismissible(
            key: Key(conversationId),
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Icon(Icons.delete, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (direction) {
              // Delete conversation
              sharedMessagesController.deleteConversation(conversationId);

              // Show snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Conversation deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      // This is a simplified undo - in a real app you might want to restore the actual conversation
                      setState(() {
                        // The conversation stream will handle the update
                      });
                    },
                  ),
                ),
              );
            },
            child: ListTile(
              title: Text(
                _getConversationTitle(conversationId, messages),
                style: TextStyle(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _getConversationDate(messages),
                style: TextStyle(color: Colors.grey),
              ),
              leading: Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
              ),
              trailing: conversationId == sharedMessagesController.currentConversationId
                  ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              )
                  : null,
              onTap: () {
                // Switch to this conversation
                sharedMessagesController.switchConversation(conversationId);

                // Navigate back to chat screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ScreenHome()),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.grey.shade800,
        onPressed: () {
          // Start a new conversation
          sharedMessagesController.startNewConversation();

          // Navigate to home screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ScreenHome()),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}