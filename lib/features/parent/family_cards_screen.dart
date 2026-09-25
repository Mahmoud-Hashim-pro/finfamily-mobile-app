import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/card_model.dart';
import '../../widgets/meeza_card_widget.dart';

class FamilyCardsScreen extends StatefulWidget {
  const FamilyCardsScreen({super.key});

  @override
  State<FamilyCardsScreen> createState() => _FamilyCardsScreenState();
}

class _FamilyCardsScreenState extends State<FamilyCardsScreen> {
  final List<CardModel> _cards = [
    CardModel(
      id: 'card1',
      userId: 'c1',
      cardNumber: '5061 •••• •••• 1234',
      cardholderName: 'Lotfy Hassan',
      status: 'active',
      expiryDate: '12/28',
    ),
    CardModel(
      id: 'card2',
      userId: 'c2',
      cardNumber: '5061 •••• •••• 5678',
      cardholderName: 'Sara Hassan',
      status: 'active',
      expiryDate: '06/29',
    ),
  ];

  void _toggleFreeze(int index) {
    setState(() {
      final current = _cards[index];
      _cards[index] = CardModel(
        id: current.id,
        userId: current.userId,
        cardNumber: current.cardNumber,
        cardholderName: current.cardholderName,
        status: current.isFrozen ? 'active' : 'frozen',
        expiryDate: current.expiryDate,
      );
    });

    final card = _cards[index];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          card.isFrozen
              ? 'تم تجميد كارت ${card.cardholderName} بنجاح 🔒'
              : 'تم فك تجميد كارت ${card.cardholderName} بنجاح 🔓',
        ),
        backgroundColor: card.isFrozen ? AppTheme.coral : AppTheme.emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('كروت ميزة العائلية (Meeza Cards)'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _cards.length,
          separatorBuilder: (_, __) => const SizedBox(height: 32),
          itemBuilder: (context, index) {
            final card = _cards[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      card.cardholderName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: card.isFrozen
                            ? AppTheme.coral.withOpacity(0.12)
                            : AppTheme.emerald.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        card.isFrozen ? 'مجمد 🔒' : 'نشط ومفعل ✅',
                        style: TextStyle(
                          color: card.isFrozen
                              ? AppTheme.coral
                              : AppTheme.emeraldDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                MeezaCardWidget(
                  card: card,
                  showControls: true,
                  onFreezeToggle: () => _toggleFreeze(index),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
