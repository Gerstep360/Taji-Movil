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
    this.residentUnits = const [],
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String phone;
  final TajiRole? role;
  final List<Map<String, dynamic>> residentUnits;

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
    residentUnits: List<Map<String, dynamic>>.from(
      (json['resident_units'] as List? ?? const [])
          .whereType<Map<String, dynamic>>(),
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'first_name': firstName,
    'last_name': lastName,
    'full_name': fullName,
    'phone': phone,
    'role': role?.toJson(),
    'resident_units': residentUnits,
  };
}

/// Comprobaciones de permisos para la interfaz.
///
/// El backend es la autoridad: `POST /visit-qr/validate/` exige el permiso
/// `validate_visits` y que la ficha de personal esté activa. Estas extensiones
/// solo evitan mostrar una acción que el servidor va a rechazar; nunca
/// sustituyen la validación del servidor.
extension TajiUserAccess on TajiUser {
  bool hasPermission(String code) => role?.permissions.contains(code) ?? false;

  /// Personal de seguridad y administración: puede escanear y validar QR en
  /// portería. El rol `seguridad` y el `administrador` lo tienen; el resto no.
  bool get canValidateVisits => hasPermission('validate_visits');

  /// Residentes y administración: pueden emitir el QR de sus visitas. El rol
  /// `seguridad` queda excluido a propósito, igual que en el backend.
  bool get canIssueVisitQr =>
      hasPermission('register_visits') || hasPermission('manage_visits');

  bool get isAdmin => role?.slug == 'administrador';

  /// CU13 móvil: consulta y operación del turno propio del guardia.
  bool get canUseSecurityShifts =>
      const [
        'seguridad',
        'guardia',
        'security',
      ].contains(role?.slug.toLowerCase()) ||
      hasPermission('operate_security_shifts') ||
      hasPermission('view_security_shifts');
}
