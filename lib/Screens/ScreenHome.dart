import 'dart:io';
import 'dart:typed_data';

import 'package:chat_bubbles/bubbles/bubble_normal.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'ScreenVoiceChat.dart';
import 'ScreenHistory.dart'; // Import ScreenHistory
import '../Utils/Waveform.dart';
import 'package:ai_assistant/Controllers/SharedMessagesController.dart';

class ScreenHome extends StatefulWidget {
  const ScreenHome({super.key});

  @override
  State<ScreenHome> createState() => _HomePageState();
}

class _HomePageState extends State<ScreenHome> {
  final Gemini gemini = Gemini.instance;
  FlutterTts flutterTts = FlutterTts();
  List<ChatMessage> messages = [];

  final ScrollController scrollController = ScrollController();
  final TextEditingController controller = TextEditingController();

  late stt.SpeechToText speechToText;
  bool _isListening = false;
  bool _isGenerating = false;
  bool isTyping = false;
  String _text = '';

  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser geminiUser = ChatUser(
    id: "1",
    firstName: "Gemini",
    profileImage:
    "https://seeklogo.com/images/G/google-gemini-logo-A5787B2669-seeklogo.com.png",
  );

  @override
  void initState() {
    super.initState();
    speechToText = stt.SpeechToText();
    _requestPermission();
    _initSpeech();

    flutterTts.setLanguage("en-US");
    flutterTts.setPitch(1.0);
    flutterTts.setSpeechRate(0.5);

    flutterTts.setCompletionHandler(() {
      setState(() {
        _isGenerating = false;
      });
    });

    // Initialize messages from shared controller
    messages = sharedMessagesController.messages;

    // Listen for message updates from shared controller
    sharedMessagesController.messagesStream.listen((updatedMessages) {
      setState(() {
        messages = updatedMessages;
      });

      // Auto-scroll to bottom when new messages arrive
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    flutterTts.stop();
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        await Permission.microphone.request();
      }
    }
  }

  Future<void> _initSpeech() async {
    bool available = await speechToText.initialize(
      onStatus: (val) => print('Speech Status: $val'),
      onError: (val) => print('Speech Error: $val'),
    );
    print('Speech Recognition available: $available');
  }

  void _sendMessage(ChatMessage chatMessage) {
    // Add message to shared controller instead of local state
    sharedMessagesController.addMessage(chatMessage);

    // Start typing indicator
    setState(() {
      isTyping = true;
    });

    try {
      String question = chatMessage.text;
      List<Uint8List>? images;
      if (chatMessage.medias?.isNotEmpty ?? false) {
        images = [
          File(chatMessage.medias!.first.url).readAsBytesSync(),
        ];
      }
      print('Requesting Gemini API with question: $question');

      // Update to use the latest non-deprecated model name
      String modelName = images != null ? 'gemini-1.5-pro' : 'gemini-1.5-pro';

      gemini
          .streamGenerateContent(
        question,
        images: images,
        modelName: modelName,
      )
          .listen((event) async {
        // Use the shared controller to update messages
        String response = event.output.toString();

        // Turn off typing indicator after first response
        if (isTyping) {
          setState(() {
            isTyping = false;
          });
        }

        // Update the last message from Gemini in the shared controller
        ChatMessage? lastMessage = sharedMessagesController.messages.firstOrNull;
        if (lastMessage != null && lastMessage.user.id == geminiUser.id) {
          lastMessage.text += response;
          sharedMessagesController.updateLastMessageFrom(geminiUser, lastMessage.text);
        } else {
          ChatMessage message = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: response,
          );
          sharedMessagesController.addMessage(message);
        }
      }, onDone: () {
        // Ensure typing indicator is off when done
        setState(() {
          isTyping = false;
        });
      }, onError: (error) {
        // Handle errors
        print('Error in Gemini API: $error');
        setState(() {
          isTyping = false;
        });

        // Add an error message
        ChatMessage errorMessage = ChatMessage(
          user: geminiUser,
          createdAt: DateTime.now(),
          text: "I'm sorry, I couldn't process that request. Please try again.",
        );
        sharedMessagesController.addMessage(errorMessage);
      });
    } catch (e) {
      print('Error in _sendMessage: $e');
      setState(() {
        isTyping = false;
      });

      // Add an error message if Gemini API fails
      ChatMessage errorMessage = ChatMessage(
        user: geminiUser,
        createdAt: DateTime.now(),
        text: "I'm sorry, I couldn't process that request. Please try again.",
      );
      sharedMessagesController.addMessage(errorMessage);
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await speechToText.initialize(
        onStatus: (status) {
          print('Status: $status');
          if (status == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (error) => print('Error: $error'),
      );
      if (available) {
        print('Starting to listen...');
        setState(() => _isListening = true);
        speechToText.listen(
          onResult: (result) {
            setState(() {
              _text = result.recognizedWords;
              controller.text = _text;

              // Move cursor to the end of text
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            });
            print('Speech recognized: $_text');

            // When result is final, stop listening but keep text in field
            if (result.finalResult) {
              setState(() => _isListening = false);
            }
          },
          listenFor: Duration(seconds: 30), // Longer listening duration
          pauseFor: Duration(seconds: 3),   // Pause after user stops speaking
          cancelOnError: true,
        );
      } else {
        print('Speech recognition not available');
      }
    } else {
      speechToText.stop();
      setState(() => _isListening = false);
    }
  }

  void _sendMediaMessage() async {
    ImagePicker picker = ImagePicker();
    XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      ChatMessage chatMessage = ChatMessage(
        user: currentUser,
        createdAt: DateTime.now(),
        text: "Describe this picture?",
        medias: [
          ChatMedia(
            url: file.path,
            fileName: "",
            type: MediaType.image,
          )
        ],
      );
      _sendMessage(chatMessage);
    }
  }

  void _readAloud(String message) async {
    await flutterTts.speak(message);
    setState(() {
      _isGenerating = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.black87,
        drawer: _drawerUI(),
        appBar: AppBar(
          leading: Builder(builder: (BuildContext context) {
            return IconButton(
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                icon: const Icon(Icons.vertical_split_outlined));
          }),
          title: const Text('Ask Anything'),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 22),
          backgroundColor: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
          actions: [
            // Add a button to create a new chat
            IconButton(
              icon: Icon(Icons.add, color: Colors.white),
              onPressed: () {
                // Start a new conversation using the shared controller
                sharedMessagesController.startNewConversation();
                // Refresh the UI
                setState(() {});
              },
            ),
          ],
        ),
        body: _chatUI());
  }

  Widget _drawerUI() {
    return Drawer(
      child: Container(
        color: Colors.black87,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 44),
              // Container for search (commented out in your original code)
              Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.home_outlined, color: Colors.white),
                    title:
                    Text('New Chat', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      // Use the controller to start a new conversation
                      sharedMessagesController.startNewConversation();
                      setState(() {});
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.history, color: Colors.white),
                    title:
                    Text('History', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      // Navigate to the History screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ScreenHistory()),
                      );
                    },
                  ),
                  const Divider(color: Colors.white),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatUI() {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'Start a new conversation',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          )
              : ListView.builder(
            controller: scrollController,
            itemCount: messages.length + (isTyping ? 1 : 0),
            reverse: true,
            itemBuilder: (context, index) {
              if (index == 0 && isTyping) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BubbleNormal(
                      text: "Typing...",
                      isSender: false,
                      color: Colors.grey,
                    ),
                  ],
                );
              }
              final message = messages[index - (isTyping ? 1 : 0)];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: message.user.id == currentUser.id
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (message.medias != null &&
                            message.medias!.isNotEmpty)
                          Image.file(
                            File(message.medias!.first.url),
                            height: 150,
                            width: 150,
                            fit: BoxFit.cover,
                          ),
                        BubbleNormal(
                          text: message.text,
                          textStyle: TextStyle(color: Colors.white),
                          isSender: message.user.id == currentUser.id,
                          color: message.user.id == currentUser.id
                              ? Colors.grey.shade800
                              : Colors.black45,
                        ),
                      ],
                    ),
                  ),
                  if (message.user.id == geminiUser.id)
                    IconButton(
                      icon: _isGenerating
                          ? const Icon(
                        Icons.volume_off,
                        color: Colors.white60,
                      )
                          : const Icon(
                        Icons.volume_up,
                        color: Colors.white60,
                      ),
                      onPressed: () {
                        if (_isGenerating) {
                          flutterTts.stop();
                          setState(() {
                            _isGenerating = false;
                          });
                        } else {
                          _readAloud(message.text);
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ),
        _textFieldUI(),
      ],
    );
  }

  Widget _textFieldUI() {
    return Padding(
      padding: const EdgeInsets.all(15.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo),
                    onPressed: _sendMediaMessage,
                    color: Colors.white,
                    constraints: BoxConstraints(),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      cursorColor: Colors.white,
                      style: TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (text) {
                        setState(() {});
                      },
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Enter text",
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const VerticalDivider(color: Colors.black, width: 8),
                  IconButton(
                    icon: _isListening
                        ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Waveform(),
                        Icon(Icons.close, color: Colors.red, size: 20),
                      ],
                    )
                        : Icon(
                      controller.text.isEmpty ? Icons.mic : Icons.send,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (_isListening) {
                        // Stop listening if already listening
                        speechToText.stop();
                        setState(() => _isListening = false);
                      } else if (controller.text.isEmpty) {
                        // Start listening if text field is empty
                        _listen();
                      } else {
                        // Send the message if there's text
                        _sendMessage(ChatMessage(
                          user: currentUser,
                          createdAt: DateTime.now(),
                          text: controller.text,
                        ));
                        controller.clear();
                        setState(() {});
                      }
                    },
                    constraints: BoxConstraints(),
                  )
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.headset),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScreenVoiceChat()),
              );
            },
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}