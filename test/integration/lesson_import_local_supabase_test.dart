// Real lesson import -> database -> readback against a LOCAL Supabase stack
// (plan PR-3; replaces the skipped legacy test_lesson_creation.dart).
//
// Runs the production LessonImportService / LessonCrudService /
// LessonContentService code paths with an injected pure-Dart SupabaseClient,
// so no Flutter platform channels (shared_preferences) are involved.
//
// Configuration (set by the CI "Verify clean Supabase migrations" job from
// `supabase status -o env`):
//   LOCAL_SUPABASE_URL, LOCAL_SUPABASE_ANON_KEY, LOCAL_SUPABASE_SERVICE_ROLE_KEY
//   REQUIRE_LOCAL_SUPABASE=true  -> missing configuration FAILS instead of skipping
//
// Safety: refuses any URL whose host is not loopback, uses synthetic
// @example.test users created and deleted by this test, and never reads the
// project .env file.
//
// Local run:
//   supabase start
//   eval "$(supabase status -o env)"
//   LOCAL_SUPABASE_URL=$API_URL LOCAL_SUPABASE_ANON_KEY=$ANON_KEY \
//   LOCAL_SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY REQUIRE_LOCAL_SUPABASE=true \
//   flutter test test/integration/lesson_import_local_supabase_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/models/question.dart';
import 'package:learning_pwa/services/lesson/lesson_content_service.dart';
import 'package:learning_pwa/services/lesson/lesson_crud_service.dart';
import 'package:learning_pwa/services/lesson/lesson_import_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _loopbackHosts = {'127.0.0.1', 'localhost', '::1', '[::1]'};

class _LocalConfig {
  _LocalConfig(this.url, this.anonKey, this.serviceKey);
  final String url;
  final String anonKey;
  final String serviceKey;

  /// Null when not configured. Throws when configured for a non-local host.
  static _LocalConfig? fromEnvironment() {
    final env = Platform.environment;
    final url = env['LOCAL_SUPABASE_URL'];
    final anon = env['LOCAL_SUPABASE_ANON_KEY'];
    final service = env['LOCAL_SUPABASE_SERVICE_ROLE_KEY'];
    if (url == null || anon == null || service == null || url.isEmpty || anon.isEmpty || service.isEmpty) {
      return null;
    }
    final host = Uri.parse(url).host;
    if (!_loopbackHosts.contains(host)) {
      throw StateError('Refusing to run lesson integration tests against non-local host "$host".');
    }
    return _LocalConfig(url, anon, service);
  }
}

/// A synthetic, confirmed learner with an authenticated client.
class _Learner {
  _Learner(this.id, this.client);
  final String id;
  final SupabaseClient client;
}

/// Fails the questions stage after terms were written (deterministic stand-in
/// for a dropped connection mid-import).
class _FailingQuestionsContentService extends LessonContentService {
  _FailingQuestionsContentService(SupabaseClient client) : super(supabase: client);

  @override
  Future<void> addQuestions(String lessonId, List<Question> questions) async {
    throw const PostgrestException(message: 'simulated network drop during questions insert');
  }
}

Map<String, dynamic> _lessonJson(String title, {String? termId}) => {
      'title': title,
      'description': 'Synthetic integration-test lesson',
      'tags': ['integration', 'synthetic'],
      'content': [
        {
          'type': 'term',
          if (termId != null) 'id': termId,
          'term': 'Widget',
          'definition': 'The basic building block of Flutter UIs',
          'example': 'Text and Row are widgets',
        },
        {
          'type': 'term',
          'term': 'State',
          'definition': 'Data that can change during a widget lifetime',
        },
        {
          'type': 'concept',
          'concept_text': 'Composition over inheritance',
          'example_text': 'Build screens from small widgets',
        },
        {
          'type': 'mcq',
          'question': 'What is Flutter?',
          'options': ['A programming language', 'A UI toolkit', 'A database', 'A design pattern'],
          'correct_answer': 1,
          'explanation': 'Flutter is a UI toolkit.',
        },
        {
          'type': 'true_false',
          'question': 'Widgets are immutable descriptions of UI.',
          'options': ['True', 'False'],
          'correct_answer': 0,
        },
        {
          'type': 'short_answer',
          'question': 'Name the method that rebuilds a StatefulWidget.',
          'accepted_answers': ['setState', 'setState()'],
          'grading_method': 'exact',
        },
      ],
    };

void main() {
  final requireLocal = Platform.environment['REQUIRE_LOCAL_SUPABASE'] == 'true';
  final config = _LocalConfig.fromEnvironment();

  if (config == null) {
    test('local Supabase configuration is present', () {
      if (requireLocal) {
        fail('REQUIRE_LOCAL_SUPABASE=true but LOCAL_SUPABASE_URL / _ANON_KEY / _SERVICE_ROLE_KEY are not set.');
      }
    }, skip: requireLocal ? false : 'Runs only in the Supabase CI job (set LOCAL_SUPABASE_* to run locally).');
    return;
  }

  late SupabaseClient admin;
  final createdUserIds = <String>[];

  Future<_Learner> newLearner() async {
    final email = 'lesson-it-${const Uuid().v4()}@example.test';
    final password = 'pw-${const Uuid().v4()}';
    final created = await admin.auth.admin.createUser(
      AdminUserAttributes(email: email, password: password, emailConfirm: true),
    );
    final id = created.user!.id;
    createdUserIds.add(id);
    final client = SupabaseClient(
      config.url,
      config.anonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final session = await client.auth.signInWithPassword(email: email, password: password);
    expect(session.user?.id, id);
    // The app creates the public.users profile row on first sign-in
    // (AuthProvider); lessons.user_id references it.
    await client.from('users').insert({'id': id, 'email': email});
    return _Learner(id, client);
  }

  LessonImportService importer(SupabaseClient client, {LessonContentService? content}) => LessonImportService(
        crudService: LessonCrudService(supabase: client),
        contentService: content ?? LessonContentService(supabase: client),
      );

  Future<List<Map<String, dynamic>>> rows(String table, String column, String value) async =>
      List<Map<String, dynamic>>.from(await admin.from(table).select().eq(column, value));

  setUpAll(() {
    admin = SupabaseClient(
      config.url,
      config.serviceKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });

  tearDownAll(() async {
    // Cascades remove lessons and their content; deleting auth users last.
    for (final id in createdUserIds) {
      await admin.from('lessons').delete().eq('user_id', id);
      await admin.from('users').delete().eq('id', id);
      await admin.auth.admin.deleteUser(id);
    }
  });

  test('import writes every item and the production read path returns it exactly', () async {
    final learner = await newLearner();
    final title = 'IT lesson ${const Uuid().v4()}';

    final created = await importer(learner.client).importLessonFromJson(jsonEncode(_lessonJson(title)), learner.id);

    final loaded = await LessonCrudService(supabase: learner.client).getLesson(created.id);
    expect(loaded.title, title);
    expect(loaded.description, 'Synthetic integration-test lesson');
    expect(loaded.tags, ['integration', 'synthetic']);
    expect(loaded.userId, learner.id);

    final terms = {for (final t in loaded.terms) t.term: t};
    expect(terms.keys, unorderedEquals(['Widget', 'State']));
    expect(terms['Widget']!.definition, 'The basic building block of Flutter UIs');
    expect(terms['Widget']!.example, 'Text and Row are widgets');
    expect(terms['State']!.example, isNull);

    expect(loaded.concepts, hasLength(1));
    expect(loaded.concepts.single.conceptText, 'Composition over inheritance');
    expect(loaded.concepts.single.exampleText, 'Build screens from small widgets');

    final questions = {for (final q in loaded.questions) q.questionText: q};
    expect(questions, hasLength(3));
    final mcq = questions['What is Flutter?']!;
    expect(mcq.type, 'mcq');
    expect(mcq.options, ['A programming language', 'A UI toolkit', 'A database', 'A design pattern']);
    expect(mcq.correctAnswer, 1);
    expect(mcq.explanation, 'Flutter is a UI toolkit.');
    final tf = questions['Widgets are immutable descriptions of UI.']!;
    expect(tf.type, 'true_false');
    expect(tf.options, ['True', 'False']);
    expect(tf.correctAnswer, 0);
    final short = questions['Name the method that rebuilds a StatefulWidget.']!;
    expect(short.type, 'short_answer');
    expect(short.acceptedAnswers, ['setState', 'setState()']);
    expect(short.gradingMethod, 'exact');

    // Independent check through the service role: exact persisted counts and
    // ownership, not just what the read path chose to return.
    expect(await rows('terms', 'lesson_id', created.id), hasLength(2));
    expect(await rows('concepts', 'lesson_id', created.id), hasLength(1));
    final dbQuestions = await rows('questions', 'lesson_id', created.id);
    expect(dbQuestions, hasLength(3));
    final lessonRows = await rows('lessons', 'id', created.id);
    expect(lessonRows.single['user_id'], learner.id);
    expect(lessonRows.single['visibility'], 'private');
  });

  test('an invalid answer key anywhere writes nothing (preflight before side effects)', () async {
    final learner = await newLearner();
    final title = 'IT invalid ${const Uuid().v4()}';
    final payload = _lessonJson(title);
    (payload['content'] as List).add({
      'type': 'mcq',
      'question': 'Which key is missing?',
      'options': ['a', 'b'],
      'correct_answer': 7,
    });

    await expectLater(
      importer(learner.client).importLessonFromJson(jsonEncode(payload), learner.id),
      throwsA(isA<LessonImportValidationException>()
          .having((e) => e.issues.map((i) => i.path), 'paths', contains(startsWith('content[6]')))),
    );
    expect(await rows('lessons', 'title', title), isEmpty);
    expect(await rows('lessons', 'user_id', learner.id), isEmpty);
  });

  test('a failure after the lesson row exists is reported and cleaned up in the database', () async {
    final learner = await newLearner();
    final title = 'IT partial ${const Uuid().v4()}';

    final error = await importer(learner.client, content: _FailingQuestionsContentService(learner.client))
        .importLessonFromJson(jsonEncode(_lessonJson(title)), learner.id)
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<LessonImportIncompleteException>());
    final incomplete = error! as LessonImportIncompleteException;
    expect(incomplete.stage, 'questions');
    expect(incomplete.cleanedUp, isTrue);
    // Terms were written before the failure; the cleanup must have removed
    // them (via the lesson cascade), not just reported success.
    expect(await rows('lessons', 'id', incomplete.lessonId), isEmpty);
    expect(await rows('terms', 'lesson_id', incomplete.lessonId), isEmpty);
    expect(await rows('concepts', 'lesson_id', incomplete.lessonId), isEmpty);
  });

  test('a real database rejection mid-import (duplicate item id) leaves no partial lesson', () async {
    final learner = await newLearner();
    final termId = const Uuid().v4();
    final first = await importer(learner.client)
        .importLessonFromJson(jsonEncode(_lessonJson('IT first ${const Uuid().v4()}', termId: termId)), learner.id);

    final secondTitle = 'IT second ${const Uuid().v4()}';
    final error = await importer(learner.client)
        .importLessonFromJson(jsonEncode(_lessonJson(secondTitle, termId: termId)), learner.id)
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(error, isA<LessonImportIncompleteException>());
    final incomplete = error! as LessonImportIncompleteException;
    expect(incomplete.stage, 'terms');
    expect(incomplete.cleanedUp, isTrue);
    expect(await rows('lessons', 'title', secondTitle), isEmpty);
    // The first lesson is untouched by the failed second import.
    expect(await rows('terms', 'lesson_id', first.id), hasLength(2));
    expect(await rows('questions', 'lesson_id', first.id), hasLength(3));
  });

  test('another learner cannot read a private imported lesson', () async {
    final owner = await newLearner();
    final other = await newLearner();
    final created = await importer(owner.client)
        .importLessonFromJson(jsonEncode(_lessonJson('IT private ${const Uuid().v4()}')), owner.id);

    final visible = await other.client.from('lessons').select('id').eq('id', created.id);
    expect(visible, isEmpty);
    final leakedQuestions = await other.client.from('questions').select('id').eq('lesson_id', created.id);
    expect(leakedQuestions, isEmpty);
  });

  test('configuration guard refuses non-local hosts', () {
    expect(_loopbackHosts.contains(Uri.parse('https://abc.supabase.co').host), isFalse);
    expect(_loopbackHosts.contains(Uri.parse(config.url).host), isTrue);
  });
}
