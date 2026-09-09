import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A fake SupabaseClient for testing that supports basic query operations
/// This allows testing service behavior with controlled test data
class FakeSupabaseClient implements SupabaseClient {
  /// Data to return for queries, keyed by table name
  final Map<String, List<Map<String, dynamic>>> _tableData = {};
  
  /// Track inserted data for verification
  final List<Map<String, dynamic>> insertedRecords = [];
  
  /// Track deleted IDs for verification  
  final List<String> deletedIds = [];
  
  /// Set test data for a specific table
  void setTableData(String table, List<Map<String, dynamic>> data) {
    _tableData[table] = data;
  }
  
  /// Clear all test data
  void clearData() {
    _tableData.clear();
    insertedRecords.clear();
    deletedIds.clear();
  }
  
  @override
  SupabaseQueryBuilder from(String table) {
    return FakeSupabaseQueryBuilder(
      tableName: table,
      tableData: _tableData[table] ?? [],
      insertedRecords: insertedRecords,
      deletedIds: deletedIds,
    );
  }

  /// Fake auth with no active session (currentUser == null) by default.
  final FakeGoTrueClient _auth = FakeGoTrueClient();

  @override
  GoTrueClient get auth => _auth;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeSupabaseClient - method ${invocation.memberName} not implemented');
  }
}

/// A fake GoTrueClient exposing a null current session/user for tests.
class FakeGoTrueClient implements GoTrueClient {
  @override
  User? get currentUser => null;

  @override
  Session? get currentSession => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeGoTrueClient - method ${invocation.memberName} not implemented');
  }
}

/// A fake query builder that mimics Supabase's fluent API
class FakeSupabaseQueryBuilder implements SupabaseQueryBuilder {
  final String tableName;
  final List<Map<String, dynamic>> tableData;
  final List<Map<String, dynamic>> insertedRecords;
  final List<String> deletedIds;
  
  FakeSupabaseQueryBuilder({
    required this.tableName,
    required this.tableData,
    required this.insertedRecords,
    required this.deletedIds,
  });
  
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) {
    return FakePostgrestFilterBuilder(
      data: List.from(tableData),
      insertedRecords: insertedRecords,
      deletedIds: deletedIds,
    );
  }
  
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> insert(Object values, {bool defaultToNull = true}) {
    if (values is Map<String, dynamic>) {
      insertedRecords.add(values);
    } else if (values is List) {
      insertedRecords.addAll(values.cast<Map<String, dynamic>>());
    }
    return FakePostgrestFilterBuilder(
      data: [if (values is Map<String, dynamic>) values],
      insertedRecords: insertedRecords,
      deletedIds: deletedIds,
      isInsert: true,
    );
  }
  
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> delete() {
    return FakePostgrestFilterBuilder(
      data: List.from(tableData),
      insertedRecords: insertedRecords,
      deletedIds: deletedIds,
      isDelete: true,
    );
  }
  
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> update(Map values) {
    return FakePostgrestFilterBuilder(
      data: List.from(tableData),
      insertedRecords: insertedRecords,
      deletedIds: deletedIds,
    );
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeSupabaseQueryBuilder - method ${invocation.memberName} not implemented');
  }
}

/// A fake filter builder that supports eq(), single(), and other common operations
// ignore: must_be_immutable
class FakePostgrestFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  List<Map<String, dynamic>> data;
  final List<Map<String, dynamic>> insertedRecords;
  final List<String> deletedIds;
  final bool isInsert;
  final bool isDelete;
  String? filterColumn;
  dynamic filterValue;
  
  FakePostgrestFilterBuilder({
    required this.data,
    required this.insertedRecords,
    required this.deletedIds,
    this.isInsert = false,
    this.isDelete = false,
  });
  
  @override
  PostgrestFilterBuilder<T> eq(String column, Object value) {
    filterColumn = column;
    filterValue = value;
    
    if (isDelete) {
      deletedIds.add(value.toString());
    }
    
    // Filter the data
    data = data.where((row) => row[column] == value).toList();
    
    return this;
  }
  
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> select([String columns = '*']) {
    return FakePostgrestFilterBuilder(
      data: data,
      insertedRecords: insertedRecords,
      deletedIds: deletedIds,
      isInsert: isInsert,
      isDelete: isDelete,
    );
  }
  
  @override
  PostgrestTransformBuilder<Map<String, dynamic>> single() {
    return FakeSingleBuilder(
      data: data.isNotEmpty ? data.first : null,
    );
  }
  
  @override
  PostgrestTransformBuilder<Map<String, dynamic>?> maybeSingle() {
    return FakeMaybeSingleBuilder(
      data: data.isNotEmpty ? data.first : null,
    );
  }
  
  @override
  PostgrestFilterBuilder<T> or(String filters, {dynamic referencedTable}) {
    return this;
  }
  
  @override
  PostgrestTransformBuilder<T> order(String column, {bool ascending = true, bool nullsFirst = false, dynamic referencedTable}) {
    return FakeListTransformBuilder(data: data as T);
  }
  
  @override
  PostgrestTransformBuilder<T> limit(int count, {dynamic referencedTable}) {
    if (data.length > count) {
      data = data.sublist(0, count);
    }
    return FakeListTransformBuilder(data: data as T);
  }
  
  // Make this awaitable - returns the filtered data
  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) {
    if (isDelete) {
      // Delete returns empty list
      return Future.value(<Map<String, dynamic>>[] as T).then(onValue);
    }
    return Future.value(data as T).then(onValue);
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // For filter methods not explicitly implemented, return this for chaining
    return this;
  }
}

/// A fake transform builder for single() results that works with await
class FakeSingleBuilder implements PostgrestTransformBuilder<Map<String, dynamic>> {
  final Map<String, dynamic>? data;
  final Future<Map<String, dynamic>> _future;
  
  FakeSingleBuilder({this.data}) : _future = data != null 
    ? Future.value(data)
    : Future.error(PostgrestException(message: 'Row not found', code: 'PGRST116'));
  
  @override
  Future<R> then<R>(FutureOr<R> Function(Map<String, dynamic>) onValue, {Function? onError}) {
    return _future.then(onValue, onError: onError);
  }
  
  @override
  Stream<Map<String, dynamic>> asStream() => _future.asStream();
  
  @override
  Future<Map<String, dynamic>> catchError(Function onError, {bool Function(Object)? test}) {
    return _future.catchError(onError, test: test);
  }
  
  @override
  Future<Map<String, dynamic>> whenComplete(FutureOr<void> Function() action) {
    return _future.whenComplete(action);
  }
  
  @override
  Future<Map<String, dynamic>> timeout(Duration timeLimit, {FutureOr<Map<String, dynamic>> Function()? onTimeout}) {
    return _future.timeout(timeLimit, onTimeout: onTimeout);
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeSingleBuilder - method ${invocation.memberName} not implemented');
  }
}

/// A fake transform builder for maybeSingle() results
class FakeMaybeSingleBuilder implements PostgrestTransformBuilder<Map<String, dynamic>?> {
  final Map<String, dynamic>? data;
  
  FakeMaybeSingleBuilder({this.data});
  
  @override
  Future<R> then<R>(FutureOr<R> Function(Map<String, dynamic>?) onValue, {Function? onError}) {
    return Future.value(data).then(onValue);
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeMaybeSingleBuilder - method ${invocation.memberName} not implemented');
  }
}

/// A fake transform builder for list results
class FakeListTransformBuilder<T> implements PostgrestTransformBuilder<T> {
  final T data;
  
  FakeListTransformBuilder({required this.data});

  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) {
    return Future.value(data).then(onValue);
  }

  @override
  PostgrestTransformBuilder<T> order(String column, {bool ascending = true, bool nullsFirst = false, dynamic referencedTable}) {
    return this;
  }

  @override
  PostgrestTransformBuilder<T> limit(int count, {dynamic referencedTable}) {
    final list = data;
    if (list is List && list.length > count) {
      return FakeListTransformBuilder(data: list.sublist(0, count < 0 ? 0 : count) as T);
    }
    return this;
  }

  @override
  PostgrestTransformBuilder<T> range(int from, int to, {dynamic referencedTable}) {
    final list = data;
    if (list is List) {
      final start = from < 0 ? 0 : from;
      if (start >= list.length) {
        return FakeListTransformBuilder(data: <Map<String, dynamic>>[] as T);
      }
      final end = (to + 1) > list.length ? list.length : (to + 1);
      return FakeListTransformBuilder(data: list.sublist(start, end < start ? start : end) as T);
    }
    return this;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('FakeListTransformBuilder - method ${invocation.memberName} not implemented');
  }
}
