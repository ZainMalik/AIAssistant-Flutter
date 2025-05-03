import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// A singleton class to manage shared chat messages across different screens
class SharedMessagesController {
  static final SharedMessagesController _instance = SharedMessagesController._internal();

  factory SharedMessagesController() {
    return _instance;
  }

  SharedMessagesController._internal() {
    _loadConversations();
  }

  // List to store all chat messages for current conversation
  List<ChatMessage> messages = [];

  // Map to store chat history: conversationId -> List of messages
  Map<String, List<ChatMessage>> conversations = {};

  // Current active conversation ID
  String _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();
  String get currentConversationId => _currentConversationId;

  // Stream controller to notify listeners when messages change
  final _messagesController = StreamController<List<ChatMessage>>.broadcast();
  Stream<List<ChatMessage>> get messagesStream => _messagesController.stream;

  // Stream controller to notify listeners when conversations change
  final _conversationsController = StreamController<Map<String, List<ChatMessage>>>.broadcast();
  Stream<Map<String, List<ChatMessage>>> get conversationsStream => _conversationsController.stream;

  // Add a new message to the current conversation and notify listeners
  void addMessage(ChatMessage message) {
    messages = [message, ...messages];

    // Update the conversations map
    conversations[_currentConversationId] = messages;

    // Notify listeners
    _messagesController.add(messages);
    _conversationsController.add(conversations);

    // Save to persistent storage
    _saveConversations();
  }

  // Update the last message from a specific user (useful for streaming responses)
  void updateLastMessageFrom(ChatUser user, String newText) {
    if (messages.isNotEmpty && messages.first.user.id == user.id) {
      messages[0] = ChatMessage(
        user: user,
        createdAt: messages[0].createdAt,
        text: newText,
        medias: messages[0].medias,
      );

      // Update the conversations map
      conversations[_currentConversationId] = messages;

      // Notify listeners
      _messagesController.add(messages);
      _conversationsController.add(conversations);

      // Save to persistent storage
      _saveConversations();
    } else {
      // If there's no message from this user yet, add a new one
      addMessage(ChatMessage(
        user: user,
        createdAt: DateTime.now(),
        text: newText,
      ));
    }
  }

  // Start a new conversation
  void startNewConversation() {
    _currentConversationId = DateTime.now().millisecondsSinceEpoch.toString();
    messages = [];

    // Initialize empty conversation
    conversations[_currentConversationId] = messages;

    // Notify listeners
    _messagesController.add(messages);
    _conversationsController.add(conversations);

    // Save to persistent storage
    _saveConversations();
  }

  // Switch to an existing conversation
  void switchConversation(String conversationId) {
    if (conversations.containsKey(conversationId)) {
      _currentConversationId = conversationId;
      messages = conversations[conversationId] ?? [];

      // Notify listeners
      _messagesController.add(messages);

      // Save current conversation ID
      _saveConversations();
    }
  }

  // Delete a conversation
  void deleteConversation(String conversationId) {
    if (conversations.containsKey(conversationId)) {
      conversations.remove(conversationId);

      // If current conversation was deleted, start a new one
      if (_currentConversationId == conversationId) {
        startNewConversation();
      } else {
        // Just notify listeners about the conversations change
        _conversationsController.add(conversations);
      }

      // Save to persistent storage
      _saveConversations();
    }
  }

  // Clear all messages in current conversation
  void clearMessages() {
    messages = [];
    conversations[_currentConversationId] = messages;

    // Notify listeners
    _messagesController.add(messages);
    _conversationsController.add(conversations);

    // Save to persistent storage
    _saveConversations();
  }

  // Save conversations to persistent storage
  Future<void> _saveConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Convert conversations to JSON-serializable format
      Map<String, String> serializableConversations = {};

      conversations.forEach((id, messageList) {
        List<Map<String, dynamic>> serializedMessages = messageList.map((message) => _serializeMessage(message)).toList();
        serializableConversations[id] = jsonEncode(serializedMessages);
      });

      // Save to shared preferences
      await prefs.setString('conversations', jsonEncode(serializableConversations));
      await prefs.setString('currentConversationId', _currentConversationId);
    } catch (e) {
      print('Error saving conversations: $e');
    }
  }

  // Load conversations from persistent storage
  Future<void> _loadConversations() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load conversations
      final String? conversationsJson = prefs.getString('conversations');
      if (conversationsJson != null) {
        Map<String, dynamic> serializableConversations = jsonDecode(conversationsJson);

        serializableConversations.forEach((id, messagesJson) {
          List<dynamic> serializedMessages = jsonDecode(messagesJson);
          conversations[id] = serializedMessages.map((json) => _deserializeMessage(json)).toList();
        });

        // Load current conversation ID
        _currentConversationId = prefs.getString('currentConversationId') ?? _currentConversationId;

        // Set messages to current conversation
        messages = conversations[_currentConversationId] ?? [];

        // Notify listeners
        _messagesController.add(messages);
        _conversationsController.add(conversations);
      }
    } catch (e) {
      print('Error loading conversations: $e');
    }
  }

  // Helper method to serialize ChatMessage
  Map<String, dynamic> _serializeMessage(ChatMessage message) {
    Map<String, dynamic> serialized = {
      'userId': message.user.id,
      'userFirstName': message.user.firstName ?? '',
      'userLastName': message.user.lastName ?? '',
      'userProfileImage': message.user.profileImage ?? '',
      'text': message.text,
      'createdAt': message.createdAt.millisecondsSinceEpoch,
    };

    // Add medias if present (just storing file paths)
    if (message.medias != null && message.medias!.isNotEmpty) {
      serialized['medias'] = message.medias!.map((media) => {
        'url': media.url,
        'fileName': media.fileName,
        // 'type': media.type.index, // Store enum as int
      }).toList();
    }

    return serialized;
  }

  // Helper method to deserialize ChatMessage
  ChatMessage _deserializeMessage(Map<String, dynamic> json) {
    // Handle media files if present
    List<ChatMedia>? medias;
    if (json.containsKey('medias') && json['medias'] != null) {
      try {
        medias = (json['medias'] as List).map((mediaJson) => ChatMedia(
          url: mediaJson['url'],
          fileName: mediaJson['fileName'],
          type: mediaJson['type'],
        )).toList();
      } catch (e) {
        print('Error deserializing media: $e');
      }
    }

    return ChatMessage(
      user: ChatUser(
        id: json['userId'],
        firstName: json['userFirstName'],
        lastName: json['userLastName'],
        profileImage: json['userProfileImage'],
      ),
      text: json['text'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      medias: medias,
    );
  }

  void dispose() {
    _messagesController.close();
    _conversationsController.close();
  }
}

// For easier access throughout the app
final sharedMessagesController = SharedMessagesController();