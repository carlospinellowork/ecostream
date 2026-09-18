/// Usuário autenticado.
///
/// Só contém dados de perfil. Nada de credencial: hash e salt vivem no
/// armazenamento seguro, isolados em `AuthCredential`.
class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  /// Forma canônica do e-mail, usada como chave de busca de conta.
  ///
  /// E-mail não diferencia maiúsculas na prática: quem cadastra `Joao@Gmail.com`
  /// precisa conseguir entrar digitando `joao@gmail.com`.
  static String normalizeEmail(String email) => email.trim().toLowerCase();

  String get normalizedEmail => normalizeEmail(email);

  /// Primeiro nome, para saudações. "Carlos Eduardo Pinello" → "Carlos".
  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Usuário';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Iniciais para o avatar: até duas letras. "Carlos Pinello" → "CP".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.avatarUrl == avatarUrl &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, email, avatarUrl, createdAt);

  @override
  String toString() => 'UserModel(id: $id, email: $email)';
}
