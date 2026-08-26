import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../../../../core/services/activity_log_service.dart';
import '../../../../core/models/activity_log_model.dart';
import '../../../../shared/widgets/activity_log_widget.dart';

class FarmActivityLogPage extends ConsumerStatefulWidget {
  const FarmActivityLogPage({super.key});

  @override
  ConsumerState<FarmActivityLogPage> createState() => _FarmActivityLogPageState();
}

class _FarmActivityLogPageState extends ConsumerState<FarmActivityLogPage> {
  String? _selectedEntityType; // null = all

  static final _filterOptions = <({String label, String? value})>[
    (label: 'Tümü', value: null),
    (label: 'Hayvan', value: 'animal'),
    (label: 'Araç', value: 'vehicle'),
    (label: 'Yapı', value: 'building'),
    (label: 'Aşı', value: 'vaccination'),
    (label: 'Süt', value: 'milkRecord'),
    (label: 'Bakım', value: 'maintenance'),
  ];

  @override
  Widget build(BuildContext context) {
    final logService = ref.read(activityLogServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Log Kayıtları'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((opt) {
                  final selected = _selectedEntityType == opt.value;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(opt.label),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedEntityType = opt.value);
                      },
                      selectedColor: AppColors.primarySurface,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Log list
          Expanded(
            child: _selectedEntityType == null
                ? ActivityLogWidget(logService: logService)
                : _FilteredLogList(
                    logService: logService,
                    entityType: _selectedEntityType!,
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilteredLogList extends StatelessWidget {
  final ActivityLogService logService;
  final String entityType;

  const _FilteredLogList({
    required this.logService,
    required this.entityType,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ActivityLogModel>>(
      stream: logService.logsForFarmFiltered(entityType),
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
          itemBuilder: (_, i) => _LogCard(log: logs[i]),
        );
      },
    );
  }
}

class _LogCard extends StatelessWidget {
  final ActivityLogModel log;
  const _LogCard({required this.log});

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
    final d = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d $t';
  }

  @override
  Widget build(BuildContext context) {
    final color = _actionColor(log.action);
    final icon = _entityIcon(log.entityType);

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
              width: 36, height: 36,
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
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(log.entityName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  if (log.details != null) ...[
                    const SizedBox(height: 2),
                    Text(log.details!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(log.userName, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                      const Spacer(),
                      const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textTertiary),
                      const SizedBox(width: 3),
                      Text(_formatDate(log.timestamp), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
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
}
