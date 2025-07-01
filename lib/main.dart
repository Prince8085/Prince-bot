import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  await dotenv.load();
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('Building TestApp UI');
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test UI')),
        body: const Center(child: Text('Hello, this is a test UI to check rendering.')),
      ),
    );
  }
}

class AskPrinceApp extends StatelessWidget {
  const AskPrinceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ask Prince – Your AI Interview Assistant',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 10,
            shadowColor: Colors.amberAccent,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
          bodyMedium: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
      home: const AskPrinceHomePage(),
    );
  }
}

class AskPrinceHomePage extends StatefulWidget {
  const AskPrinceHomePage({super.key});

  @override
  State<AskPrinceHomePage> createState() => _AskPrinceHomePageState();
}

class _AskPrinceHomePageState extends State<AskPrinceHomePage> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _transcribedText = '';
  final TextEditingController _textController = TextEditingController();
  String _answer = '';
  bool _isLoading = false;

  // Added a function to handle streaming chat completions from Groq API
  Future<void> fetchGroqChatCompletionStream(
      String userMessage, void Function(String) onData) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GROQ_API_KEY is not set in .env file');
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });

    final body = {
      "messages": [
        {
          "role": "system",
          "content":
              '''You are Prince Kachhwaha, a passionate and results-driven Full-Stack Engineer with over 2 years of experience. You’re currently working at Innovixsolutions.in while pursuing a B.Tech in AI & Machine Learning from MITS Gwalior. You specialize in building full-stack applications, AI-powered systems, and cloud infrastructure that solve real-world business problems.

You speak clearly, using simple, confident English like you're talking to a colleague, interviewer, or client. You always keep it professional, practical, and outcome-focused. When asked anything about your skills, background, projects, strengths, work experience, or goals — you respond as yourself, using this tone and based on the following details:

Built 14+ real-world projects including trading bots, mobile apps, LinkedIn automation tools, and AI prediction systems

Delivered 500K+ business impact, with 99.9% system uptime and serving 50K+ global users

Known for your expertise in React, Next.js, Node.js, Python, TensorFlow, Flutter, AWS, and automation tools

Strong ability to simplify complex challenges, collaborate across teams, and ship production-grade software fast

Developed smart solutions that saved 40+ hours/week, achieved 78% trading success rate, and 85–94% ML accuracy

Actively contributing to startup projects, research, and client success across AI, web, mobile, and cloud domains

You’re passionate about building high-performance, secure, scalable systems that actually make a difference

Always speak as Prince — humble, smart, and focused on results. Avoid jargon unless asked, and explain things like a pro who’s easy to work with.'''
        },
        {"role": "user", "content": userMessage}
      ],
      "model": "llama-3.3-70b-versatile",
      "temperature": 1,
      "max_completion_tokens": 1024,
      "top_p": 1,
      "stream": true,
      "stop": null
    };

    request.body = jsonEncode(body);

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      final respBody = await streamedResponse.stream.bytesToString();
      throw Exception(
          'Failed to fetch chat completion: \u0007Status: \u0007\u0007${streamedResponse.statusCode}, Body: $respBody');
    }

    // Listen to the stream and parse chunks
    final utf8Stream = streamedResponse.stream.transform(utf8.decoder);

    await for (final chunk in utf8Stream) {
      // The stream may send multiple JSON objects or SSE events
      // Try to parse each chunk as JSON
      try {
        // The chunk may contain multiple JSON objects separated by newlines
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          // The API might prefix data with 'data: ' in SSE style
          final jsonString =
              line.startsWith('data: ') ? line.substring(6) : line;
          if (jsonString == '[DONE]') {
            // Stream finished
            break;
          }
          final Map<String, dynamic> jsonData = jsonDecode(jsonString);
          final content = jsonData['choices']?[0]?['delta']?['content'];
          if (content != null) {
            onData(content);
          }
        }
      } catch (e) {
        // Ignore parse errors for partial chunks
      }
    }
  }

  final List<String> _preloadedQuestions = [
    'Tell me about yourself.',
    'What are your strengths?',
    'What are your weaknesses?',
    'Why do you want to work here?',
    'Describe a challenging project you worked on.',
    'How do you handle tight deadlines?',
    'What is your experience with React and Next.js?',
    'Explain a machine learning project you have done.',
    'How do you ensure system uptime and reliability?',
    'What motivates you in your work?',
  ];

  final String _systemPrompt =
      "You are Prince Kachhwaha, a Full-Stack Engineer and AI/ML Specialist with 2+ years of experience, currently working at Innovixsolutions.in while pursuing a B.Tech in AI & Machine Learning from MITS Gwalior. You've delivered 14+ full-stack projects, generated \$500K+ business impact, maintained 99.9% uptime, and saved clients 40+ hours/week via automation.\n\nYour tone is simple, confident, professional like you’re talking to a colleague or an interviewer. Avoid jargon unless asked. Explain real-world examples with results and business impact. Always speak as Prince — humble, smart, and focused on solving problems and building production-grade software.";

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _startListening() async {
    // Request microphone permission at runtime
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        // Permission denied, show a message or handle accordingly
        setState(() {
          _answer = 'Microphone permission is required to use this feature.';
        });
        return;
      }
    }

    bool available = await _speech.initialize(
      onStatus: (val) {
        if (val == 'done' || val == 'notListening') {
          setState(() {
            _isListening = false;
          });
          if (_transcribedText.isNotEmpty) {
            _sendQuestion(_transcribedText);
          }
        }
      },
      onError: (val) {
        setState(() {
          _isListening = false;
        });
      },
    );
    if (available) {
      setState(() {
        _isListening = true;
        _transcribedText = '';
      });
      _speech.listen(
        onResult: (val) {
          setState(() {
            _transcribedText = val.recognizedWords;
          });
        },
      );
    }
  }

  Future<void> _sendQuestion(String question) async {
    setState(() {
      _isLoading = true;
      _answer = '';
    });

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${dotenv.env['GROQ_API_KEY']}',
    };
    final body = jsonEncode({
      'model': 'llama-3.3-70b-versatile',
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': question},
      ],
      'temperature': 1,
      'max_completion_tokens': 1024,
      'top_p': 1,
      'stream': false,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'];
        if (choices != null && choices.isNotEmpty) {
          final answer = choices[0]['message']['content'];
          setState(() {
            _answer = answer;
          });
        } else {
          setState(() {
            _answer = 'No answer received from API.';
          });
        }
      } else {
        setState(() {
          _answer =
              'Failed to fetch answer. Status code: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _answer = 'Error occurred: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clear() {
    setState(() {
      _transcribedText = '';
      _textController.clear();
      _answer = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask Prince – Your AI Interview Assistant'),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Mic Icon
            Center(
              child: GestureDetector(
                onTap: _isListening ? null : _startListening,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _isListening ? Colors.amberAccent : Colors.amber[700],
                    boxShadow: _isListening
                        ? [
                            BoxShadow(
                              // ignore: deprecated_member_use
                              color: Colors.amberAccent.withOpacity(0.7),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ]
                        : [],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Text input field
            TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[900],
                hintText: 'Type your question here...',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.amber),
                  onPressed: () {
                    final question = _textController.text.trim();
                    if (question.isNotEmpty) {
                      _sendQuestion(question);
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                final question = value.trim();
                if (question.isNotEmpty) {
                  _sendQuestion(question);
                }
              },
            ),
            const SizedBox(height: 16),

            // Section 3: Pre-defined questions list
            Expanded(
              child: ListView.builder(
                itemCount: _preloadedQuestions.length,
                itemBuilder: (context, index) {
                  final question = _preloadedQuestions[index];
                  return Card(
                    color: Colors.grey[900],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      title: Text(
                        question,
                        style: const TextStyle(color: Colors.amber),
                      ),
                      onTap: () {
                        _sendQuestion(question);
                      },
                    ),
                  );
                },
              ),
            ),

            // Section 4: Answer Display
            Container(
              height: 150,
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    )
                  : SingleChildScrollView(
                      child: Text(
                        _answer.isEmpty
                            ? 'Your answer will appear here.'
                            : _answer,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Buttons Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    final question = _textController.text.trim();
                    if (question.isNotEmpty) {
                      _sendQuestion(question);
                    }
                  },
                  child: const Text('Ask Question'),
                ),
                ElevatedButton(
                  onPressed: _isListening ? null : _startListening,
                  child: const Text('Start Listening'),
                ),
                ElevatedButton(onPressed: _clear, child: const Text('Clear')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
