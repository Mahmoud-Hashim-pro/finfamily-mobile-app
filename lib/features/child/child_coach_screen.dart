import 'package:flutter/material.dart';
import '../../config/theme.dart';

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
    },
  ];

  final List<String> _quickQuestions = [
    'إزاي أحوش لشراء عجلة أسرع؟ 🚲',
    'إيه الفرق بين الحاجة والرغبة؟ 🤔',
    'يعني إيه كارت ميزة؟ 💳',
  ];

  void _ask(String question) {
    if (question.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': question.trim()});
      _isTyping = true;
    });
    _controller.clear();

    Future.delayed(const Duration(milliseconds: 700), () {
      String answer;
      if (question.contains('عجلة') || question.contains('أحوش')) {
        answer =
            'عشان تشتري العجلة بسرعة: 1️⃣ أنجز كل المهام اليومية في التطبيق. 2️⃣ اطلب من بابا يفعّل ميزة "مطابقة التحويش"، يعني كل 10 جنيه تحوشها يزودلك عليها مكافأة! 🚀';
      } else if (question.contains('الحاجة') || question.contains('الرغبة')) {
        answer =
            'الحاجة = أكل، شرب، كتب المدرسة (حاجات من غيرها منقدرش نعيش). أما الرغبة = لعبة جديدة، شيبسي، كاندي (حاجات حلوة بس ممكن نأجلها عشان نحوش للأهم)! 💡';
      } else {
        answer =
            'كارت ميزة هو كارتك البنكي الذكي الخاص بيك! بابا بيحطلك فيه المصروف، وتقدر تشتري بيه من السوبرماركت وكانتين المدرسة بدون ما تشيل كاش يضيع منك 💳✨';
      }

      setState(() {
        _messages.add({'role': 'bot', 'text': answer});
        _isTyping = false;
      });

      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
                    onPressed: () => _ask(_quickQuestions[index]),
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
                      decoration: InputDecoration(
                        hintText: 'اسأل فطين أي سؤال...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppTheme.cardBorder),
                        ),
                      ),
                      onSubmitted: _ask,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.emerald,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () => _ask(_controller.text),
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
