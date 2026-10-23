import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../core/error_handler.dart';

/// Backend ChatMessage limits (services/ai_coach.py): message ≤ 1000 chars, each history item ≤ 1000 chars,
/// total history text ≤ 4000 chars, and the model only reads the last 10 history messages.
const int kCoachMaxMessageChars = 1000;
const int kCoachMaxHistoryItems = 10;
const int kCoachMaxHistoryTotalChars = 4000;

/// Builds the `history` payload for the AI coach from the chat bubbles (oldest → newest).
/// Client-only bubbles (the static greeting and error bubbles, marked with 'local': 'true') are never sent.
/// Lengths are counted in code points (runes), the same way the backend's Python validator counts them.
@visibleForTesting
List<Map<String, String>> buildCoachHistory(List<Map<String, String>> messages) {
  final turns = <Map<String, String>>[];
  for (final m in messages) {
    if (m['local'] == 'true') continue;
    var text = (m['text'] ?? '').trim();
    if (text.isEmpty) continue;
    if (text.runes.length > kCoachMaxMessageChars) {
      text = String.fromCharCodes(text.runes.take(kCoachMaxMessageChars));
    }
    // 'bot' → 'assistant' so the backend maps the turn to the assistant role
    turns.add({'role': m['role'] == 'user' ? 'user' : 'assistant', 'content': text});
  }
  final recent = turns.length > kCoachMaxHistoryItems
      ? turns.sublist(turns.length - kCoachMaxHistoryItems)
      : turns;
  var total = recent.fold<int>(0, (s, m) => s + m['content']!.runes.length);
  while (total > kCoachMaxHistoryTotalChars && recent.isNotEmpty) {
    total -= recent.removeAt(0)['content']!.runes.length;
  }
  return recent;
}

class ChildCoachScreen extends StatefulWidget {
  const ChildCoachScreen({super.key});

  @override
  State<ChildCoachScreen> createState() => _ChildCoachScreenState();
}

class _ChildCoachScreenState extends State<ChildCoachScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isTyping = false;

  final List<Map<String, String>> _messages = [
    {
      'role': 'bot',
      'text': 'أهلاً يا بطل! أنا صديقك الذكي "فطين" 🤖💰.. اسألني أي حاجة عن الفلوس، إزاي تحوش أسرع، أو إزاي تكسب كوينز في الألعاب!',
      'local': 'true', // static greeting: not part of the conversation history sent to the coach
    },
  ];

  final List<String> _quickQuestions = [
    'إزاي أحوش لشراء عجلة أسرع؟ 🚲',
    'إيه الفرق بين الحاجة والرغبة؟ 🤔',
    'يعني إيه كارت ميزة؟ 💳',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _ask(String question, {bool fromInput = false}) async {
    final q = question.trim();
    if (q.isEmpty) return;
    if (!mounted) return;
    // One request at a time: keeps replies in order and the typed draft untouched
    if (_isTyping) return;
    if (q.runes.length > kCoachMaxMessageChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سؤالك طويل جداً يا بطل! الحد الأقصى 1000 حرف ✂️')),
      );
      return;
    }

    // Previous turns only (the current question is sent as `message`)
    final history = buildCoachHistory(_messages);
    setState(() {
      _messages.add({'role': 'user', 'text': q});
      _isTyping = true;
    });
    if (fromInput) _controller.clear();

    try {
      final res = await ApiClient().post(
        ApiConfig.aiCoach,
        data: {
          'message': q,
          if (history.isNotEmpty) 'history': history,
        },
      );
      final reply = res.data['reply'] ??
          res.data['response'] ??
          'أنا هنا لمساعدتك دائماً يا بطل! 🌟';
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'bot', 'text': reply.toString()});
        _isTyping = false;
      });
    } catch (e) {
      final errMsg = ApiErrorHandler.getErrorMessage(e);
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'bot',
          'text': 'عذراً يا بطل! تعذر الاتصال بـ فطين: $errMsg 🤖',
          'local': 'true', // error bubble: never sent back to the model as history
        });
        _isTyping = false;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('صديقي المالي الذكي (فطين) 🤖'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick Questions
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickQuestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ActionChip(
                    label: Text(_quickQuestions[index], style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.emerald),
                    onPressed: _isTyping ? null : () => _ask(_quickQuestions[index]),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return Align(
                    alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isUser ? AppTheme.navy : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isUser ? 0 : 20),
                          bottomRight: Radius.circular(isUser ? 20 : 0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        msg['text']!,
                        style: TextStyle(
                          color: isUser ? Colors.white : AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('فطين يفكر في الإجابة... 🤖', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),

            // Input
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: kCoachMaxMessageChars,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'اسأل فطين أي سؤال...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                        ),
                      ),
                      onSubmitted: (v) => _ask(v, fromInput: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.emerald,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isTyping ? null : () => _ask(_controller.text, fromInput: true),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
