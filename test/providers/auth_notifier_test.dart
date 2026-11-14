import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../test_helpers/fake_supabase_client.dart';

/// AuthNotifier: session start-up, auth events, guest sign-in, the guard
/// rails that protect an anonymous learner's id, profile provisioning, and
/// that a failed profile write never signs the learner out.
void main() {
  sb.User user(String id, {bool anonymous = false, String? email}) => sb.User(
        id: id,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        isAnonymous: anonymous,
        email: email,
        createdAt: '2026-11-14T00:00:00Z',
      );

  sb.Session session(sb.User u) => sb.Session(accessToken: 'token', tokenType: 'bearer', user: u);

  late _AuthClient client;

  setUp(() => client = _AuthClient());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('no session at start-up: guest mode, no profile write', () async {
    final notifier = AuthNotifier(client: client);
    await settle();

    expect(notifier.state, isA<GuestMode>());
    expect(client.users.writes, isEmpty);
    notifier.dispose();
  });

  test('existing anonymous session: signed in and a Guest profile is created once', () async {
    client.fakeAuth.signIn(session(user('anon-1', anonymous: true)));

    final notifier = AuthNotifier(client: client);
    await settle();

    expect((notifier.state as AuthSuccess).user.id, 'anon-1');
    expect(notifier.isAnonymousSession, isTrue);
    expect(client.users.writes, [
      {'op': 'insert', 'id': 'anon-1', 'email': null, 'display_name': 'Guest'},
    ]);
    notifier.dispose();
  });

  test('an existing profile only has its email synced, never its display name', () async {
    client.users.rows['g-1'] = {'email': null};
    client.fakeAuth.signIn(session(user('g-1', email: '  learner@example.test ')));

    final notifier = AuthNotifier(client: client);
    await settle();

    expect(client.users.writes, [
      {'op': 'update', 'id': 'g-1', 'email': 'learner@example.test'},
    ]);
    notifier.dispose();
  });

  test('auth events switch between signed in and guest mode', () async {
    final notifier = AuthNotifier(client: client);
    await settle();

    client.fakeAuth.emit(session(user('u-1')));
    await settle();
    expect((notifier.state as AuthSuccess).user.id, 'u-1');

    client.fakeAuth.emit(null);
    await settle();
    expect(notifier.state, isA<GuestMode>());
    notifier.dispose();
  });

  test('guest sign-in is refused when a session already exists', () async {
    client.fakeAuth.signIn(session(user('u-1')));
    final notifier = AuthNotifier(client: client);
    await settle();

    await expectLater(notifier.signInAsGuest(), throwsStateError);
    expect(client.fakeAuth.anonymousSignIns, 0);
    notifier.dispose();
  });

  test('a failed guest sign-in shows a sanitized error and rethrows', () async {
    client.fakeAuth.anonymousError = const sb.AuthException('internal detail: rate limit key xyz');
    final notifier = AuthNotifier(client: client);
    await settle();

    await expectLater(notifier.signInAsGuest(), throwsA(isA<sb.AuthException>()));
    final state = notifier.state as AuthError;
    expect(state.message, 'Unable to start guest session. Please try again.');
    expect(state.message, isNot(contains('xyz')));
    notifier.dispose();
  });

  test('an anonymous learner cannot start a fresh Google sign-in (would lose their id)', () async {
    client.fakeAuth.signIn(session(user('anon-1', anonymous: true)));
    final notifier = AuthNotifier(client: client);
    await settle();

    await expectLater(notifier.signInWithGoogle(), throwsStateError);
    expect(notifier.state, isA<AuthSuccess>(), reason: 'guest session is kept');
    notifier.dispose();
  });

  test('only an anonymous guest may link Google', () async {
    client.fakeAuth.signIn(session(user('u-1')));
    final notifier = AuthNotifier(client: client);
    await settle();

    await expectLater(notifier.linkGuestToGoogle(), throwsStateError);
    notifier.dispose();
  });

  test('a profile write that keeps failing does not sign the learner out', () async {
    client.users.failAll = true;
    client.fakeAuth.signIn(session(user('anon-1', anonymous: true)));

    final notifier = AuthNotifier(client: client);
    // Three attempts with 500 ms and 1000 ms backoff in between.
    await Future<void>.delayed(const Duration(milliseconds: 1700));

    expect(client.users.attempts, 3);
    expect((notifier.state as AuthSuccess).user.id, 'anon-1');
    expect(client.fakeAuth.signOuts, 0);

    // Retry succeeds once the database is reachable again.
    client.users.failAll = false;
    await notifier.retryProfileProvisioning();
    expect(client.users.writes.single['op'], 'insert');
    notifier.dispose();
  });

  test('sign-out clears the session state', () async {
    client.fakeAuth.signIn(session(user('u-1')));
    final notifier = AuthNotifier(client: client);
    await settle();

    await notifier.signOut();

    expect(client.fakeAuth.signOuts, 1);
    expect(notifier.state, isA<AuthInitial>());
    notifier.dispose();
  });
}

class _AuthClient extends FakeSupabaseClient {
  final _FakeAuth fakeAuth = _FakeAuth();
  final _UsersTable users = _UsersTable();

  @override
  _FakeAuth get auth => fakeAuth;

  @override
  sb.SupabaseQueryBuilder from(String table) {
    expect(table, 'users');
    return users;
  }
}

class _FakeAuth extends FakeGoTrueClient {
  _FakeAuth() : super(null);

  final _events = StreamController<sb.AuthState>.broadcast();
  sb.Session? _session;
  int anonymousSignIns = 0;
  int signOuts = 0;
  Object? anonymousError;

  void signIn(sb.Session s) {
    _session = s;
    currentUser = s.user;
  }

  void emit(sb.Session? s) {
    _session = s;
    currentUser = s?.user;
    _events.add(sb.AuthState(
      s == null ? sb.AuthChangeEvent.signedOut : sb.AuthChangeEvent.signedIn,
      s,
    ));
  }

  @override
  sb.Session? get currentSession => _session;

  @override
  Stream<sb.AuthState> get onAuthStateChange => _events.stream;

  @override
  Future<sb.AuthResponse> signInAnonymously({Map<String, dynamic>? data, String? captchaToken}) async {
    anonymousSignIns++;
    if (anonymousError != null) throw anonymousError!;
    return sb.AuthResponse();
  }

  @override
  Future<void> signOut({sb.SignOutScope scope = sb.SignOutScope.local}) async {
    signOuts++;
    emit(null);
  }
}

/// `users` table: select().eq().maybeSingle(), insert(row), update(row).eq().
// Test double with mutable recording state.
// ignore: must_be_immutable
class _UsersTable implements sb.SupabaseQueryBuilder {
  final Map<String, Map<String, dynamic>> rows = {};
  final List<Map<String, dynamic>> writes = [];
  bool failAll = false;
  int attempts = 0;

  @override
  sb.PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) {
    attempts++;
    return _Query(this, failAll ? const sb.PostgrestException(message: 'db down') : null);
  }

  @override
  sb.PostgrestFilterBuilder<List<Map<String, dynamic>>> insert(Object values, {bool defaultToNull = true}) {
    final row = Map<String, dynamic>.from(values as Map);
    writes.add({'op': 'insert', ...row});
    rows[row['id'] as String] = row;
    return _Query(this, null);
  }

  @override
  sb.PostgrestFilterBuilder<List<Map<String, dynamic>>> update(Map values) =>
      _Query(this, null, pendingUpdate: Map<String, dynamic>.from(values));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_UsersTable.${invocation.memberName}');
}

// Test double with mutable recording state.
// ignore: must_be_immutable
class _Query implements sb.PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  _Query(this.table, this.error, {this.pendingUpdate});
  final _UsersTable table;
  final Object? error;
  final Map<String, dynamic>? pendingUpdate;
  String? id;

  @override
  sb.PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(String column, Object value) {
    id = value as String;
    if (pendingUpdate != null) {
      table.writes.add({'op': 'update', 'id': id, ...pendingUpdate!});
    }
    return this;
  }

  @override
  sb.PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() =>
      _Single(error != null ? Future.error(error!) : Future.value(table.rows[id]));

  @override
  Future<R> then<R>(FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {Function? onError}) =>
      (error != null ? Future<List<Map<String, dynamic>>>.error(error!) : Future.value(<Map<String, dynamic>>[]))
          .then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_Query.${invocation.memberName}');
}

class _Single implements sb.PostgrestTransformBuilder<Map<String, dynamic>?> {
  _Single(this._future);
  final Future<Map<String, dynamic>?> _future;

  @override
  Future<R> then<R>(FutureOr<R> Function(Map<String, dynamic>? value) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('_Single.${invocation.memberName}');
}
