import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_badge.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../providers/documents_provider.dart';

class DocumentsPage extends ConsumerWidget {
  const DocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(documentsNotifierProvider);

    final expired = docs.where((d) => d.isExpired).toList();
    final expiringSoon = docs.where((d) => d.isExpiringSoon && !d.isExpired).toList();
    final valid = docs.where((d) => !d.isExpired && !d.isExpiringSoon).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Evraklar')),
      body: docs.isEmpty
          ? const AppEmptyState(
              icon: Icons.description_rounded,
              title: 'Evrak bulunamadı',
              subtitle: 'Araç, yapı ve hayvan kartlarından belge ekleyebilirsiniz',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (expired.isNotEmpty) ...[
                  _SectionHeader('Süresi Dolmuş', AppColors.error, Icons.error_rounded),
                  const SizedBox(height: 8),
                  ...expired.map((d) => _DocCard(doc: d)),
                  const SizedBox(height: 20),
                ],
                if (expiringSoon.isNotEmpty) ...[
                  _SectionHeader('Yakında Bitiyor (≤10 gün)', AppColors.warning, Icons.warning_amber_rounded),
                  const SizedBox(height: 8),
                  ...expiringSoon.map((d) => _DocCard(doc: d)),
                  const SizedBox(height: 20),
                ],
                if (valid.isNotEmpty) ...[
                  _SectionHeader('Geçerli', AppColors.success, Icons.check_circle_rounded),
                  const SizedBox(height: 8),
                  ...valid.map((d) => _DocCard(doc: d)),
                ],
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  const _SectionHeader(this.title, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

class _DocCard extends ConsumerWidget {
  final EntityDocument doc;
  const _DocCard({required this.doc});

  Color get _color {
    if (doc.isExpired) return AppColors.error;
    if (doc.isExpiringSoon) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_rounded, color: _color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Row(children: [
                AppBadge(
                    label: doc.docType.label,
                    color: AppColors.primarySurface,
                    textColor: AppColors.primary,
                    small: true),
                const SizedBox(width: 6),
                Text(doc.entityName,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(doc.entityType.label,
                      style: const TextStyle(fontSize: 10, color: AppColors.textTertiary)),
                ),
              ]),
              if (doc.expiryDate != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.event_rounded, size: 12, color: _color),
                  const SizedBox(width: 3),
                  Text(
                    doc.isExpired
                        ? 'Süresi doldu — ${AppDateUtils.formatDate(doc.expiryDate)}'
                        : doc.isExpiringSoon
                            ? '${doc.daysUntilExpiry} gün kaldı — ${AppDateUtils.formatDate(doc.expiryDate)}'
                            : AppDateUtils.formatDate(doc.expiryDate),
                    style: TextStyle(fontSize: 11, color: _color,
                        fontWeight: (doc.isExpired || doc.isExpiringSoon) ? FontWeight.w600 : FontWeight.w400),
                  ),
                ]),
              ],
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 18, color: AppColors.textTertiary),
            onPressed: () => ref.read(documentsNotifierProvider.notifier).delete(doc.id),
          ),
        ]),
      ),
    );
  }
}
