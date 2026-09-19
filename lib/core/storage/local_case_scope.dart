import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Account boundary for local legal history. Ownerless legacy entries remain
/// untouched and invisible: their owner cannot safely be inferred.
class LocalCaseScope extends ValueNotifier<String> {
  LocalCaseScope({String? userId, Stream<String?>? userChanges})
      : _userId = userId,
        super(_scopeFor(userId)) {
    _subscription = userChanges?.listen(updateUser);
  }

  String? _userId;
  StreamSubscription<String?>? _subscription;

  static String _scopeFor(String? userId) =>
      userId == null ? 'guest:${const Uuid().v4()}' : 'account:$userId';

  void updateUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    value = _scopeFor(userId);
  }

  String keyFor(String id) => '$value:$id';

  bool ownsKey(Object? key) => key is String && key.startsWith('$value:');

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
