import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../core/error_handler.dart';

/// Backend ChatMessage limits (services/ai_coach.py): each history item ≤ 1000 chars, total history text
/// ≤ 4000 chars, and the model only reads the last 10 history messages (C15).
const int _kParentCoachMaxItemChars = 1000;
const int _kParentCoachMaxHistoryItems = 10;
const int _kParentCoachMaxHistoryTotalChars = 4000;

/// Builds the `history` payload (oldest → newest) from the chat bubbles that came BEFORE the message being sent.
/// Client-only bubbles (the static greeting and error bubbles, marked with 'local': 'true') are never sent.
/// Lengths are counted in code points (runes), the same way the backend's Python validator counts them.
@visibleForTesting
List<Map<String, String>> buildParentCoachHistory(List<Map<String, String>> messages) {
  final turns = <Map<String, String>>[];
  for (final m in messages) {
    if (m['local'] == 'true') continue;
    var text = (m['text'] ?? '').trim();
    if (text.isEmpty) continue;
    if (text.runes.length > _kParentCoachMaxItemChars) {
      text = String.fromCharCodes(text.runes.take(_kParentCoachMaxItemChars));
    }
    turns.add({'role': m['role'] == 'user' ? 'user' : 'assistant', 'content': text});
  }
  final recent = turns.length > _kParentCoachMaxHistoryItems
      ? turns.sublist(turns.length - _kParentCoachMaxHistoryItems)
      : turns;
  var total = recent.fold<int>(0, (s, m) => s + m['content']!.runes.length);
  while (total > _kParentCoachMaxHistoryTotalChars && recent.isNotEmpty) {
    total -= recent.removeAt(0)['content']!.runes.length;
  }
  return recent;
}

class ParentCoachScreen extends StatefulWidget {
  const ParentCoachScreen({super.key});

  @override
  State<ParentCoachScreen> createState() => _ParentCoachScreenState();
}

class _ParentCoachScreenState extends State<ParentCoachScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'text':
          'أهلاً بك! أنا مستشارك المالي الذكي في FinFamily 🤖. كيف أساعدك اليوم في تنظيم مصاريف عائلتك أو تعليم أولادك عادات مالية ذكية؟',
      'local': 'true', // static greeting: not part of the conversation history sent to the coach
    },
  ];

  final List<String> _quickPrompts = [
    'إزاي أحدد مصروف مناسب لابني (10 سنين)؟',
    'إيه أفضل طريقة لتشجيعهم على الادخار؟',
    'ازاي أعلمهم الفرق بين الاحتياج والرغبة؟',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    // One request at a time: keeps replies in question order and the typing indicator accurate
    if (_isTyping) return;

    if (!mounted) return;
    // History = the conversation so far, excluding the message being sent (C15)
    final history = buildParentCoachHistory(_messages);
    setState(() {
      _messages.add({'role': 'user', 'text': text.trim()});
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final res = await ApiClient().post(
        ApiConfig.aiCoach,
        data: {
          'message': text.trim(),
          if (history.isNotEmpty) 'history': history,
        },
      );
      final reply = res.data['reply'] ?? res.data['response'] ?? 'أنا هنا لمساعدتك دائماً!';
      if (!mounted) return;
      setState(() {
        _messages.add({'role': 'assistant', 'text': reply});
        _isTyping = false;
      });
    } catch (e) {
      final errMsg = ApiErrorHandler.getErrorMessage(e);
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': 'تعذر الاتصال بالمستشار المالي: $errMsg. يرجى المحاولة مرة أخرى.',
          'local': 'true', // client-side error bubble: never sent back as history
        });
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('المستشار المالي الذكي 🤖'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick Suggestion Chips
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = _quickPrompts[index];
                  return ActionChip(
                    label: Text(prompt, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.cardBorder),
                    onPressed: _isTyping ? null : () => _sendMessage(prompt),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isUser ? AppTheme.navy : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isUser ? 0 : 18),
                          bottomRight: Radius.circular(isUser ? 18 : 0),
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'المستشار يكتب الآن...',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'اسأل عن التربية المالية أو المصروف...',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppTheme.cardBorder),
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.navy,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isTyping ? null : () => _sendMessage(_messageController.text),
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
