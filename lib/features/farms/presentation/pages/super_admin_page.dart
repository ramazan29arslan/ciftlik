import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/farm_models.dart';
import '../providers/farm_provider.dart';
import '../../../../shared/widgets/app_card.dart';

class SuperAdminPage extends ConsumerWidget {
  const SuperAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Süper Admin — Çok Çiftlik İstekleri'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
        data: (requests) => requests.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success),
                    SizedBox(height: 12),
                    Text('Bekleyen istek yok',
                        style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) => _RequestCard(
                  request: requests[i],
                  onApprove: () async {
                    await ref.read(farmServiceProvider).approveMultiFarmRequest(requests[i].id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${requests[i].userName} onaylandı'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  onReject: () async {
                    await ref.read(farmServiceProvider).rejectMultiFarmRequest(requests[i].id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('İstek reddedildi')),
                      );
                    }
                  },
                ),
              ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final MultiFarmRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primarySurface,
              child: Text(
                (request.userName.isNotEmpty ? request.userName[0] : '?').toUpperCase(),
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(request.userName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(request.userEmail,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            Text(_timeAgo(request.requestedAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.agriculture_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(request.farmName.isNotEmpty ? request.farmName : request.farmId,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('Rol: ${request.role.label}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Reddet'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onApprove,
                child: const Text('Onayla'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk önce';
    if (diff.inHours < 24) return '${diff.inHours}sa önce';
    return '${diff.inDays}g önce';
  }
}
