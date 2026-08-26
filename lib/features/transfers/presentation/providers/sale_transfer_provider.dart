import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/sale_transfer_service.dart';
import '../../domain/entities/sale_transfer.dart';

final saleTransferServiceProvider = Provider<SaleTransferService>((_) => SaleTransferService());

final outgoingTransfersProvider = StreamProvider<List<SaleTransfer>>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (userId.isEmpty) return const Stream.empty();
  return ref.watch(saleTransferServiceProvider).outgoingTransfers(userId);
});

final incomingTransfersProvider = StreamProvider<List<SaleTransfer>>((ref) {
  final email = FirebaseAuth.instance.currentUser?.email ?? '';
  if (email.isEmpty) return const Stream.empty();
  return ref.watch(saleTransferServiceProvider).incomingTransfers(email);
});

final pendingIncomingCountProvider = Provider<int>((ref) {
  final incoming = ref.watch(incomingTransfersProvider).value ?? [];
  return incoming.where((t) => t.status == SaleTransferStatus.pending).length;
});
