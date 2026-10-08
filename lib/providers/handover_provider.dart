import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/handover.dart';
import '../models/handover_status.dart';
import '../models/handover_event.dart';
import '../services/mock_data.dart';

enum HandoverTab { sentByMe, receivedByMe }

class HandoverProvider extends ChangeNotifier {
  final List<Handover> _handovers = [];
  final List<Handover> _receivedHandovers = [];
  HandoverTab _currentTab = HandoverTab.sentByMe;
  String _currentFilter = 'All'; // 'All', 'Active', 'Completed', 'Issues'
  String _searchQuery = '';
  final _uuid = const Uuid();

  HandoverProvider() {
    _handovers.addAll(MockData.getInitialHandovers());
    _receivedHandovers.addAll(MockData.getReceivedByMeHandovers());
  }

  List<Handover> get allHandovers => List.unmodifiable(_handovers);
  List<Handover> get receivedHandovers => List.unmodifiable(_receivedHandovers);
  HandoverTab get currentTab => _currentTab;
  String get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;

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

  // Create Handover
  Handover createHandover({
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
  }) {
    final nextNumber = 1048 + _handovers.length;
    final token = 'HN-$nextNumber';
    final id = 'hn_${_uuid.v4().substring(0, 8)}';

    final newHandover = Handover(
      id: id,
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
      events: [
        HandoverEvent(
          id: 'ev_${_uuid.v4().substring(0, 6)}',
          title: 'Record created by $senderName',
          timestamp: DateTime.now(),
          type: HandoverEventType.created,
          performedBy: senderName,
        ),
      ],
    );

    _handovers.insert(0, newHandover);
    notifyListeners();
    return newHandover;
  }

  // Receiver scans and confirms receipt
  void confirmReceipt(String handoverId, {String? receiverName}) {
    final index = _handovers.indexWhere((h) => h.id == handoverId);
    if (index != -1) {
      final h = _handovers[index];
      final rName = receiverName ?? h.receiverName;
      final updatedEvents = List<HandoverEvent>.from(h.events)
        ..add(HandoverEvent(
          id: 'ev_${_uuid.v4().substring(0, 6)}',
          title: '$rName confirmed physical receipt',
          timestamp: DateTime.now(),
          type: HandoverEventType.received,
          performedBy: rName,
        ));

      _handovers[index] = h.copyWith(
        status: HandoverStatus.received,
        receivedAt: DateTime.now(),
        events: updatedEvents,
      );
      notifyListeners();
    }
  }

  // Sender confirms item returned
  void confirmReturn(String handoverId, {String? senderName}) {
    final index = _handovers.indexWhere((h) => h.id == handoverId);
    if (index != -1) {
      final h = _handovers[index];
      final sName = senderName ?? h.senderName;
      final updatedEvents = List<HandoverEvent>.from(h.events)
        ..add(HandoverEvent(
          id: 'ev_${_uuid.v4().substring(0, 6)}',
          title: '$sName confirmed physical return',
          timestamp: DateTime.now(),
          type: HandoverEventType.returned,
          performedBy: sName,
        ));

      _handovers[index] = h.copyWith(
        status: HandoverStatus.returned,
        returnedAt: DateTime.now(),
        events: updatedEvents,
      );
      notifyListeners();
    }
  }

  // Record an issue / condition discrepancy
  void recordIssue(String handoverId, {required String reason, required String description, String? reportedBy}) {
    final index = _handovers.indexWhere((h) => h.id == handoverId);
    if (index != -1) {
      final h = _handovers[index];
      final rName = reportedBy ?? h.senderName;
      final updatedEvents = List<HandoverEvent>.from(h.events)
        ..add(HandoverEvent(
          id: 'ev_${_uuid.v4().substring(0, 6)}',
          title: '$rName recorded a condition issue',
          timestamp: DateTime.now(),
          type: HandoverEventType.issueRecorded,
          performedBy: rName,
          description: description,
        ));

      _handovers[index] = h.copyWith(
        status: HandoverStatus.disputed,
        issueReason: reason,
        issueDescription: description,
        events: updatedEvents,
      );
      notifyListeners();
    }
  }

  // Resolve issue
  void resolveIssue(String handoverId) {
    final index = _handovers.indexWhere((h) => h.id == handoverId);
    if (index != -1) {
      final h = _handovers[index];
      final updatedEvents = List<HandoverEvent>.from(h.events)
        ..add(HandoverEvent(
          id: 'ev_${_uuid.v4().substring(0, 6)}',
          title: 'Condition issue resolved',
          timestamp: DateTime.now(),
          type: HandoverEventType.issueResolved,
          performedBy: h.senderName,
        ));

      _handovers[index] = h.copyWith(
        status: HandoverStatus.received,
        events: updatedEvents,
      );
      notifyListeners();
    }
  }

  // Renew expired confirmation code
  void renewExpiredCode(String handoverId) {
    final index = _handovers.indexWhere((h) => h.id == handoverId);
    if (index != -1) {
      final h = _handovers[index];
      final nextNumber = 1055 + index;
      final updatedEvents = List<HandoverEvent>.from(h.events)
        ..add(HandoverEvent(
          id: 'ev_${_uuid.v4().substring(0, 6)}',
          title: 'New confirmation code generated',
          timestamp: DateTime.now(),
          type: HandoverEventType.created,
        ));

      _handovers[index] = h.copyWith(
        token: 'HN-$nextNumber',
        status: HandoverStatus.pending,
        events: updatedEvents,
      );
      notifyListeners();
    }
  }
}
