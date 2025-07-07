import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  await dotenv.load();
  runApp(const AskPrinceApp());
}

// Removed print statement from TestApp build method
class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Removed print statement for production
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Test UI')),
        body: const Center(
            child: Text('Hello, this is a test UI to check rendering.')),
      ),
    );
  }
}

// Updated InterviewHistoryScreen to accept List<Map<String, String>> and display question-answer pairs
class InterviewHistoryScreen extends StatelessWidget {
  final List<Map<String, String>> history;

  const InterviewHistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interview History'),
      ),
      body: ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, index) {
          final entry = history[index];
          final question = entry['question'] ?? '';
          final answer = entry['answer'] ?? '';
          return ListTile(
            title: Text('Q: $question'),
            subtitle: Text('A: $answer'),
          );
        },
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
          ),
        ),
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Ask Prince'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome to Ask Prince – Your AI Interview Assistant! 🎤🤖',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'This app helps you practice interview questions using voice or text input.\n\nPlease grant microphone permission when prompted to use voice features.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AskPrinceHomePage(),
                  ),
                );
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
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
  bool _isVoiceResponseEnabled = true;
  String _transcribedText = '';
  final TextEditingController _textController = TextEditingController();
  String _answer = '';
  bool _isLoading = false;

  bool _isInterviewActive = false;
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _history = [];

  String? _lastSentQuestion;

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

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startListening() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
        if (!status.isGranted) {
          setState(() {
            _transcribedText = 'Microphone permission denied';
          });
          _showError('Microphone permission denied.');
          return;
        }
      }

      bool available = await _speech.initialize(
        onStatus: (status) async {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
            if (_isInterviewActive) {
              // Restart listening automatically during interview
              await Future.delayed(const Duration(milliseconds: 200));
              await _startListening();
            }
          }
        },
        onError: (errorNotification) {
          setState(() {
            _transcribedText = 'Error: ${errorNotification.errorMsg}';
            _isListening = false;
          });
          _showError('Speech recognition error: ${errorNotification.errorMsg}');
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _transcribedText = '';
          _lastSentQuestion = null;
        });
        _speech.listen(
          onResult: (result) async {
            String recognized = result.recognizedWords.trim();
            setState(() {
              _transcribedText = recognized;
            });

            // Improved question detection
            bool isQuestion = false;
            final lower = recognized.toLowerCase();
            final questionWords = [
              'what',
              'how',
              'why',
              'when',
              'where',
              'who',
              'which',
              'do',
              'does',
              'is',
              'are',
              'can',
              'could',
              'would',
              'should'
            ];

            if (recognized.endsWith('?')) {
              isQuestion = true;
            } else {
              for (var word in questionWords) {
                if (lower.startsWith('$word ')) {
                  isQuestion = true;
                  break;
                }
              }
            }

            if (isQuestion && recognized != _lastSentQuestion) {
              _lastSentQuestion = recognized;
              await _sendQuestion(_lastSentQuestion!);
              setState(() {
                _transcribedText = '';
              });
            }
          },
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 3),
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
            cancelOnError: true,
            listenMode: stt.ListenMode.confirmation,
          ),
        );
      } else {
        setState(() {
          _transcribedText = 'Speech recognition not available';
          _isListening = false;
        });
        _showError('Speech recognition not available.');
      }
    } catch (e) {
      _showError(
          'Failed to start listening. Please check microphone permissions.');
    }
  }

  Future<void> _sendQuestion(String question) async {
    setState(() {
      _isLoading = true;
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
            _history.insert(0, {'question': question, 'answer': answer});
          });
        } else {
          setState(() {
            _answer = 'No answer received from API.';
          });
          _showError('No answer received from API.');
        }
      } else {
        setState(() {
          _answer =
              'Failed to fetch answer. Status code: ${response.statusCode}';
        });
        _showError(
            'Failed to fetch answer. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _answer = 'Error occurred: $e';
      });
      _showError('Failed to get answer. Please try again.');
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
      _history.clear();
    });
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _startInterview() async {
    setState(() {
      _isInterviewActive = true;
      _history.clear();
      _transcribedText = '';
      _answer = '';
    });
    await _startListening();
  }

  void _stopInterview() {
    _stopListening();
    setState(() {
      _isInterviewActive = false;
    });
  }

  void _sendTranscribedQuestion() async {
    if (_transcribedText.trim().isEmpty) return;
    String question = _transcribedText.trim();
    setState(() {
      _transcribedText = '';
      _isLoading = true;
    });
    await _sendQuestion(question);
    setState(() {
      _isLoading = false;
    });
    // Scroll to bottom to show latest answer
    await Future.delayed(const Duration(milliseconds: 300));
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMicIcon() {
    return Icon(
      _isListening ? Icons.mic : Icons.mic_none,
      color: _isListening ? Colors.red : Colors.grey,
      size: 32,
    );
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
            if (_isInterviewActive) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: _buildMicIcon(),
                    label: const Text('Start Interview'),
                    onPressed: _isInterviewActive || _isLoading
                        ? null
                        : _startInterview,
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _isInterviewActive && !_isLoading
                        ? _stopInterview
                        : null,
                    child: const Text('Stop Interview'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: _isInterviewActive &&
                            !_isLoading &&
                            _transcribedText.trim().isNotEmpty
                        ? _sendTranscribedQuestion
                        : null,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send Question'),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed:
                        _history.isNotEmpty && !_isLoading ? _clear : null,
                    child: const Text('Clear History'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _history.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _history.length) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _transcribedText.isEmpty
                              ? 'Listening...'
                              : _transcribedText,
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                        ),
                      );
                    }
                    final item = _history[index];
                    return ListTile(
                      title: Text('Q: ${item['question'] ?? ''}'),
                      subtitle: Text('A: ${item['answer'] ?? ''}'),
                    );
                  },
                ),
              ),
            ] else ...[
              // Section 1: Mic Icon
              Center(
                child: GestureDetector(
                  onTap: _isListening || _isLoading ? null : _startListening,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _isListening ? Colors.amberAccent : Colors.amber[700],
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                  color: Colors.amberAccent.withAlpha(179),
                                  blurRadius: 20,
                                  spreadRadius: 5)
                            ]
                          : [],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return ScaleTransition(scale: animation, child: child);
                      },
                      child: Icon(
                        key: ValueKey<bool>(_isListening),
                        _isListening ? Icons.mic : Icons.mic_none,
                        size: 48,
                        color: Colors.black,
                      ),
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
                    onPressed: _isLoading
                        ? null
                        : () {
                            final question = _textController.text.trim();
                            if (question.isNotEmpty) {
                              _sendQuestion(question);
                            }
                          },
                  ),
                ),
                onSubmitted: _isLoading
                    ? null
                    : (value) {
                        final question = value.trim();
                        if (question.isNotEmpty) {
                          _sendQuestion(question);
                        }
                      },
              ),

              const SizedBox(height: 8),

              // Voice Response Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Voice Response',
                    style: TextStyle(color: Colors.white),
                  ),
                  Switch(
                    value: _isVoiceResponseEnabled,
                    activeColor: Colors.amber[700],
                    onChanged: _isLoading
                        ? null
                        : (bool value) {
                            setState(() {
                              _isVoiceResponseEnabled = value;
                            });
                          },
                  ),
                ],
              ),

              const SizedBox(height: 8),

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
                        onTap:
                            _isLoading ? null : () => _sendQuestion(question),
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
                    onPressed: _isLoading
                        ? null
                        : () {
                            final question = _textController.text.trim();
                            if (question.isNotEmpty) {
                              _sendQuestion(question);
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Ask Question'),
                  ),
                  ElevatedButton(
                    onPressed:
                        _isListening || _isLoading ? null : _startListening,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Start Listening'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    InterviewHistoryScreen(history: _history),
                              ),
                            );
                          },
                    child: const Text('View History'),
                  ),
                  ElevatedButton(
                    onPressed:
                        _history.isNotEmpty && !_isLoading ? _clear : null,
                    child: const Text('Clear History'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
