import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/pdf_viewer_page.dart';
import '../../../../core/models/document_model.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/di/providers.dart';
import '../../../../core/services/storage_service.dart';
import '../../../farms/presentation/providers/farm_provider.dart';
import '../providers/documents_provider.dart';
import '../../../../shared/widgets/app_card.dart';

void showDocumentAddForm(
  BuildContext context,
  WidgetRef ref, {
  required String entityId,
  required EntityType entityType,
  required String entityName,
  required List<DocType> availableDocTypes,
  EntityDocument? existing,
  VoidCallback? onDismissed,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _DocFormSheet(
      existing: existing,
      entityId: entityId,
      entityType: entityType,
      entityName: entityName,
      availableDocTypes: availableDocTypes,
      onSave: (doc) async {
        if (existing == null) {
          await ref.read(documentsNotifierProvider.notifier).add(doc);
        } else {
          await ref.read(documentsNotifierProvider.notifier).update(doc);
        }
        if (ctx.mounted) Navigator.pop(ctx);
      },
    ),
  ).whenComplete(() {
    if (onDismissed != null) onDismissed();
  });
}

class EntityDocumentsSection extends ConsumerWidget {
  final String entityId;
  final EntityType entityType;
  final String entityName;
  final List<DocType> availableDocTypes;

  const EntityDocumentsSection({
    super.key,
    required this.entityId,
    required this.entityType,
    required this.entityName,
    required this.availableDocTypes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(entityDocumentsProvider(entityId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Belgeler',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => showDocumentAddForm(context, ref,
                entityId: entityId, entityType: entityType,
                entityName: entityName, availableDocTypes: availableDocTypes),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Belge Ekle'),
          ),
        ]),
        const SizedBox(height: 8),
        if (docs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(children: [
              Icon(Icons.description_outlined, color: AppColors.textTertiary, size: 20),
              SizedBox(width: 10),
              Text('Henüz belge eklenmemiş.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          )
        else
          Column(
            children: docs.map((doc) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DocumentTile(
                doc: doc,
                onEdit: () => showDocumentAddForm(context, ref,
                    entityId: entityId, entityType: entityType,
                    entityName: entityName, availableDocTypes: availableDocTypes,
                    existing: doc),
                onDelete: () async {
                  if (doc.fileUrl != null && doc.fileName != null) {
                    final farmId = ref.read(activeFarmIdProvider) ?? ref.read(currentUserIdProvider) ?? '';
                    await ref.read(storageServiceProvider).deleteDocument(
                      farmId: farmId, docId: doc.id, fileName: doc.fileName!);
                  }
                  ref.read(documentsNotifierProvider.notifier).delete(doc.id);
                },
              ),
            )).toList(),
          ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final EntityDocument doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _DocumentTile({required this.doc, required this.onEdit, required this.onDelete});

  Color get _statusColor {
    if (doc.isExpired) return AppColors.error;
    if (doc.isExpiringSoon) return AppColors.warning;
    return doc.expiryDate != null ? AppColors.success : AppColors.primary;
  }

  IconData get _docIcon => doc.hasPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_docIcon, color: _statusColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(6)),
                child: Text(doc.docType.label,
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
              ),
              if (doc.expiryDate != null) ...[
                const SizedBox(width: 8),
                Icon(
                  doc.isExpired ? Icons.error_rounded : doc.isExpiringSoon ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                  size: 12, color: _statusColor,
                ),
                const SizedBox(width: 3),
                Flexible(child: Text(
                  doc.isExpired
                      ? 'Süresi doldu (${AppDateUtils.formatDate(doc.expiryDate)})'
                      : doc.isExpiringSoon
                          ? '${doc.daysUntilExpiry} gün kaldı'
                          : AppDateUtils.formatDate(doc.expiryDate),
                  style: TextStyle(fontSize: 11, color: _statusColor,
                      fontWeight: (doc.isExpired || doc.isExpiringSoon) ? FontWeight.w600 : FontWeight.w400),
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            ]),
            if (doc.fileName != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.attach_file_rounded, size: 11, color: AppColors.textTertiary),
                const SizedBox(width: 3),
                Flexible(child: Text(doc.fileName!, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ]),
        ),
        if (doc.fileUrl != null)
          IconButton(
            icon: Icon(
              doc.hasPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              size: 20, color: AppColors.primary,
            ),
            tooltip: 'Aç',
            onPressed: () => _openFile(context, doc),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Düzenle'),
            ])),
            const PopupMenuItem(value: 'delete', child: Row(children: [
              Icon(Icons.delete_rounded, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Text('Sil', style: TextStyle(color: AppColors.error)),
            ])),
          ],
        ),
      ]),
    );
  }

  void _openFile(BuildContext context, EntityDocument doc) {
    final url = doc.fileUrl!;
    final isPdf = doc.hasPdf;
    if (isPdf) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(url: url, title: doc.title),
        ),
      );
    } else {
      // Görsel — tam ekran göster
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => _ImageViewerPage(url: url, title: doc.title),
        ),
      );
    }
  }
}

class _DocFormSheet extends ConsumerStatefulWidget {
  final EntityDocument? existing;
  final String entityId;
  final EntityType entityType;
  final String entityName;
  final List<DocType> availableDocTypes;
  final Future<void> Function(EntityDocument) onSave;

  const _DocFormSheet({
    required this.existing,
    required this.entityId,
    required this.entityType,
    required this.entityName,
    required this.availableDocTypes,
    required this.onSave,
  });

  @override
  ConsumerState<_DocFormSheet> createState() => _DocFormSheetState();
}

class _DocFormSheetState extends ConsumerState<_DocFormSheet> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late DocType _docType;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  PlatformFile? _pickedFile;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _docType = e?.docType ?? widget.availableDocTypes.first;
    _titleCtrl.text = e?.title ?? '';
    _notesCtrl.text = e?.notes ?? '';
    _issueDate = e?.issueDate;
    _expiryDate = e?.expiryDate;
    if (_titleCtrl.text.isEmpty) _titleCtrl.text = _docType.label;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _pickDate(bool isExpiry) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isExpiry ? (_expiryDate ?? now.add(const Duration(days: 365))) : (_issueDate ?? now),
      firstDate: isExpiry ? now.subtract(const Duration(days: 365 * 5)) : DateTime(2000),
      lastDate: isExpiry ? now.add(const Duration(days: 365 * 10)) : now,
    );
    if (picked != null) {
      setState(() {
        if (isExpiry) _expiryDate = picked;
        else _issueDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final farmId = ref.read(activeFarmIdProvider) ?? ref.read(currentUserIdProvider) ?? '';

    try {
      String? fileUrl = widget.existing?.fileUrl;
      String? fileName = widget.existing?.fileName;

      if (_pickedFile != null && _pickedFile!.path != null) {
        final docId = widget.existing?.id ?? _generateId();
        final result = await ref.read(storageServiceProvider).uploadDocument(
          farmId: farmId,
          docId: docId,
          file: File(_pickedFile!.path!),
          fileName: _pickedFile!.name,
        );
        fileUrl = result.url;
        fileName = result.name;

        final doc = widget.existing != null
            ? widget.existing!.copyWith(
                title: _titleCtrl.text.trim(),
                docType: _docType,
                issueDate: _issueDate,
                expiryDate: _expiryDate,
                clearIssueDate: _issueDate == null,
                clearExpiryDate: _expiryDate == null,
                notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                fileUrl: fileUrl,
                fileName: fileName,
              )
            : createDocument(
                farmId: farmId,
                entityId: widget.entityId,
                entityType: widget.entityType,
                entityName: widget.entityName,
                title: _titleCtrl.text.trim(),
                docType: _docType,
                issueDate: _issueDate,
                expiryDate: _expiryDate,
                notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                fileUrl: fileUrl,
                fileName: fileName,
                existingId: widget.existing == null ? docId : null,
              );
        await widget.onSave(doc);
      } else {
        final doc = widget.existing != null
            ? widget.existing!.copyWith(
                title: _titleCtrl.text.trim(),
                docType: _docType,
                issueDate: _issueDate,
                expiryDate: _expiryDate,
                clearIssueDate: _issueDate == null,
                clearExpiryDate: _expiryDate == null,
                notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              )
            : createDocument(
                farmId: farmId,
                entityId: widget.entityId,
                entityType: widget.entityType,
                entityName: widget.entityName,
                title: _titleCtrl.text.trim(),
                docType: _docType,
                issueDate: _issueDate,
                expiryDate: _expiryDate,
                notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              );
        await widget.onSave(doc);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = DateTime.now().millisecondsSinceEpoch;
    return List.generate(20, (i) => chars[(rand >> i) % chars.length]).join();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final hasExistingFile = existing?.fileName != null;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(existing == null ? 'Belge Ekle' : 'Belgeyi Düzenle',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Doc type chips
          const Text('Belge Türü', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: widget.availableDocTypes.map((t) {
              final sel = _docType == t;
              return GestureDetector(
                onTap: () => setState(() {
                  _docType = t;
                  if (widget.availableDocTypes.map((x) => x.label).contains(_titleCtrl.text)) {
                    _titleCtrl.text = t.label;
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primarySurface : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(t.label,
                      style: TextStyle(fontSize: 12,
                          color: sel ? AppColors.primary : AppColors.textSecondary,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Title
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Belge Başlığı', prefixIcon: Icon(Icons.title_rounded)),
          ),
          const SizedBox(height: 12),

          // Dates
          Row(children: [
            Expanded(child: _DateField(
              label: 'Düzenleme Tarihi',
              date: _issueDate,
              onTap: () => _pickDate(false),
              onClear: () => setState(() => _issueDate = null),
            )),
            const SizedBox(width: 12),
            Expanded(child: _DateField(
              label: 'Bitiş Tarihi',
              date: _expiryDate,
              onTap: () => _pickDate(true),
              onClear: () => setState(() => _expiryDate = null),
              isExpiry: true,
            )),
          ]),
          const SizedBox(height: 12),

          // PDF / file picker
          GestureDetector(
            onTap: _pickedFile == null ? _pickFile : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Icon(
                  _pickedFile != null
                      ? (_pickedFile!.name.toLowerCase().endsWith('.pdf')
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded)
                      : Icons.attach_file_rounded,
                  size: 20,
                  color: _pickedFile != null ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _pickedFile != null
                        ? _pickedFile!.name
                        : hasExistingFile
                            ? existing!.fileName!
                            : 'PDF veya fotoğraf ekle (opsiyonel)',
                    style: TextStyle(
                      fontSize: 13,
                      color: _pickedFile != null || hasExistingFile
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_pickedFile != null)
                  GestureDetector(
                    onTap: () => setState(() => _pickedFile = null),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                  )
                else
                  TextButton(
                    onPressed: _pickFile,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 28)),
                    child: Text(hasExistingFile ? 'Değiştir' : 'Seç',
                        style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Notes
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notlar (opsiyonel)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(existing == null ? 'Kaydet' : 'Güncelle'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool isExpiry;
  const _DateField({required this.label, this.date, required this.onTap, required this.onClear, this.isExpiry = false});

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    final expired = isExpiry && hasDate && date!.isBefore(DateTime.now());
    final soonExpiry = isExpiry && hasDate && !expired && date!.difference(DateTime.now()).inDays <= 10;
    final color = expired ? AppColors.error : soonExpiry ? AppColors.warning : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasDate && (expired || soonExpiry) ? color.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Row(children: [
          Icon(Icons.event_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hasDate ? AppDateUtils.formatDate(date) : label,
              style: TextStyle(fontSize: 12,
                  color: hasDate ? (expired || soonExpiry ? color : AppColors.textPrimary) : AppColors.textTertiary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasDate)
            GestureDetector(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 14, color: AppColors.textTertiary),
            ),
        ]),
      ),
    );
  }
}

class _ImageViewerPage extends StatelessWidget {
  final String url;
  final String title;
  const _ImageViewerPage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const CircularProgressIndicator(color: Colors.white),
            errorBuilder: (_, __, ___) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                SizedBox(height: 8),
                Text('Görsel yüklenemedi', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
