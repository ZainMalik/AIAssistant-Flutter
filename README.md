# AI Assistant

A modern, feature-rich AI Assistant built with Flutter that leverages Google's Gemini API for powerful conversations and image recognition capabilities.

## ✨ Features

- 💬 **Text Chat**: Engage in natural conversations with the AI
- 🔊 **Voice Interaction**: Speak to the assistant and hear responses
- 📱 **Multimodal Input**: Send images for the AI to analyze
- 🌓 **Dark Mode**: Sleek dark UI for comfortable usage
- 📚 **Conversation History**: Save and revisit previous conversations
- 🔄 **Real-time Streaming**: See the AI responses as they're generated

## 🛠️ Technologies Used

- **Flutter**: Cross-platform UI framework
- **Gemini API**: For powerful AI responses
- **dash_chat_2**: For the chat interface
- **flutter_tts**: For text-to-speech functionality
- **speech_to_text**: For speech recognition
- **image_picker**: For selecting images from gallery

## 🚀 Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) (v3.0.0+)
- [Dart](https://dart.dev/get-dart) (v2.17.0+)
- [Android Studio](https://developer.android.com/studio) or [Xcode](https://developer.apple.com/xcode/) (for deployment)
- [Google Gemini API Key](https://ai.google.dev/)

### Installation

#### Clone the repository

```bash
git clone https://github.com/yourusername/ai-assistant.git
cd ai-assistant
```

#### Install dependencies

```bash
flutter pub get
```

#### Configure API Key

1. Create a `.env` file in the root directory
2. Add your Gemini API key:
   ```
   GEMINI_API_KEY=your_api_key_here
   ```

### Setting up for Android

1. Ensure you have Android Studio installed with SDK tools
2. Connect an Android device or set up an emulator
3. Enable USB debugging on your device
4. Configure your `android/app/build.gradle` file:
   ```gradle
   defaultConfig {
       applicationId "com.yourusername.ai_assistant"
       minSdkVersion 21
       targetSdkVersion 33
   }
   ```
5. Run the app:
   ```bash
   flutter run
   ```

### Setting up for iOS

1. Ensure you have Xcode installed (MacOS only)
2. Configure your `ios/Runner/Info.plist` to include necessary permissions:
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>This app needs microphone access for voice conversations with the AI.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>This app needs photo library access to analyze images.</string>
   <key>NSSpeechRecognitionUsageDescription</key>
   <string>This app needs speech recognition for voice input.</string>
   ```
3. Open iOS simulator or connect an iOS device
4. Run the app:
   ```bash
   flutter run
   ```

## 📋 Project Structure

```
lib/
├── Controllers/
│   └── SharedMessagesController.dart
├── Models/
│   └── ...
├── Screens/
│   ├── ScreenHome.dart
│   ├── ScreenHistory.dart
│   ├── ScreenSplash.dart
│   └── ScreenVoiceChat.dart
├── Utils/
│   └── Waveform.dart
├── Widgets/
│   └── ...
└── main.dart
```

## 🧪 Running Tests

```bash
flutter test
```

## 📦 Building for Production

### Android APK

```bash
flutter build apk --release
```
The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`

### iOS IPA

```bash
flutter build ipa --release
```
Open the generated Xcode project and archive the app for distribution.

## 🔍 Troubleshooting

### Common Issues

1. **API Key not working**
   - Verify your API key is correctly entered in the `.env` file
   - Check if you have billing set up for the Gemini API

2. **Microphone permissions**
   - Ensure microphone permissions are granted in device settings
   - Check that `permission_handler` is properly implemented

3. **Build Errors**
   - Try running `flutter clean` and then `flutter pub get`
   - Make sure your Flutter and Dart versions are up to date

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
