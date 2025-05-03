import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ai_assistant/Controllers/SharedMessagesController.dart';

class ScreenVoiceChat extends StatefulWidget {
  @override
  _VoiceChatState createState() => _VoiceChatState();
}

class _VoiceChatState extends State<ScreenVoiceChat>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final Gemini gemini = Gemini.instance;
  FlutterTts flutterTts = FlutterTts();

  late stt.SpeechToText speechToText;
  bool _isListening = false;
  bool isGenerating = false;
  String _text = '';
  // Add flag to track if the widget is still mounted
  bool _isMounted = true;
  // Add variable to store active stream subscription
  dynamic _activeStreamSubscription;
  // Add a timer variable to cancel delayed operations
  dynamic _listenTimeoutTimer;

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
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    speechToText = stt.SpeechToText();
    _initSpeech();

    flutterTts.setLanguage("en-US");
    flutterTts.setPitch(1.0);
    flutterTts.setSpeechRate(0.5);
    _listen();
  }

  void _sendMessage(ChatMessage chatMessage) {
    // Add message to the shared controller
    sharedMessagesController.addMessage(chatMessage);

    try {
      String question = chatMessage.text;
      StringBuffer responseBuffer = StringBuffer();

      if (_isMounted) {
        setState(() {
          isGenerating = true;
        });
      }

      // Store the stream subscription so we can cancel it later
      _activeStreamSubscription = gemini
          .streamGenerateContent(
        question,
      )
          .listen((event) async {
        String response = event.output.toString();
        responseBuffer.write(response);

        // First response chunk - create a new message
        if (responseBuffer.length == response.length) {
          ChatMessage geminiMessage = ChatMessage(
            user: geminiUser,
            createdAt: DateTime.now(),
            text: responseBuffer.toString(),
          );
          sharedMessagesController.addMessage(geminiMessage);
        } else {
          // Update existing message with the growing response
          sharedMessagesController.updateLastMessageFrom(geminiUser, responseBuffer.toString());
        }

        // Only update the UI if the widget is still mounted
        if (_isMounted) {
          setState(() {});
        }
      }, onDone: () async {
        String finalResponse = responseBuffer.toString();

        // Ensure the final response is stored in the shared controller
        sharedMessagesController.updateLastMessageFrom(geminiUser, finalResponse);

        // Only continue with TTS if the widget is still mounted
        if (_isMounted) {
          await flutterTts.speak(finalResponse);

          flutterTts.setCompletionHandler(() {
            if (_isMounted) {
              setState(() {
                isGenerating = false;
              });
              _listen();
            }
          });
        }
      });
    } catch (e) {
      print(e);
    }
  }

  void _listen() async {
    // Cancel any existing timer to prevent memory leaks
    _listenTimeoutTimer?.cancel();

    if (!_isListening && _isMounted) {
      bool available = await speechToText.initialize(
        onStatus: (status) => print('Status: $status'),
        onError: (error) => print('Error: $error'),
      );
      if (available && _isMounted) {
        print('Starting to listen...');
        setState(() {
          isGenerating = false;
          _isListening = true;
          _text = '';  // Reset the text
        });

        // Start listening
        speechToText.listen(
          onResult: (result) {
            if (_isMounted) {
              setState(() {
                _text = result.recognizedWords;
              });
              print('Speech recognized: $_text');
              if (result.finalResult) {
                ChatMessage chatMessage = ChatMessage(
                  user: currentUser,
                  createdAt: DateTime.now(),
                  text: _text,
                );
                _sendMessage(chatMessage);
                setState(() => _isListening = false);
              }
            }
          },
        );

        // Add a timeout to stop listening if there's no input
        _listenTimeoutTimer = Future.delayed(Duration(seconds: 5), () {
          if (_text.isEmpty && _isListening && _isMounted) {
            speechToText.stop();
            setState(() {
              _isListening = false;
            });
          }
        });
      } else {
        print('Speech recognition not available');
      }
    } else if (_isListening) {
      speechToText.stop();
      if (_isMounted) {
        setState(() => _isListening = false);
      }
    }
  }

  void _stopTTS() async {
    if (isGenerating) {
      await flutterTts.stop();
      if (_isMounted) {
        setState(() {
          isGenerating = false;
          _isListening = false;
        });
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

  @override
  void dispose() {
    // Mark that this widget is no longer mounted
    _isMounted = false;

    // Cancel animation controller
    _controller.dispose();

    // Stop text-to-speech
    flutterTts.stop();

    // Stop speech recognition
    if (_isListening) {
      speechToText.stop();
      _isListening = false;
    }

    // Cancel any active stream subscription
    _activeStreamSubscription?.cancel();

    // Cancel any active timers
    _listenTimeoutTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // Handle the back action, e.g., Navigator.pop(context);
                Navigator.pop(context);
              },
              tooltip: 'Back',
            ),
          ],
        ),

        SizedBox(height: 240),
        Text(
          _isListening ? 'Listening...' : (isGenerating ? 'Generating...' : ''),
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              decoration: TextDecoration.none
          ),
        ),
        SizedBox(height: 20),

        SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Box(0.8, 0.8, 4, _controller, Colors.grey.withOpacity(0.2)),
              Box(0.6, 0.6, 3, _controller, Colors.grey.withOpacity(0.4)),
              Box(0.4, 0.4, 2, _controller, Colors.grey.withOpacity(0.6)),
              Box(0.2, 0.2, 1, _controller, Colors.grey.withOpacity(0.8)),
              Box(0.1, 0.1, 0, _controller, Colors.grey),
              LogoBox(_controller),
            ],
          ),
        ),

        SizedBox(height: 80),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.stop, color: Colors.red),
              onPressed: isGenerating ? _stopTTS : null,
              tooltip: 'Stop',
              iconSize: 28,
            ),
            SizedBox(width: 40),
            IconButton(
              icon: Icon(Icons.mic, color: Colors.green),
              onPressed: !_isListening && !isGenerating ? _listen : null,
              tooltip: 'Start Listening',
              iconSize: 28,
            ),
          ],
        )
      ],
    );
  }
}

class Box extends StatelessWidget {
  final double scaleFactor;
  final double borderFactor;
  final int delay;
  final AnimationController controller;
  final Color borderColor;

  Box(this.scaleFactor, this.borderFactor, this.delay, this.controller,
      this.borderColor);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        double animationValue =
            sin((controller.value + delay * 0.2) * pi * 2) * 0.15 + 1.0;
        return Transform.scale(
          scale: animationValue,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: 2,
              ),
            ),
            width: 250 * scaleFactor,
            height: 250 * scaleFactor,
          ),
        );
      },
    );
  }
}

class LogoBox extends StatelessWidget {
  final AnimationController controller;

  LogoBox(this.controller);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Icon(
          Icons.music_note, // Replace with your desired icon or SVG.
          color: controller.value < 0.5 ? Colors.grey : Colors.white,
          size: 80,
        );
      },
    );
  }
}