class MissionModel {
  final String id;
  final String title;
  final String description;
  final double rewardAmount;
  final int rewardXp;
  final String status; // pending, submitted, completed/approved, rejected
  final String kind; // chore, redemption
  final String category;
  final String icon;
  final String dueLabel;
  final String? childId;
  final String? childName;
  final String? proofText;
  final String? proofUrl;

  MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardAmount,
    required this.rewardXp,
    required this.status,
    required this.kind,
    this.category = 'عام',
    this.icon = '🧹',
    this.dueLabel = 'اليوم',
    this.childId,
    this.childName,
    this.proofText,
    this.proofUrl,
  });

  bool get isPending => status == 'pending';
  bool get isSubmitted => status == 'submitted';
  bool get isApproved => status == 'approved' || status == 'completed';
  bool get isRejected => status == 'rejected';
  bool get isChore => kind == 'chore';
  bool get isRedemption => kind == 'redemption';

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    final double parsedReward = ((json['reward'] ?? json['reward_amount'] ?? json['reward_egp'] ?? 0.0) as num).toDouble();
    final int parsedXp = (json['reward_xp'] != null || json['reward_points'] != null || json['reward_coins'] != null)
        ? ((json['reward_xp'] ?? json['reward_points'] ?? json['reward_coins']) as num).toInt()
        : (parsedReward * 10).toInt();

    return MissionModel(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? 'مهمة عائلية',
      description: json['description'] ?? '',
      rewardAmount: parsedReward,
      rewardXp: parsedXp,
      status: json['status'] ?? 'pending',
      kind: json['kind'] ?? 'chore',
      category: json['category'] ?? 'عام',
      icon: json['icon'] ?? (json['kind'] == 'redemption' ? '🏆' : '🧹'),
      dueLabel: json['due_label'] ?? json['dueDate'] ?? 'اليوم',
      childId: (json['assigned_to_id'] ?? json['child_id'])?.toString(),
      childName: json['child_name']?.toString(),
      proofText: json['proof_text'] ?? json['proof'],
      proofUrl: json['proof_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'reward': rewardAmount,
      'reward_xp': rewardXp,
      'status': status,
      'kind': kind,
      'category': category,
      'icon': icon,
      'due_label': dueLabel,
      'assigned_to_id': childId,
      'child_name': childName,
      'proof_text': proofText,
      'proof_url': proofUrl,
    };
  }
}

class GoalModel {
  final String id;
  final String name;
  final double target;
  final double current;
  final String icon;
  final String color;
  final String eta;
  final String aiNote;

  GoalModel({
    required this.id,
    required this.name,
    required this.target,
    required this.current,
    this.icon = '🎯',
    this.color = '#00B894',
    this.eta = '',
    this.aiNote = '',
  });

  double get progress => target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
  double get remaining => (target - current).clamp(0.0, double.infinity);
  bool get isCompleted => target > 0 && current >= target;

  String get computedEta {
    if (isCompleted) return 'مكتمل! 🎉 تم تحقيق الهدف';
    if (current <= 0) return 'ابدأ بالتحويش لتحديد الموعد';
    final rem = remaining;
    final int weeks = (rem / 25.0).ceil();
    if (weeks <= 1) return 'خلال أسبوع تقريباً ⚡';
    if (weeks <= 4) return 'خلال $weeks أسابيع 📅';
    final int months = (weeks / 4.0).ceil();
    return 'خلال $months أشهر بمعدل ادخار أسبوعي';
  }

  String get computedAiNote {
    if (aiNote.isNotEmpty && aiNote != 'استمر في التحويش لتحقيق هدفك!') {
      return aiNote;
    }
    if (isCompleted) {
      return 'مبروك يا بطل! حققت هدفك بنجاح، يمكنك الآن سحب المبلغ أو شراء ما حلمت به!';
    }
    if (current == 0) {
      return 'أول خطوة هي الأهم: تحويش 10 ج.م فقط اليوم يبدأ رحلة إنجاز هذا الهدف! 🚀';
    }
    return 'نصيحة ذكية: تحويش جزء من مكافأة كل مهمة أو لعبة يقرّبك للهدف في نصف الوقت! 💡';
  }

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    final t = (json['target'] as num?)?.toDouble() ?? 100.0;
    final c = (json['current'] as num?)?.toDouble() ?? 0.0;
    return GoalModel(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      target: t,
      current: c,
      icon: json['icon'] ?? '🎯',
      color: json['color'] ?? '#00B894',
      eta: json['eta'] ?? '',
      aiNote: json['ai_note'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'target': target,
      'current': current,
      'icon': icon,
      'color': color,
      'eta': eta,
      'ai_note': aiNote,
    };
  }
}
