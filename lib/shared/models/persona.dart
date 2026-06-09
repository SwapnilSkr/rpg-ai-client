class Persona {
  final String id;
  final String name;
  final String gender;
  final int? age;
  final String description;
  final String otherInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Persona({
    required this.id,
    required this.name,
    required this.gender,
    this.age,
    this.description = '',
    this.otherInfo = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      gender: (json['gender'] ?? 'non_binary').toString(),
      age: (json['age'] as num?)?.toInt(),
      description: (json['description'] ?? '').toString(),
      otherInfo: (json['other_info'] ?? '').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
