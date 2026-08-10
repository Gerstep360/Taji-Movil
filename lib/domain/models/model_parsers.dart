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
