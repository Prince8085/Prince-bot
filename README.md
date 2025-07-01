# 🤖 My Personal Bot - AI Interview Assistant

Welcome to **My Personal Bot**, your AI-powered interview assistant named *Ask Prince*! This Flutter app leverages speech-to-text and AI to help you practice and prepare for interviews with intelligent, interactive Q&A.

---

## 🚀 Features

- 🎤 **Speech Recognition:** Ask questions using your voice with real-time transcription.
- 💬 **AI Responses:** Get smart, context-aware answers from the AI assistant.
- 📝 **Text Input:** Type your questions manually if you prefer.
- 🔄 **Preloaded Questions:** Quickly select from common interview questions.
- 🔒 **Secure API Key Management:** Uses environment variables to keep your API keys safe.
- 📱 **Cross-Platform:** Runs on Android, iOS, and Web.

---

## 🛠️ Technologies Used

- Flutter & Dart
- speech_to_text package for voice input
- http package for API communication
- flutter_dotenv for environment variable management
- permission_handler for runtime permission requests

---

## 📦 Installation & Setup

1. **Clone the repository:**

```bash
git clone <your-repo-url>
cd my_personal_bot
```

2. **Install dependencies:**

```bash
flutter pub get
```

3. **Set up environment variables:**

- Create a `.env` file inside the `assets` folder.
- Add your Groq API key:

```
GROQ_API_KEY=your_api_key_here
```

4. **Run the app:**

```bash
flutter run
```

---

## 📱 Building APK for Android

- To build APKs split by ABI (recommended):

```bash
flutter build apk --split-per-abi
```

- Install the APK matching your device architecture (e.g., `app-arm64-v8a-release.apk` for most modern devices).

---

## ⚙️ Permissions

- The app requests microphone permission at runtime for speech recognition.
- Ensure you grant microphone access when prompted.

---

## 🐞 Troubleshooting

- If you see a black screen on launch, try running the app in debug mode with `flutter run` to see logs.
- Make sure your `.env` file is correctly set up and API key is valid.
- Check microphone permissions on your device.

---

## 🤝 Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

---

## 📄 License

This project is licensed under the MIT License.

---

## 🙏 Acknowledgements

Thanks to the Flutter community and all package maintainers.

---

Happy coding! 🚀✨
