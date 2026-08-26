import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/feedback_model.dart';
import '../../../../core/services/feedback_service.dart';
import '../../../../core/di/providers.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_button.dart';

final _feedbackServiceProvider = Provider<FeedbackService>((_) => FeedbackService());

extension _FeedbackTypeX on FeedbackType {
  String get label {
    switch (this) {
      case FeedbackType.complaint: return 'Şikayet';
      case FeedbackType.suggestion: return 'Öneri';
      case FeedbackType.question: return 'Soru';
    }
  }
  IconData get icon {
    switch (this) {
      case FeedbackType.complaint: return Icons.report_problem_rounded;
      case FeedbackType.suggestion: return Icons.lightbulb_rounded;
      case FeedbackType.question: return Icons.help_rounded;
    }
  }
  Color get color {
    switch (this) {
      case FeedbackType.complaint: return AppColors.error;
      case FeedbackType.suggestion: return AppColors.primary;
      case FeedbackType.question: return AppColors.info;
    }
  }
}

final _userFeedbackProvider = StreamProvider.family<List<FeedbackModel>, String>((ref, userId) {
  return ref.read(_feedbackServiceProvider).userFeedbackStream(userId);
});

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key});

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Şikayet & Öneriler'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gönder'),
            Tab(text: 'Geçmişim'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SendTab(onSent: () => _tabController.animateTo(1)),
          const _HistoryTab(),
        ],
      ),
    );
  }
}

// ── Gönder Tab ────────────────────────────────────────────
class _SendTab extends ConsumerStatefulWidget {
  final VoidCallback onSent;
  const _SendTab({required this.onSent});

  @override
  ConsumerState<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends ConsumerState<_SendTab> {
  final _msgCtrl = TextEditingController();
  FeedbackType _type = FeedbackType.suggestion;
  bool _loading = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      await ref.read(_feedbackServiceProvider).sendFeedback(
        userId: user.uid,
        userEmail: user.email ?? '',
        userName: user.displayName ?? user.email ?? 'Kullanıcı',
        type: _type,
        message: _msgCtrl.text.trim(),
      );
      _msgCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesajınız iletildi. Teşekkürler!'), backgroundColor: AppColors.success),
        );
        widget.onSent();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Görüş ve önerileriniz uygulamanın geliştirilmesine katkı sağlar.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),

          // Tür seçimi
          const Text('Mesaj Türü', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: FeedbackType.values.map((t) {
              final selected = _type == t;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primarySurface : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 15, color: selected ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        t.label,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? AppColors.primary : AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Mesaj
          TextField(
            controller: _msgCtrl,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Mesajınız',
              alignLabelWithHint: true,
              hintText: _type == FeedbackType.complaint
                  ? 'Karşılaştığınız sorunu açıklayın...'
                  : _type == FeedbackType.question
                      ? 'Sorunuzu yazın...'
                      : 'Önerinizi paylaşın...',
            ),
          ),
          const SizedBox(height: 24),

          AppButton(
            label: 'Gönder',
            icon: Icons.send_rounded,
            onPressed: _send,
            isLoading: _loading,
          ),
        ],
      ),
    );
  }

}

// ── Geçmiş Tab ────────────────────────────────────────────
class _HistoryTab extends ConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const SizedBox();

    final feedbackAsync = ref.watch(_userFeedbackProvider(userId));

    return feedbackAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 56, color: AppColors.textTertiary),
                SizedBox(height: 12),
                Text('Henüz mesaj göndermediniz', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _FeedbackCard(feedback: list[i]),
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackModel feedback;
  const _FeedbackCard({required this.feedback});

  @override
  Widget build(BuildContext context) {
    final hasReply = feedback.status == FeedbackStatus.replied && feedback.adminReply != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: feedback.type.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(feedback.typeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: feedback.type.color)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasReply ? AppColors.successLight : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(feedback.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: hasReply ? AppColors.success : AppColors.warning)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(feedback.message, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.5)),
          const SizedBox(height: 6),
          Text(
            '${feedback.createdAt.day}.${feedback.createdAt.month}.${feedback.createdAt.year}',
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),

          // Admin yanıtı
          if (hasReply) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primaryPale),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.support_agent_rounded, size: 14, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Destek Yanıtı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(feedback.adminReply!, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
                  if (feedback.repliedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${feedback.repliedAt!.day}.${feedback.repliedAt!.month}.${feedback.repliedAt!.year}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

}
