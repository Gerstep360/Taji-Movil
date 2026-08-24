class TajiRole {
  const TajiRole({
    required this.slug,
    required this.name,
    required this.description,
    required this.permissions,
  });

  final String slug;
  final String name;
  final String description;
  final List<String> permissions;

  factory TajiRole.fromJson(Map<String, dynamic> json) => TajiRole(
    slug: json['slug'] as String? ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    permissions: List<String>.from(json['permissions'] as List? ?? const []),
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'name': name,
    'description': description,
    'permissions': permissions,
  };
}

class TajiUser {
  const TajiUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.phone,
    this.role,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phone;
  final TajiRole? role;

  String get initials {
    final first = firstName.isEmpty ? '' : firstName[0];
    final last = lastName.isEmpty ? '' : lastName[0];
    return '$first$last'.toUpperCase();
  }

  factory TajiUser.fromJson(Map<String, dynamic> json) => TajiUser(
    id: json['id'] as int,
    email: json['email'] as String? ?? '',
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    fullName: json['full_name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    role: json['role'] is Map<String, dynamic>
        ? TajiRole.fromJson(json['role'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'full_name': fullName,
    'phone': phone,
    'role': role?.toJson(),
  };
}
