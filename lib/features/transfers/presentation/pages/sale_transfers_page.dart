import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/sale_transfer_provider.dart';
import '../../domain/entities/sale_transfer.dart';
import '../../../farms/presentation/providers/farm_provider.dart';

class SaleTransfersPage extends ConsumerWidget {
  const SaleTransfersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingTransfersProvider);
    final outgoing = ref.watch(outgoingTransfersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Transfer Talepleri'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Gelen'),
              Tab(text: 'Gönderilen'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _IncomingTab(incoming: incoming),
            _OutgoingTab(outgoing: outgoing),
          ],
        ),
      ),
    );
  }
}

class _IncomingTab extends ConsumerWidget {
  final AsyncValue<List<SaleTransfer>> incoming;
  const _IncomingTab({required this.incoming});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return incoming.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_rounded, size: 56, color: AppColors.textTertiary),
                SizedBox(height: 12),
                Text('Gelen transfer talebi yok', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (ctx, i) => _TransferCard(
            transfer: list[i],
            isIncoming: true,
          ),
        );
      },
    );
  }
}

class _OutgoingTab extends ConsumerWidget {
  final AsyncValue<List<SaleTransfer>> outgoing;
  const _OutgoingTab({required this.outgoing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return outgoing.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Hata: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.outbox_rounded, size: 56, color: AppColors.textTertiary),
                SizedBox(height: 12),
                Text('Gönderilen transfer talebi yok', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (ctx, i) => _TransferCard(
            transfer: list[i],
            isIncoming: false,
          ),
        );
      },
    );
  }
}

class _TransferCard extends ConsumerWidget {
  final SaleTransfer transfer;
  final bool isIncoming;
  const _TransferCard({required this.transfer, required this.isIncoming});

  Color get _statusColor {
    switch (transfer.status) {
      case SaleTransferStatus.pending: return AppColors.warning;
      case SaleTransferStatus.accepted: return AppColors.success;
      case SaleTransferStatus.rejected: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.pets_rounded, color: AppColors.animalColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transfer.entityName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(transfer.statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isIncoming) ...[
              Row(children: [
                const Icon(Icons.person_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text('Satıcı: ${transfer.sellerDisplayName} (${transfer.sellerEmail})', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              ]),
            ] else ...[
              Row(children: [
                const Icon(Icons.email_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text('Alıcı: ${transfer.buyerEmail}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
              ]),
            ],
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${transfer.createdAt.day}.${transfer.createdAt.month}.${transfer.createdAt.year}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ]),
            if (isIncoming && transfer.status == SaleTransferStatus.pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _reject(context, ref),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                      child: const Text('Reddet'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _accept(context, ref),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Kabul Et', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
            if (!isIncoming && transfer.status == SaleTransferStatus.pending) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancel(context, ref),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('İptal Et'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.textSecondary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final farmId = ref.read(activeFarmIdProvider) ?? user.uid;
    try {
      await ref.read(saleTransferServiceProvider).acceptTransfer(
        transfer: transfer,
        buyerUserId: user.uid,
        buyerFarmId: farmId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${transfer.entityName} envanterinize eklendi!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await ref.read(saleTransferServiceProvider).rejectTransfer(transfer.id, user.uid);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer reddedildi')),
      );
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    await ref.read(saleTransferServiceProvider).cancelTransfer(transfer.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer iptal edildi')),
      );
    }
  }
}
