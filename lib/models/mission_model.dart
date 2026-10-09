class MissionModel {
  final String id;
  final String title;
  final String description;
  final double rewardAmount;
  final int rewardXp;
  final String status; // pending, submitted, approved, rejected
  final String kind; // chore, redemption
  final String? childId;
  final String? childName;

  MissionModel({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardAmount,
    this.rewardXp = 50,
    required this.status,
    required this.kind,
    this.childId,
    this.childName,
  });

  bool get isPending => status == 'pending';
  bool get isSubmitted => status == 'submitted';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory MissionModel.fromJson(Map<String, dynamic> json) {
    return MissionModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      rewardAmount: ((json['reward'] ?? json['reward_amount'] ?? 0.0) as num).toDouble(),
      rewardXp: json['reward_xp'] ?? 50,
      status: json['status'] ?? 'pending',
      kind: json['kind'] ?? 'chore',
      childId: json['child_id'],
      childName: json['child_name'],
    );
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

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    return GoalModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      target: (json['target'] as num?)?.toDouble() ?? 100.0,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      icon: json['icon'] ?? '🎯',
      color: json['color'] ?? '#00B894',
      eta: json['eta'] ?? '',
      aiNote: json['ai_note'] ?? '',
    );
  }
}
