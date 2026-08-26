import 'package:flutter/material.dart';
import '../../core/models/activity_log_model.dart';
import '../../core/services/activity_log_service.dart';
import '../../core/theme/app_colors.dart';

class ActivityLogWidget extends StatelessWidget {
  final ActivityLogService logService;
  final String? entityId; // null = show all farm logs

  const ActivityLogWidget({
    super.key,
    required this.logService,
    this.entityId,
  });

  @override
  Widget build(BuildContext context) {
    final stream = entityId != null
        ? logService.logsForEntity(entityId!)
        : logService.logsForFarm();

    return StreamBuilder<List<ActivityLogModel>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snap.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 48, color: AppColors.textTertiary),
                const SizedBox(height: 8),
                Text('Henüz kayıt yok',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _LogTile(log: logs[i]),
        );
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  final ActivityLogModel log;
  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(log.action);
    final icon = _entityIcon(log.entityType);
    final dateStr = _formatDate(log.timestamp);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.border, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(log.action.label,
                            style: TextStyle(
                                fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(log.entityName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (log.details != null) ...[
                    const SizedBox(height: 2),
                    Text(log.details!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(log.userName,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary)),
                      const Spacer(),
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _actionColor(LogAction a) {
    switch (a) {
      case LogAction.eklendi: return const Color(0xFF2E7D32);
      case LogAction.guncellendi: return const Color(0xFFE65100);
      case LogAction.silindi: return const Color(0xFFC62828);
    }
  }

  IconData _entityIcon(String type) {
    switch (type) {
      case 'animal': return Icons.pets_rounded;
      case 'vehicle': return Icons.agriculture_rounded;
      case 'building': return Icons.home_work_rounded;
      case 'vaccination': return Icons.vaccines_rounded;
      case 'milkRecord': return Icons.water_drop_rounded;
      case 'fuelRecord': return Icons.local_gas_station_rounded;
      case 'maintenance': return Icons.build_rounded;
      default: return Icons.history_rounded;
    }
  }

  String _formatDate(DateTime dt) {
    final d = '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
    final t = '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
    return '$d $t';
  }
}
