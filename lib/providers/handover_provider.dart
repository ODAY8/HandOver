// lib/providers/handover_provider.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/handover.dart';
import '../models/handover_status.dart';
import '../repositories/handover_repository.dart';
import '../services/mock_data.dart';

enum HandoverTab { sentByMe, receivedByMe }

class HandoverProvider extends ChangeNotifier {
  final HandoverRepository _repository;
  final List<Handover> _handovers = [];
  final List<Handover> _receivedHandovers = [];

  HandoverTab _currentTab = HandoverTab.sentByMe;
  String _currentFilter = 'All'; // 'All', 'Active', 'Completed', 'Issues'
  String _searchQuery = '';

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  final _uuid = const Uuid();

  HandoverProvider({HandoverRepository? handoverRepository})
      : _repository = handoverRepository ?? _createDefaultRepository() {
    if (handoverRepository == null) {
      _handovers.addAll(MockData.getInitialHandovers());
      _receivedHandovers.addAll(MockData.getReceivedByMeHandovers());
    }
  }

  static HandoverRepository _createDefaultRepository() {
    try {
      return SupabaseHandoverRepository();
    } catch (_) {
      return MockHandoverRepository();
    }
  }

  List<Handover> get allHandovers => List.unmodifiable(_handovers);
  List<Handover> get receivedHandovers => List.unmodifiable(_receivedHandovers);
  HandoverTab get currentTab => _currentTab;
  String get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    if (_errorMessage != null || _successMessage != null) {
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();
    }
  }

  void reset() {
    _handovers.clear();
    _receivedHandovers.clear();
    _currentTab = HandoverTab.sentByMe;
    _currentFilter = 'All';
    _searchQuery = '';
    _isLoading = false;
    _isSubmitting = false;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setTab(HandoverTab tab) {
    if (_currentTab != tab) {
      _currentTab = tab;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // Quick stats for Home screen
  int get activeCount => _handovers.where((h) => h.status == HandoverStatus.received).length;
  int get awaitingReceiptCount => _handovers.where((h) => h.status == HandoverStatus.pending).length;
  int get overdueCount => _handovers.where((h) => h.status == HandoverStatus.overdue).length;

  List<Handover> get activeHandovers => _handovers
      .where((h) => h.status == HandoverStatus.received || h.status == HandoverStatus.overdue)
      .toList();

  List<Handover> get filteredHandovers {
    final list = _currentTab == HandoverTab.sentByMe ? _handovers : _receivedHandovers;
    return list.where((item) {
      // Filter by chip
      final matchesFilter = switch (_currentFilter) {
        'Active' => item.status == HandoverStatus.received || item.status == HandoverStatus.pending,
        'Completed' => item.status == HandoverStatus.returned,
        'Issues' => item.status == HandoverStatus.disputed || item.status == HandoverStatus.overdue,
        _ => true,
      };

      if (!matchesFilter) return false;

      // Filter by search
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = item.itemName.toLowerCase().contains(query);
        final matchReceiver = item.receiverName.toLowerCase().contains(query);
        final matchToken = item.token.toLowerCase().contains(query);
        return matchName || matchReceiver || matchToken;
      }

      return true;
    }).toList();
  }

  Handover? getHandoverById(String id) {
    try {
      return _handovers.firstWhere(
        (h) => h.id == id,
        orElse: () => _receivedHandovers.firstWhere((h) => h.id == id),
      );
    } catch (_) {
      return null;
    }
  }

  Handover? getHandoverByToken(String token) {
    try {
      return _handovers.firstWhere(
        (h) => h.token.toLowerCase() == token.toLowerCase(),
        orElse: () => _receivedHandovers.firstWhere((h) => h.token.toLowerCase() == token.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  /// Load handovers for the current user from Supabase
  Future<void> loadHandovers({
    required String userId,
    required String userEmail,
  }) async {
    if (userId.isEmpty) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await _repository.fetchHandovers(
        currentUserId: userId,
        currentUserEmail: userEmail,
      );

      _handovers.clear();
      _receivedHandovers.clear();

      final normEmail = userEmail.toLowerCase().trim();

      for (final item in items) {
        final isOwner = item.ownerId != null && item.ownerId == userId;
        final isRecipient = item.receiverEmail.toLowerCase().trim() == normEmail;

        if (isOwner) {
          _handovers.add(item);
        } else if (isRecipient) {
          _receivedHandovers.add(item);
        } else {
          // If neither owner_id nor email matches directly (e.g. mock data), fallback by tab
          _handovers.add(item);
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch single handover by ID from repository
  Future<Handover?> fetchHandoverById(
    String id, {
    required String userId,
    required String userEmail,
  }) async {
    try {
      final item = await _repository.fetchHandoverById(
        id,
        currentUserId: userId,
        currentUserEmail: userEmail,
      );
      if (item != null) {
        _updateLocalHandover(item);
      }
      return item;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Create Handover record
  Future<Handover> createHandover({
    String? ownerId,
    required String itemName,
    required String category,
    required String identifier,
    required String description,
    String? photoAsset,
    required String senderName,
    required String senderOrg,
    required String receiverName,
    required String receiverOrg,
    required String receiverEmail,
    String? receiverPhone,
    required bool returnExpected,
    DateTime? returnDueAt,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextNumber = 1048 + _handovers.length;
      final token = 'HN-$nextNumber';
      final fallbackId = 'hn_${_uuid.v4().substring(0, 8)}';
      final effectiveOwnerId = ownerId ?? fallbackId;

      final newHandover = Handover(
        id: fallbackId,
        ownerId: effectiveOwnerId,
        token: token,
        itemName: itemName,
        category: category,
        identifier: identifier,
        description: description,
        photoAsset: photoAsset ?? 'assets/images/item_laptop.png',
        senderName: senderName,
        senderOrg: senderOrg,
        receiverName: receiverName,
        receiverOrg: receiverOrg,
        receiverEmail: receiverEmail,
        receiverPhone: receiverPhone,
        returnExpected: returnExpected,
        returnDueAt: returnDueAt,
        status: HandoverStatus.pending,
        notes: notes,
      );

      final created = await _repository.createHandover(
        handover: newHandover,
        ownerId: effectiveOwnerId,
        performerName: senderName,
      );

      _handovers.insert(0, created);
      _successMessage = 'Handover record created.';
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Receiver scans and confirms receipt
  Future<bool> confirmReceipt(
    String handoverId, {
    String? receiverId,
    String? receiverName,
  }) async {
    final existing = getHandoverById(handoverId);
    if (existing == null) {
      _errorMessage = 'Handover not found.';
      notifyListeners();
      return false;
    }

    final pId = receiverId ?? existing.ownerId ?? '';
    final pName = receiverName ?? existing.receiverName;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.updateStatus(
        handoverId: handoverId,
        currentStatus: existing.status,
        newStatus: HandoverStatus.received,
        performerId: pId,
        performerName: pName,
        eventTime: DateTime.now(),
      );

      _updateLocalHandover(updated);
      _successMessage = 'Physical receipt confirmed.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Sender confirms item returned
  Future<bool> confirmReturn(
    String handoverId, {
    String? senderId,
    String? senderName,
  }) async {
    final existing = getHandoverById(handoverId);
    if (existing == null) {
      _errorMessage = 'Handover not found.';
      notifyListeners();
      return false;
    }

    final pId = senderId ?? existing.ownerId ?? '';
    final pName = senderName ?? existing.senderName;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.updateStatus(
        handoverId: handoverId,
        currentStatus: existing.status,
        newStatus: HandoverStatus.returned,
        performerId: pId,
        performerName: pName,
        eventTime: DateTime.now(),
      );

      _updateLocalHandover(updated);
      _successMessage = 'Physical return confirmed.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Record an issue / condition discrepancy
  Future<bool> recordIssue(
    String handoverId, {
    required String reason,
    required String description,
    String? reportedBy,
    String? reporterId,
  }) async {
    final existing = getHandoverById(handoverId);
    if (existing == null) {
      _errorMessage = 'Handover not found.';
      notifyListeners();
      return false;
    }

    final pId = reporterId ?? existing.ownerId ?? '';
    final pName = reportedBy ?? existing.senderName;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.updateStatus(
        handoverId: handoverId,
        currentStatus: existing.status,
        newStatus: HandoverStatus.disputed,
        performerId: pId,
        performerName: pName,
        reason: reason,
        description: description,
      );

      _updateLocalHandover(updated);
      _successMessage = 'Issue recorded successfully.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Resolve issue
  Future<bool> resolveIssue(
    String handoverId, {
    String? resolverId,
    String? resolverName,
  }) async {
    final existing = getHandoverById(handoverId);
    if (existing == null) {
      _errorMessage = 'Handover not found.';
      notifyListeners();
      return false;
    }

    final pId = resolverId ?? existing.ownerId ?? '';
    final pName = resolverName ?? existing.senderName;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.updateStatus(
        handoverId: handoverId,
        currentStatus: existing.status,
        newStatus: HandoverStatus.received,
        performerId: pId,
        performerName: pName,
      );

      _updateLocalHandover(updated);
      _successMessage = 'Condition issue resolved.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Renew expired confirmation code
  Future<bool> renewExpiredCode(
    String handoverId, {
    String? userId,
    String? userName,
  }) async {
    final existing = getHandoverById(handoverId);
    if (existing == null) {
      _errorMessage = 'Handover not found.';
      notifyListeners();
      return false;
    }

    final pId = userId ?? existing.ownerId ?? '';
    final pName = userName ?? existing.senderName;
    final nextNumber = 1055 + _handovers.length;
    final newToken = 'HN-$nextNumber';

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.renewToken(
        handoverId: handoverId,
        newToken: newToken,
        performerId: pId,
        performerName: pName,
      );

      _updateLocalHandover(updated);
      _successMessage = 'New confirmation code generated.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Cancel handover before receipt
  Future<bool> cancelHandover(
    String handoverId, {
    String? userId,
    String? userName,
    String? reason,
  }) async {
    final existing = getHandoverById(handoverId);
    if (existing == null) {
      _errorMessage = 'Handover not found.';
      notifyListeners();
      return false;
    }

    final pId = userId ?? existing.ownerId ?? '';
    final pName = userName ?? existing.senderName;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _repository.cancelHandover(
        handoverId: handoverId,
        currentStatus: existing.status,
        performerId: pId,
        performerName: pName,
        reason: reason,
      );

      _updateLocalHandover(updated);
      _successMessage = 'Handover cancelled.';
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _updateLocalHandover(Handover item) {
    final sIdx = _handovers.indexWhere((h) => h.id == item.id);
    if (sIdx != -1) {
      _handovers[sIdx] = item;
    }

    final rIdx = _receivedHandovers.indexWhere((h) => h.id == item.id);
    if (rIdx != -1) {
      _receivedHandovers[rIdx] = item;
    }

    notifyListeners();
  }
}
