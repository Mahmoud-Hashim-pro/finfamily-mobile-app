import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/card_model.dart';

class MeezaCardWidget extends StatefulWidget {
  final CardModel card;
  final VoidCallback? onFreezeToggle;
  final bool showControls;

  const MeezaCardWidget({
    super.key,
    required this.card,
    this.onFreezeToggle,
    this.showControls = false,
  });

  @override
  State<MeezaCardWidget> createState() => _MeezaCardWidgetState();
}

class _MeezaCardWidgetState extends State<MeezaCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isBackVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _flipCard() {
    if (_controller.isAnimating) return;
    if (_isBackVisible) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {
      _isBackVisible = !_isBackVisible;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _flipCard,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final angle = _animation.value * pi;
              final isUnder = angle > (pi / 2);

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: isUnder
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(pi),
                        child: _buildCardBack(),
                      )
                    : _buildCardFront(),
              );
            },
          ),
        ),
        if (widget.showControls) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _flipCard,
                icon: const Icon(Icons.flip, size: 18),
                label: Text(
                  _isBackVisible ? 'عرض واجهة الكارت' : 'قلب الكارت (الخلف)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: widget.onFreezeToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.card.isFrozen
                      ? AppTheme.emerald
                      : AppTheme.coral,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: Icon(
                  widget.card.isFrozen ? Icons.lock_open : Icons.lock,
                  size: 18,
                ),
                label: Text(
                  widget.card.isFrozen ? 'إلغاء التجميد' : 'تجميد الكارت',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCardFront() {
    return Container(
      width: double.infinity,
      height: 215,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.card.isFrozen
              ? [const Color(0xFF475569), const Color(0xFF1E293B)]
              : [const Color(0xFF0F2D52), const Color(0xFF1E40AF), const Color(0xFF0D9488)],
        ),
        boxShadow: [
          BoxShadow(
            color: (widget.card.isFrozen ? Colors.black : const Color(0xFF0F2D52))
                .withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background subtle pattern
          Positioned(
            right: -30,
            bottom: -30,
            child: Icon(
              Icons.credit_card,
              size: 160,
              color: Colors.white.withOpacity(0.04),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Meeza logo & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'meeza',
                          style: TextStyle(
                            color: AppTheme.navyDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'ميزة',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (widget.card.isFrozen)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'مجمد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Icon(Icons.contactless, color: Colors.white70, size: 26),
                ],
              ),

              // Chip
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2C974),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFC7A747)),
                    ),
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 20,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF9E7E2C), width: 1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Card Number
              Text(
                widget.card.cardNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 2.2,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Cardholder & Expiry
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حامل الكارت',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      Text(
                        widget.card.cardholderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'صالح حتى',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                      Text(
                        widget.card.expiryDate ?? '12/28',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      width: double.infinity,
      height: 215,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Magnetic Strip
          Container(
            width: double.infinity,
            height: 40,
            color: Colors.black87,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Signature / CVV bar
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 34,
                        color: Colors.white70,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Text(
                          'AUTHORIZED SIGNATURE',
                          style: TextStyle(fontSize: 8, color: Colors.black54),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 34,
                        color: Colors.white,
                        alignment: Alignment.center,
                        child: const Text(
                          '•••',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'كارت محاكاة تعليمي مخصص للتدريب المالي للأطفال ولا يُستخدم في المعاملات البنكية الحقيقية.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
