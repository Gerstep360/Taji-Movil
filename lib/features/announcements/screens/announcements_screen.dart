import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/taji_theme.dart';
import '../../../domain/models/notification_models.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../../shared/widgets/taji_drawer.dart';
import '../data/announcements_repository.dart';
import '../state/announcements_controller.dart';
import '../../../core/network/api_client.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AnnouncementsController _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final apiClient = context.read<ApiClient>();
    _controller = AnnouncementsController(AnnouncementsRepository(apiClient))
      ..loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'URGENT':
        return Colors.red.shade700;
      case 'HIGH':
        return Colors.orange.shade800;
      case 'NORMAL':
        return const Color(0xFF4F46E5);
      case 'LOW':
      default:
        return Colors.grey.shade600;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showAnnouncementDetail(AnnouncementModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(item.priority).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.priority,
                      style: TextStyle(
                        color: _getPriorityColor(item.priority),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Audiencia: ${item.audience}',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              if (item.publishedAt != null)
                Text(
                  'Publicado el ${_formatDate(item.publishedAt!)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              const Divider(height: 24),
              Text(
                item.body,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
              if (item.expiresAt != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.amber.shade900, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aviso válido hasta: ${_formatDate(item.expiresAt!)}',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comunicados y Avisos'),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.loadAll(),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: TajiColors.primary,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: TajiColors.primary,
            tabs: [
              const Tab(
                icon: Icon(Icons.campaign_outlined),
                text: 'Comunicados',
              ),
              Consumer<AnnouncementsController>(
                builder: (_, c, __) => Tab(
                  icon: Badge(
                    isLabelVisible: c.unreadCount > 0,
                    label: Text('${c.unreadCount}'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  text: 'Notificaciones',
                ),
              ),
            ],
          ),
        ),
        drawer: const TajiDrawer(),
        body: Consumer<AnnouncementsController>(
          builder: (context, controller, _) {
            if (controller.isLoading &&
                controller.announcements.isEmpty &&
                controller.notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: COMUNICADOS
                RefreshIndicator(
                  onRefresh: controller.loadAll,
                  child: Column(
                    children: [
                      if (controller.error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: StatusBanner(message: controller.error!),
                        ),
                      // Chips de filtro por audiencia
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            FilterChip(
                              label: const Text('Todos'),
                              selected: controller.selectedAudience == null,
                              onSelected: (_) => controller.filterByAudience(null),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Residentes'),
                              selected: controller.selectedAudience == 'RESIDENTS',
                              onSelected: (_) => controller.filterByAudience('RESIDENTS'),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Personal'),
                              selected: controller.selectedAudience == 'STAFF',
                              onSelected: (_) => controller.filterByAudience('STAFF'),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Seguridad'),
                              selected: controller.selectedAudience == 'SECURITY',
                              onSelected: (_) => controller.filterByAudience('SECURITY'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: controller.announcements.isEmpty
                            ? Center(
                                child: Text(
                                  'No hay comunicados disponibles.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: controller.announcements.length,
                                itemBuilder: (context, index) {
                                  final item = controller.announcements[index];
                                  final priorityColor = _getPriorityColor(item.priority);

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.grey.shade200),
                                    ),
                                    elevation: 0,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _showAnnouncementDetail(item),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: priorityColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  item.priority,
                                                  style: TextStyle(
                                                    color: priorityColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (item.publishedAt != null)
                                                  Text(
                                                    _formatDate(item.publishedAt!),
                                                    style: TextStyle(
                                                      color: Colors.grey.shade500,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              item.body,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),

                // TAB 2: NOTIFICACIONES
                RefreshIndicator(
                  onRefresh: controller.loadAll,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Row(
                          children: [
                            Text(
                              controller.unreadCount > 0
                                  ? '${controller.unreadCount} no leídas'
                                  : 'Todas al día',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            if (controller.unreadCount > 0)
                              TextButton(
                                onPressed: () => controller.markAllAsRead(),
                                child: const Text('Marcar todas como leídas'),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: controller.notifications.isEmpty
                            ? Center(
                                child: Text(
                                  'No tienes notificaciones.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: controller.notifications.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = controller.notifications[index];
                                  final isUnread = item.readAt == null;

                                  return Material(
                                    color: isUnread
                                        ? const Color(0xFFEEF2FF)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () {
                                        if (isUnread) controller.markAsRead(item.id);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              isUnread
                                                  ? Icons.mark_email_unread_outlined
                                                  : Icons.mail_outline,
                                              color: isUnread
                                                  ? TajiColors.primary
                                                  : Colors.grey.shade500,
                                              size: 22,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.title,
                                                    style: TextStyle(
                                                      fontWeight: isUnread
                                                          ? FontWeight.bold
                                                          : FontWeight.w600,
                                                      fontSize: 15,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.message,
                                                    style: TextStyle(
                                                      color: Colors.grey.shade700,
                                                      fontSize: 13,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _formatDate(item.createdAt),
                                                    style: TextStyle(
                                                      color: Colors.grey.shade500,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
