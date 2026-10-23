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
      'status': 'success',
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _retry(Map<String, String> errorMsg) {
    if (!mounted) return;
    if (_isTyping) return;
    final q = errorMsg['failed_question'] ?? '';
    if (q.isEmpty) return;
    setState(() {
      _messages.remove(errorMsg);
    });
    _sendMessage(q, isRetry: true);
  }

  Future<void> _sendMessage(String text, {bool isRetry = false}) async {
    final q = text.trim();
    if (q.isEmpty) return;
    if (!mounted) return;
    // One request at a time: keeps replies in question order and the typing indicator accurate
    if (_isTyping) return;
    if (q.runes.length > _kParentCoachMaxItemChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرسالة طويلة جداً. الحد الأقصى 1000 حرف')),
      );
      return;
    }

    final bool hasUserBubble = isRetry &&
        _messages.isNotEmpty &&
        _messages.last['role'] == 'user' &&
        _messages.last['text'] == q;

    // History = the conversation so far, excluding the message being sent (C15)
    final history = buildParentCoachHistory(
        hasUserBubble ? _messages.sublist(0, _messages.length - 1) : _messages);

    setState(() {
      if (!hasUserBubble) {
        _messages.add({'role': 'user', 'text': q});
      }
      _isTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final res = await ApiClient().post(
        ApiConfig.aiCoach,
        data: {
          'message': q,
          if (history.isNotEmpty) 'history': history,
        },
      );
      if (!mounted) return;

      final reply = res.data['reply']?.toString() ??
          res.data['response']?.toString() ??
          'أنا هنا لمساعدتك دائماً!';
      final status = res.data['status']?.toString() ?? 'success';
      final requestId = res.data['request_id']?.toString();

      setState(() {
        if (status == 'emergency_disabled' || status == 'quota_exceeded') {
          _messages.add({
            'role': 'assistant',
            'text': reply,
            'status': status,
            'local': 'true', // informative notice: never sent back in history
            if (requestId != null) 'request_id': requestId,
          });
        } else if (status == 'rate_limited' || status == 'timeout') {
          _messages.add({
            'role': 'assistant',
            'text': reply,
            'status': status,
            'local': 'true', // error bubble: never sent back in history
            'failed_question': q,
            if (requestId != null) 'request_id': requestId,
          });
        } else if (status == 'refusal') {
          _messages.add({
            'role': 'assistant',
            'text': reply,
            'status': 'refusal',
            if (requestId != null) 'request_id': requestId,
          });
        } else {
          // 'success' or default
          _messages.add({
            'role': 'assistant',
            'text': reply,
            'status': 'success',
            if (requestId != null) 'request_id': requestId,
          });
        }
        _isTyping = false;
      });
    } catch (e) {
      final errMsg = ApiErrorHandler.getErrorMessage(e);
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': 'تعذر الاتصال بالمستشار المالي: $errMsg. يرجى المحاولة مرة أخرى.',
          'status': 'error',
          'local': 'true', // client-side error bubble: never sent back as history
          'failed_question': q,
        });
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  Widget _buildBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    final status = msg['status'] ?? 'success';
    final text = msg['text'] ?? '';
    final hasRetry = (status == 'rate_limited' || status == 'timeout' || status == 'error') &&
        msg['failed_question'] != null &&
        msg['failed_question']!.isNotEmpty;

    if (isUser) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.navy,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.zero,
              bottomRight: Radius.circular(18),
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
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    // Assistant messages: informative notice bubble for emergency_disabled or quota_exceeded
    if (status == 'emergency_disabled' || status == 'quota_exceeded') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB), // Soft warm amber
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.zero,
            ),
            border: Border.all(color: const Color(0xFFFDE68A)),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'quota_exceeded' ? Icons.hourglass_top_rounded : Icons.info_outline,
                    color: const Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status == 'quota_exceeded' ? 'تنبيه: تم بلوغ الحد المسموح ⏳' : 'تنويه هام 📢',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF78350F),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (msg['request_id'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  'معرّف الطلب: ${msg['request_id']}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Assistant messages: error bubble with retry action button for rate_limited, timeout, or network error
    if (status == 'rate_limited' || status == 'timeout' || status == 'error') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2), // Soft rose/red
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.zero,
            ),
            border: Border.all(color: const Color(0xFFFECACA)),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFDC2626),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status == 'rate_limited'
                        ? 'تم تجاوز حد الطلبات مؤقتاً ⏳'
                        : (status == 'timeout' ? 'انتهت مهلة الانتظار ⏱️' : 'تعذر الاتصال ⚠️'),
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Color(0xFF7F1D1D),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (msg['request_id'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  'معرّف الطلب: ${msg['request_id']}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
              if (hasRetry) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: _isTyping
                        ? null
                        : () {
                            if (!mounted) return;
                            _retry(msg);
                          },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text(
                      'إعادة المحاولة',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFB91C1C),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Assistant messages: gentle safety redirect message for refusal
    if (status == 'refusal') {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), // Gentle soft emerald
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.zero,
            ),
            border: Border.all(color: const Color(0xFFBBF7D0)),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: AppTheme.emerald,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'توجيه المستشار المالي 🛡️',
                    style: TextStyle(
                      color: AppTheme.emeraldDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                text,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (msg['request_id'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  'معرّف الطلب: ${msg['request_id']}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Standard assistant message ('success')
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.zero,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            if (msg['request_id'] != null) ...[
              const SizedBox(height: 6),
              Text(
                'معرّف الطلب: ${msg['request_id']}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
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
                    onPressed: _isTyping
                        ? null
                        : () {
                            if (!mounted) return;
                            _sendMessage(prompt);
                          },
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
                  return _buildBubble(_messages[index]);
                },
              ),
            ),

            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
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
                      maxLength: _kParentCoachMaxItemChars,
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: 'اسأل عن التربية المالية أو المصروف...',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          borderSide: BorderSide(color: AppTheme.cardBorder),
                        ),
                      ),
                      onSubmitted: (v) {
                        if (!mounted) return;
                        _sendMessage(v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.navy,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _isTyping
                          ? null
                          : () {
                              if (!mounted) return;
                              _sendMessage(_messageController.text);
                            },
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
