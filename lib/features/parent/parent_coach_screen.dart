import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';

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

    setState(() {
      _messages.add({'role': 'user', 'text': text.trim()});
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final res = await ApiClient().post(
        ApiConfig.aiCoach,
        data: {'prompt': text.trim()},
      );
      final reply = res.data['reply'] ?? res.data['response'] ?? 'أنا هنا لمساعدتك دائماً!';
      setState(() {
        _messages.add({'role': 'assistant', 'text': reply});
        _isTyping = false;
      });
    } catch (_) {
      // Intelligent fallback answer if offline
      await Future.delayed(const Duration(seconds: 1));
      String fallbackAnswer;
      if (text.contains('مصروف')) {
        fallbackAnswer =
            'المعيار الشائع في مصر هو حساب المصروف الأسبوعي بمعدل (العمر × 10 أو 15 ج.م) أسبوعياً مع تقسيمها: 50% مصاريف شخصية، 30% ادخار في حصالة كارت ميزة، و20% للمهام.';
      } else if (text.contains('ادخار')) {
        fallbackAnswer =
            'أفضل طريقة هي "مطابقة الادخار" (Parental Match): اتفق مع طفلك إن كل 10 جنيه هيحوشها في الهدف بتاعه، أنت هتزود له عليها 5 جنيه تشجيعية!';
      } else {
        fallbackAnswer =
            'خطوة ممتازة! تعليم الأطفال الوعي المالي بيعتمد على الممارسة العملية مش النظري. تطبيق FinFamily بيساعدهم يجربوا ويغلطوا في بيئة آمنة تماماً.';
      }

      setState(() {
        _messages.add({'role': 'assistant', 'text': fallbackAnswer});
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
                    onPressed: () => _sendMessage(prompt),
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
                      onPressed: () => _sendMessage(_messageController.text),
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
