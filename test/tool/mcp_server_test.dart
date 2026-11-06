import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../../tool/mcp_server/src/learning_data_source.dart';
import '../../tool/mcp_server/src/learningapp_mcp_server.dart';
import '../../tool/mcp_server/src/mcp_protocol.dart';

void main() {
  group('LearningApp MCP Server Protocol & Handshake Tests', () {
    late LearningDataSource dataSource;
    late LearningAppMcpServer server;

    setUp(() {
      dataSource = LearningDataSource(
        contentDir: 'content',
        offline: true,
      );
      server = LearningAppMcpServer(
        dataSource: dataSource,
        serverName: 'learningapp-test-mcp',
        serverVersion: '1.0.0-test',
      );
    });

    test('initialize returns protocolVersion, serverInfo, and capabilities', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2024-11-05',
          'capabilities': {},
          'clientInfo': {'name': 'test-client', 'version': '1.0.0'}
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;

      expect(res['jsonrpc'], '2.0');
      expect(res['id'], 1);
      final result = res['result'] as Map<String, dynamic>;
      expect(result['serverInfo']['name'], 'learningapp-test-mcp');
      expect(result['serverInfo']['version'], '1.0.0-test');
      expect(result['capabilities']['tools'], isNotNull);
      expect(result['capabilities']['resources'], isNotNull);
      expect(result['capabilities']['prompts'], isNotNull);
    });

    test('notifications/initialized produces null response (no-op notification)', () async {
      final notification = jsonEncode({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
        'params': {}
      });

      final resStr = await server.handleMessage(notification);
      expect(resStr, isNull);
    });

    test('ping returns empty result map', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 'ping-123',
        'method': 'ping',
        'params': {}
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      expect(res['id'], 'ping-123');
      expect(res['result'], equals({}));
    });

    test('invalid JSON returns Parse error (-32700)', () async {
      final resStr = await server.handleMessage('this is not json {');
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      expect(res['error']['code'], McpErrorCodes.parseError);
    });

    test('unknown method returns Method not found (-32601)', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 42,
        'method': 'nonexistent_rpc_method',
        'params': {}
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      expect(res['error']['code'], McpErrorCodes.methodNotFound);
    });
  });

  group('LearningApp MCP Tools Tests', () {
    late LearningDataSource dataSource;
    late LearningAppMcpServer server;

    setUp(() {
      dataSource = LearningDataSource(
        contentDir: 'content',
        offline: true,
      );
      server = LearningAppMcpServer(
        dataSource: dataSource,
      );
    });

    test('tools/list returns all 10 registered tools with valid schemas', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final tools = res['result']['tools'] as List;

      expect(tools.length, 10);
      final toolNames = tools.map((t) => t['name'] as String).toSet();
      expect(toolNames, containsAll([
        'search_catalog',
        'get_target_outline',
        'get_exam_blueprint',
        'get_learner_state',
        'get_due_items',
        'explain_item',
        'compute_item_analytics',
        'submit_review',
        'validate_lesson',
        'propose_item_fix',
      ]));
    });

    test('tools/call: search_catalog discovers local manifests', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 3,
        'method': 'tools/call',
        'params': {
          'name': 'search_catalog',
          'arguments': {'query': 'security', 'limit': 5}
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final content = res['result']['content'] as List;
      expect(content.first['type'], 'text');
      final data = jsonDecode(content.first['text']) as Map<String, dynamic>;

      expect(data['count'], greaterThan(0));
      final results = data['results'] as List;
      expect(results.any((r) => r['slug'] == 'cert-comptia-security-plus'), isTrue);
    });

    test('tools/call: get_target_outline returns curriculum domain tree', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 4,
        'method': 'tools/call',
        'params': {
          'name': 'get_target_outline',
          'arguments': {'target_slug': 'cert-comptia-security-plus'}
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final data = jsonDecode(res['result']['content'][0]['text']) as Map<String, dynamic>;

      expect(data['target']['slug'], 'cert-comptia-security-plus');
      expect(data['domains'], isNotEmpty);
    });

    test('tools/call: get_exam_blueprint returns domains and total weights', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 5,
        'method': 'tools/call',
        'params': {
          'name': 'get_exam_blueprint',
          'arguments': {'target_version_id': 'cert-comptia-security-plus'}
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final data = jsonDecode(res['result']['content'][0]['text']) as Map<String, dynamic>;

      expect(data['total_domains'], greaterThan(0));
      expect(data['total_weight'], closeTo(1.0, 0.05));
    });

    test('tools/call: get_learner_state returns calibrated readiness metrics', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 6,
        'method': 'tools/call',
        'params': {
          'name': 'get_learner_state',
          'arguments': {
            'user_id': 'user-123',
            'target_version_id': 'cert-comptia-security-plus',
          }
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final data = jsonDecode(res['result']['content'][0]['text']) as Map<String, dynamic>;

      expect(data['user_id'], 'user-123');
      expect(data['readiness_band'], isNotNull);
      expect(data['weakest_concepts'], isNotEmpty);
    });

    test('tools/call: get_due_items returns scheduled reviews', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 7,
        'method': 'tools/call',
        'params': {
          'name': 'get_due_items',
          'arguments': {'user_id': 'user-123'}
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final data = jsonDecode(res['result']['content'][0]['text']) as Map<String, dynamic>;

      expect(data['due_count'], greaterThan(0));
      expect(data['items'], isNotEmpty);
    });

    test('tools/call: compute_item_analytics returns psychometric stats', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 8,
        'method': 'tools/call',
        'params': {
          'name': 'compute_item_analytics',
          'arguments': {'item_id': 'item-security-hash-integrity'}
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final data = jsonDecode(res['result']['content'][0]['text']) as Map<String, dynamic>;

      expect(data['p_value'], greaterThanOrEqualTo(0.0));
      expect(data['point_biserial'], greaterThanOrEqualTo(0.0));
    });

    test('tools/call: submit_review creates audited review event', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 9,
        'method': 'tools/call',
        'params': {
          'name': 'submit_review',
          'arguments': {
            'user_id': 'user-456',
            'item_id': 'item-001',
            'rating': 3,
            'client_id': 'mcp:test-runner'
          }
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final data = jsonDecode(res['result']['content'][0]['text']) as Map<String, dynamic>;

      expect(data['event_id'], startsWith('mcp-'));
      expect(data['payload']['rating'], 3);
      expect(data['payload']['metadata']['origin_client_id'], 'mcp:test-runner');
    });

    test('tools/call: validate_lesson detects Haladyna violations (negative stems and all-of-the-above)', () async {
      final flawedContent = {
        'content': [
          {
            'type': 'mcq',
            'question': 'Which of the following is NOT a characteristic of asymmetric cryptography?',
            'options': [
              'Uses public and private key pairs',
              'Slower than symmetric cryptography',
              'All of the above',
              'Used for digital signatures'
            ],
            'correctIndex': 2,
          }
        ]
      };

      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 10,
        'method': 'tools/call',
        'params': {
          'name': 'validate_lesson',
          'arguments': {'content': flawedContent}
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final data = jsonDecode(res['result']['content'][0]['text']) as Map<String, dynamic>;

      expect(data['is_valid'], isFalse);
      expect(data['status'], 'FAILED');
      final issues = data['issues'] as List;
      final rules = issues.map((i) => i['rule']).toSet();
      expect(rules, contains('HALADYNA_NEGATIVE_STEM'));
      expect(rules, contains('HALADYNA_ALL_NONE_ABOVE'));
    });

    test('tools/call: propose_item_fix records suggestion into moderation queue', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 11,
        'method': 'tools/call',
        'params': {
          'name': 'propose_item_fix',
          'arguments': {
            'item_id': 'item-007',
            'reason': 'factual_error',
            'suggested_stem': 'What is the standard block size of AES in bits?'
          }
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final data = jsonDecode(res['result']['content'][0]['text']) as Map<String, dynamic>;

      expect(data['report_id'], startsWith('mod-'));
      expect(data['item_id'], 'item-007');
    });
  });

  group('LearningApp MCP Resources Tests', () {
    late LearningDataSource dataSource;
    late LearningAppMcpServer server;

    setUp(() {
      dataSource = LearningDataSource(
        contentDir: 'content',
        offline: true,
      );
      server = LearningAppMcpServer(
        dataSource: dataSource,
      );
    });

    test('resources/list returns catalog, schema, and rubric resources', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 12,
        'method': 'resources/list',
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final resources = res['result']['resources'] as List;

      final uris = resources.map((r) => r['uri'] as String).toList();
      expect(uris, containsAll([
        'learningapp://schema/curriculum_manifest',
        'learningapp://schema/lesson',
        'learningapp://rubrics/item_writing',
        'learningapp://catalog/targets',
      ]));
    });

    test('resources/read: item writing rubric returns Haladyna guidelines', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 13,
        'method': 'resources/read',
        'params': {'uri': 'learningapp://rubrics/item_writing'}
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final contents = res['result']['contents'] as List;

      expect(contents.first['mimeType'], 'text/markdown');
      expect(contents.first['text'], contains('Haladyna'));
    });

    test('resources/read: dynamic curriculum returns target outline', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 14,
        'method': 'resources/read',
        'params': {'uri': 'learningapp://curriculum/cert-comptia-security-plus'}
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final contents = res['result']['contents'] as List;

      expect(contents.first['mimeType'], 'application/json');
      final data = jsonDecode(contents.first['text']) as Map<String, dynamic>;
      expect(data['target']['slug'], 'cert-comptia-security-plus');
    });
  });

  group('LearningApp MCP Prompts Tests', () {
    late LearningDataSource dataSource;
    late LearningAppMcpServer server;

    setUp(() {
      dataSource = LearningDataSource(
        contentDir: 'content',
        offline: true,
      );
      server = LearningAppMcpServer(
        dataSource: dataSource,
      );
    });

    test('prompts/list returns 3 prompts', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 15,
        'method': 'prompts/list',
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final prompts = res['result']['prompts'] as List;

      final names = prompts.map((p) => p['name'] as String).toList();
      expect(names, containsAll([
        'study_weak_concepts',
        'socratic_tutor',
        'exam_readiness_coaching',
      ]));
    });

    test('prompts/get: study_weak_concepts renders instructional template', () async {
      final req = jsonEncode({
        'jsonrpc': '2.0',
        'id': 16,
        'method': 'prompts/get',
        'params': {
          'name': 'study_weak_concepts',
          'arguments': {'target_slug': 'cert-comptia-security-plus'}
        }
      });

      final resStr = await server.handleMessage(req);
      expect(resStr, isNotNull);
      final res = jsonDecode(resStr!) as Map<String, dynamic>;
      final messages = res['result']['messages'] as List;

      expect(messages.first['role'], 'user');
      expect(messages.first['content']['text'], contains('Haladyna'));
    });
  });
}
