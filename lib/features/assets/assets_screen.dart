import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_failure.dart';
import '../../core/theme/taji_theme.dart';
import '../../core/utils/camera_permission.dart';
import '../../shared/widgets/taji_drawer.dart';
import 'asset_repository.dart';

/// CU23 consulta móvil; el CRUD administrativo sigue en Web. CU24 lector de activos.
class AssetsScreen extends StatefulWidget {
  const AssetsScreen({this.scanOnly = false, super.key});
  final bool scanOnly;
  @override
  State<AssetsScreen> createState() => _AssetsScreenState();
}

class _AssetsScreenState extends State<AssetsScreen> {
  final _search = TextEditingController(), _payload = TextEditingController();
  late final AssetRepository _repository;
  List<CondominiumAsset> _items = [];
  CondominiumAsset? _identified;
  String? _error;
  bool _loading = false;
  int _page = 1, _pages = 1, _revision = 0;
  @override
  void initState() {
    super.initState();
    _repository = AssetRepository(context.read<ApiClient>());
    if (!widget.scanOnly) unawaited(_load());
  }

  @override
  void dispose() {
    _revision++;
    _search.dispose();
    _payload.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _repository.list(
        search: _search.text.trim(),
        page: _page,
      );
      if (!mounted || revision != _revision) return;
      setState(() {
        _items = result.items;
        _pages = result.pages < 1 ? 1 : result.pages;
      });
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() => _error = _message(e));
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _identify(String payload) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _identified = null;
    });
    try {
      final asset = await _repository.scan(payload);
      if (mounted) setState(() => _identified = asset);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final granted = await CameraPermissionHelper.ensureCameraPermission(
      context,
    );
    if (!mounted) return;
    if (!granted) {
      setState(
        () =>
            _error = 'Puedes habilitar la cámara o pegar el contenido del QR.',
      );
      return;
    }
    final payload = await showDialog<String>(
      context: context,
      builder: (_) => const _AssetScanner(),
    );
    if (!mounted || payload == null) return;
    _payload.text = payload;
    await _identify(payload);
  }

  void _detail(CondominiumAsset asset) {
    final history = _repository.history(asset.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        minChildSize: .45,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    asset.code,
                    style: const TextStyle(
                      color: TajiColors.primaryStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar detalle',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(asset.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('${asset.type} · ${asset.sector} · ${asset.statusLabel}'),
            if (asset.descriptionText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(asset.descriptionText),
              ),
            if (asset.brandText.isNotEmpty || asset.modelText.isNotEmpty)
              Text('Equipo: ${asset.brandText} ${asset.modelText}'),
            if (asset.serial.isNotEmpty) Text('Serie: ${asset.serial}'),
            if (asset.qrUuid.isNotEmpty)
              Center(
                child: QrImageView(
                  data: asset.qrPayload,
                  size: 180,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Código QR del activo ${asset.code}',
                ),
              ),
            const Divider(height: 32),
            Text(
              'Historial del activo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            FutureBuilder<AssetHistory>(
              future: history,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    _message(snapshot.error!),
                    style: const TextStyle(color: TajiColors.danger),
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HistorySection(
                      title: 'Incidencias',
                      entries: data.incidents
                          .map(
                            (e) => (
                              title: e.title,
                              code: e.publicCode,
                              status: e.status,
                            ),
                          )
                          .toList(),
                    ),
                    _HistorySection(
                      title: 'Órdenes de trabajo',
                      entries: data.workOrders
                          .map(
                            (e) => (
                              title: e.title,
                              code: e.publicCode,
                              status: e.status,
                            ),
                          )
                          .toList(),
                    ),
                    _HistorySection(
                      title: 'Planes de mantenimiento',
                      entries: data.maintenancePlans
                          .map(
                            (e) => (
                              title: e.name,
                              code: 'Cada ${e.frequencyDays} días',
                              status: e.isActive ? 'Activo' : 'Inactivo',
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    drawer: const TajiDrawer(),
    appBar: AppBar(
      title: Text(
        widget.scanOnly ? 'Identificar activo' : 'Activos del condominio',
      ),
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: widget.scanOnly ? () async {} : _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              widget.scanOnly
                  ? 'Del código al equipo'
                  : 'Tu inventario, a mano',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              widget.scanOnly
                  ? 'Escanea la etiqueta para consultar el equipo y su historial.'
                  : 'Consulta ubicación e historial. La administración gestiona el inventario desde Web.',
            ),
            const SizedBox(height: 20),
            if (widget.scanOnly) ...[
              FilledButton.icon(
                onPressed: _loading ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear etiqueta QR'),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _payload,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'O pega el contenido del QR',
                  hintText: 'TAJI-ASSET.…',
                ),
                onSubmitted: _identify,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _loading ? null : () => _identify(_payload.text),
                child: const Text('Consultar activo'),
              ),
            ] else
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Buscar por código o nombre',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Buscar activos',
                    onPressed: _loading
                        ? null
                        : () {
                            _page = 1;
                            _load();
                          },
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
                onSubmitted: (_) {
                  _page = 1;
                  _load();
                },
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: TajiColors.danger),
                ),
              ),
            if (_identified != null) _assetTile(_identified!),
            if (!widget.scanOnly) ...[
              const SizedBox(height: 16),
              if (!_loading && _error == null && _items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No encontramos activos para esta búsqueda.'),
                ),
              for (final asset in _items) _assetTile(asset),
              if (_pages > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Página anterior',
                      onPressed: _loading || _page <= 1
                          ? null
                          : () {
                              _page--;
                              _load();
                            },
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('$_page de $_pages'),
                    IconButton(
                      tooltip: 'Página siguiente',
                      onPressed: _loading || _page >= _pages
                          ? null
                          : () {
                              _page++;
                              _load();
                            },
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    ),
  );
  Widget _assetTile(CondominiumAsset asset) => Card(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: TajiColors.border),
    ),
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(16),
      leading: const Icon(
        Icons.inventory_2_outlined,
        color: TajiColors.primary,
      ),
      title: Text(
        asset.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text('${asset.code} · ${asset.sector}\n${asset.statusLabel}'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _detail(asset),
    ),
  );
}

class _HistorySection extends StatelessWidget {
  const _HistorySection({required this.title, required this.entries});
  final String title;
  final List<({String title, String code, String status})> entries;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (entries.isEmpty) const Text('Sin registros todavía.'),
        for (final entry in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.title),
            subtitle: Text('${entry.code} · ${entry.status}'),
          ),
      ],
    ),
  );
}

class _AssetScanner extends StatefulWidget {
  const _AssetScanner();
  @override
  State<_AssetScanner> createState() => _AssetScannerState();
}

class _AssetScannerState extends State<_AssetScanner>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _finished = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_camera.start());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_finished) {
      unawaited(_camera.start());
    } else {
      unawaited(_camera.stop());
    }
  }

  @override
  void dispose() {
    _finished = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Apunta a la etiqueta del activo')),
              IconButton(
                tooltip: 'Cerrar cámara',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(
                controller: _camera,
                errorBuilder: (_, __) => const Center(
                  child: Text(
                    'No pudimos abrir la cámara. Usa el código manual.',
                  ),
                ),
                onDetect: (capture) {
                  if (_finished || !mounted) return;
                  final values = capture.barcodes
                      .map((e) => e.rawValue)
                      .whereType<String>();
                  if (values.isEmpty) return;
                  _finished = true;
                  unawaited(_camera.stop());
                  Navigator.pop(context, values.first);
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

String _message(Object error) => error is ApiFailure
    ? error.displayMessage
    : 'No pudimos completar la consulta. Inténtalo de nuevo.';
