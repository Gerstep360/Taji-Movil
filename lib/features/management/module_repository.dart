import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import 'module_catalog.dart';

typedef ResourceRow = Map<String, dynamic>;

class ResourcePage {
  const ResourcePage(this.items, this.pages);
  final List<ResourceRow> items;
  final int pages;
  factory ResourcePage.fromJson(Object? data) {
    final entries = data is List
        ? data
        : data is Map
        ? data['results']
        : null;
    if (entries is! List) {
      throw const ApiFailure(
        code: 'invalid_response',
        message: 'El servidor no devolvió una lista válida.',
      );
    }
    final count = data is Map
        ? ((data['pagination'] as Map?)?['total_pages'] as int? ?? 1)
        : 1;
    return ResourcePage(
      entries
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList(growable: false),
      count < 1 ? 1 : count,
    );
  }
}

class ModuleRepository {
  const ModuleRepository(this.api);
  final ApiClient api;
  Future<ResourcePage> list(
    MobileModule module, {
    int page = 1,
    String search = '',
  }) async => ResourcePage.fromJson(
    await api.get<dynamic>(
      module.endpoint,
      query: {
        'page': page,
        'page_size': 25,
        if (search.isNotEmpty) 'search': search,
      },
    ),
  );
  Future<ResourceRow> save(
    MobileModule module,
    ResourceRow values, {
    ResourceRow? original,
  }) async {
    final dynamic data = original == null
        ? await api.post<dynamic>(module.endpoint, data: values)
        : await api.patch<dynamic>(
            '${module.endpoint}${Uri.encodeComponent('${original[module.identity]}')}${module.editSuffix}',
            data: values,
          );
    if (data is! Map) {
      throw const ApiFailure(
        code: 'invalid_response',
        message:
            'No se pudo confirmar el cambio. Actualiza antes de volver a guardar.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  Future<List<ResourceRow>> options(String key) async {
    final module = mobileModules[key];
    if (module == null) throw StateError('Catálogo no disponible.');
    final result = <ResourceRow>[];
    // Las opciones también respetan la paginación; nunca solicitar page_size sin límite.
    var page = 1, pages = 1;
    do {
      final response = await list(module, page: page);
      result.addAll(response.items);
      pages = response.pages;
      page++;
      if (result.length > 2000) {
        throw StateError(
          'Hay demasiadas opciones. Usa la gestión Web para este registro.',
        );
      }
    } while (page <= pages);
    return result;
  }

  Future<List<ResourceRow>> permissions() async => ResourcePage.fromJson(
    await api.get<dynamic>('/roles/permissions/'),
  ).items;
}
