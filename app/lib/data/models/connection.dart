/// One electricity meter the user tracks, e.g. "Ghar".
class Connection {
  const Connection({
    required this.id,
    required this.nickname,
    this.disco,
    this.referenceNo,
    required this.createdAt,
  });

  final String id;
  final String nickname;
  final String? disco; // filled from first bill
  final String? referenceNo; // filled from first bill
  final DateTime createdAt;

  Connection copyWith({String? disco, String? referenceNo}) => Connection(
        id: id,
        nickname: nickname,
        disco: disco ?? this.disco,
        referenceNo: referenceNo ?? this.referenceNo,
        createdAt: createdAt,
      );

  factory Connection.fromJson(Map<String, dynamic> json) => Connection(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        disco: json['disco'] as String?,
        referenceNo: json['reference_no'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'disco': disco,
        'reference_no': referenceNo,
        'created_at': createdAt.toIso8601String(),
      };
}
