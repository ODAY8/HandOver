// lib/services/handover_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exception thrown when handover operations fail
class HandoverFailure implements Exception {
  final String message;
  final String? code;

  const HandoverFailure(this.message, {this.code});

  @override
  String toString() => message;
}

abstract class HandoverService {
  Future<List<Map<String, dynamic>>> getHandovers();

  Future<Map<String, dynamic>?> getHandoverById(String id);

  Future<Map<String, dynamic>?> getHandoverByToken(String token);

  Future<Map<String, dynamic>> createHandover({
    required Map<String, dynamic> handoverData,
    required Map<String, dynamic> initialEventData,
  });

  Future<Map<String, dynamic>> updateHandoverStatus({
    required String handoverId,
    required String status,
    required Map<String, dynamic> eventData,
    String? currentStatus,
    Map<String, dynamic>? extraFields,
  });

  Future<Map<String, dynamic>> addHandoverEvent({
    required Map<String, dynamic> eventData,
  });

  Future<Map<String, dynamic>> updateHandover({
    required String handoverId,
    required Map<String, dynamic> updates,
  });

  Future<Map<String, dynamic>> renewHandoverToken({
    required String handoverId,
    required String newToken,
  });
}

class SupabaseHandoverService implements HandoverService {
  final SupabaseClient? _customClient;

  SupabaseHandoverService({SupabaseClient? client}) : _customClient = client;

  SupabaseClient get _client {
    if (_customClient != null) return _customClient;
    try {
      return Supabase.instance.client;
    } catch (e) {
      throw const HandoverFailure('Supabase is not initialized.');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getHandovers() async {
    try {
      final response = await _client
          .from('handovers')
          .select('*, handover_events(*)')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is HandoverFailure) rethrow;
      debugPrint('Unexpected error fetching handovers: $e');
      throw const HandoverFailure(
        'Unable to load handovers. Please check your network connection.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> getHandoverById(String id) async {
    try {
      final response = await _client
          .from('handovers')
          .select('*, handover_events(*)')
          .eq('id', id)
          .maybeSingle();

      return response;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is HandoverFailure) rethrow;
      debugPrint('Unexpected error fetching handover $id: $e');
      throw const HandoverFailure(
        'Unable to load handover details. Please try again.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createHandover({
    required Map<String, dynamic> handoverData,
    required Map<String, dynamic> initialEventData,
  }) async {
    try {
      // Security: derive owner_id and performed_by from authenticated session
      final authUid = _client.auth.currentUser?.id;
      if (authUid != null) {
        handoverData['owner_id'] = authUid;
        initialEventData['performed_by'] = authUid;
      }

      // 1. Insert handover row
      final handoverRes = await _client
          .from('handovers')
          .insert(handoverData)
          .select()
          .single();

      final handoverId = handoverRes['id'].toString();

      // 2. Insert initial CREATED audit event
      final eventPayload = Map<String, dynamic>.from(initialEventData);
      eventPayload['handover_id'] = handoverId;

      final eventRes = await _client
          .from('handover_events')
          .insert(eventPayload)
          .select()
          .single();

      handoverRes['handover_events'] = [eventRes];
      return handoverRes;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is HandoverFailure) rethrow;
      debugPrint('Unexpected error creating handover: $e');
      throw const HandoverFailure(
        'Unable to create handover record. Please try again.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> getHandoverByToken(String token) async {
    try {
      final cleanToken = token.trim();
      // 1. Try querying dedicated 'token' column directly
      try {
        final response = await _client
            .from('handovers')
            .select('*, handover_events(*)')
            .eq('token', cleanToken)
            .maybeSingle();

        if (response != null) return response;
      } catch (_) {
        // Fall back if token column is not yet present on server
      }

      // 2. Query authorized handovers and check purpose metadata
      final all = await getHandovers();
      for (final row in all) {
        if (row['token']?.toString().toUpperCase() ==
            cleanToken.toUpperCase()) {
          return row;
        }
        if (row['purpose'] != null) {
          try {
            final decoded = jsonDecode(row['purpose'].toString());
            if (decoded is Map &&
                decoded['token']?.toString().toUpperCase() ==
                    cleanToken.toUpperCase()) {
              return row;
            }
          } catch (_) {}
        }
      }

      return null;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is HandoverFailure) rethrow;
      debugPrint('Unexpected error fetching handover by token: $e');
      throw const HandoverFailure('Unable to load handover details.');
    }
  }

  @override
  Future<Map<String, dynamic>> updateHandoverStatus({
    required String handoverId,
    required String status,
    required Map<String, dynamic> eventData,
    String? currentStatus,
    Map<String, dynamic>? extraFields,
  }) async {
    try {
      final meta = eventData['metadata'] is Map<String, dynamic>
          ? eventData['metadata'] as Map<String, dynamic>
          : <String, dynamic>{};
      final reason = meta['reason']?.toString();
      final description = meta['description']?.toString();
      final note = meta['note']?.toString();

      // Map custody status transition to exact PostgreSQL atomic RPC
      String? rpcName;
      final Map<String, dynamic> rpcParams = {'p_handover_id': handoverId};

      if (status == 'RECEIVED' && currentStatus == 'DISPUTED') {
        rpcName = 'resolve_handover_issue';
        if (note != null && note.isNotEmpty) {
          rpcParams['p_notes'] = note;
        }
      } else if (status == 'RECEIVED') {
        rpcName = 'confirm_handover_receipt';
      } else if (status == 'RETURNED') {
        rpcName = 'confirm_handover_return';
      } else if (status == 'CANCELLED') {
        rpcName = 'cancel_handover';
        if (reason != null && reason.isNotEmpty) {
          rpcParams['p_reason'] = reason;
        }
      } else if (status == 'DISPUTED') {
        rpcName = 'record_handover_issue';
        rpcParams['p_reason'] = reason ?? 'Issue reported';
        rpcParams['p_description'] = description ?? '';
      }

      if (rpcName == null) {
        throw const HandoverFailure(
          'Direct status updates are prohibited. Custody transitions must use secure backend procedures.',
          code: '42501',
        );
      }

      // Execute atomic custody transition RPC. Fail-closed: NEVER fall back to direct writes.
      try {
        await _client.rpc(rpcName, params: rpcParams);
      } on PostgrestException catch (e) {
        final isMissingRpc =
            e.code == 'PGRST202' ||
            e.message.toLowerCase().contains('could not find the function') ||
            e.message.toLowerCase().contains('does not exist');
        if (isMissingRpc) {
          throw HandoverFailure(
            'Backend migration required: The atomic transition procedure "$rpcName" is not installed on this server.',
            code: e.code,
          );
        }
        throw _mapPostgrestException(e);
      }

      // Custody state changed atomically via RPC. Re-fetch refreshed record.
      final refreshed = await getHandoverById(handoverId);
      if (refreshed != null) return refreshed;

      throw const HandoverFailure('Failed to load updated handover.');
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is HandoverFailure) rethrow;
      debugPrint('Unexpected error updating handover status: $e');
      throw const HandoverFailure(
        'Unable to update handover status. Please try again.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> addHandoverEvent({
    required Map<String, dynamic> eventData,
  }) async {
    try {
      final authUid = _client.auth.currentUser?.id;
      if (authUid != null) {
        eventData['performed_by'] = authUid;
      }

      final res = await _client
          .from('handover_events')
          .insert(eventData)
          .select()
          .single();

      return res;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is HandoverFailure) rethrow;
      debugPrint('Unexpected error adding handover event: $e');
      throw const HandoverFailure(
        'Unable to record handover event. Please try again.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateHandover({
    required String handoverId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await _client
          .from('handovers')
          .update(updates)
          .eq('id', handoverId)
          .select('*, handover_events(*)')
          .single();

      return response;
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is HandoverFailure) rethrow;
      debugPrint('Unexpected error updating handover: $e');
      throw const HandoverFailure(
        'Unable to save handover updates. Please try again.',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> renewHandoverToken({
    required String handoverId,
    required String newToken,
  }) async {
    try {
      final response = await _client.rpc(
        'renew_handover_token',
        params: {'p_handover_id': handoverId, 'p_new_token': newToken},
      );

      if (response is Map<String, dynamic>) {
        return response;
      } else if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      final refreshed = await getHandoverById(handoverId);
      if (refreshed != null) return refreshed;

      throw const HandoverFailure('Failed to load renewed handover.');
    } on PostgrestException catch (e) {
      throw _mapPostgrestException(e);
    } catch (e) {
      if (e is HandoverFailure) rethrow;
      debugPrint('Unexpected error renewing handover token: $e');
      throw const HandoverFailure(
        'Unable to renew confirmation code. Please try again.',
      );
    }
  }

  HandoverFailure _mapPostgrestException(PostgrestException e) {
    final msg = e.message.toLowerCase();
    final code = e.code;

    if (code == '42501' ||
        msg.contains('row-level security') ||
        msg.contains('permission denied')) {
      return HandoverFailure(
        'Access denied. You do not have permission to modify or access this handover record.',
        code: code,
      );
    }

    if (code == '23514' || msg.contains('check constraint')) {
      return HandoverFailure(
        'Invalid status transition or invalid values provided.',
        code: code,
      );
    }

    if (code == '23503' || msg.contains('foreign key')) {
      return HandoverFailure(
        'Referenced user profile or handover record does not exist.',
        code: code,
      );
    }

    if (msg.contains('network') ||
        msg.contains('timeout') ||
        msg.contains('connection')) {
      return HandoverFailure(
        'Network error. Please check your internet connection.',
        code: code,
      );
    }

    return HandoverFailure(e.message, code: code);
  }

  @visibleForTesting
  HandoverFailure mapPostgrestException(PostgrestException e) =>
      _mapPostgrestException(e);
}
