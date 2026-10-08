int readInt(Object? value) => (value as num).toInt();
int? readNullableInt(Object? value) =>
    value == null ? null : (value as num).toInt();
String readString(Object? value) => value?.toString() ?? '';
String? readNullableString(Object? value) => value?.toString();
bool readBool(Object? value) => value as bool? ?? false;
bool? readNullableBool(Object? value) => value as bool?;
DateTime readDateTime(Object? value) => DateTime.parse(value as String);
DateTime? readNullableDateTime(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
Map<String, dynamic> readJsonMap(Object? value) =>
    Map<String, dynamic>.unmodifiable(
      (value as Map?)?.cast<String, dynamic>() ?? const {},
    );
Map<String, dynamic>? readNullableJsonMap(Object? value) => value == null
    ? null
    : Map<String, dynamic>.unmodifiable((value as Map).cast<String, dynamic>());
List<int> readIntList(Object? value) => List<int>.unmodifiable(
  (value as List? ?? const []).map((item) => (item as num).toInt()),
);

/// Lecturas tolerantes: devuelven un valor por defecto en vez de lanzar.
///
/// Las de arriba hacen un cast directo y explotan si el backend cambia el tipo o
/// omite un campo. Estas se usan donde la respuesta puede variar entre versiones
/// o cuando un campo opcional llega ausente.

/// Entero o `fallback` si viene nulo o no es numérico.
int readIntOr(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

/// Fecha en hora local, o `null` si viene vacía o no es parseable.
///
/// Acepta tanto el sufijo `Z` como offsets numéricos, porque la respuesta
/// depende de `USE_TZ` en el backend.
DateTime? readDateOrNull(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
