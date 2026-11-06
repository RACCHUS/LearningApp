import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// JSON-RPC 2.0 Error Codes as defined by the JSON-RPC spec & MCP.
class McpErrorCodes {
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;
}

/// A JSON-RPC 2.0 Request or Notification.
class JsonRpcMessage {
  final dynamic id; // null for notifications
  final String method;
  final Map<String, dynamic> params;

  JsonRpcMessage({
    this.id,
    required this.method,
    this.params = const {},
  });

  bool get isNotification => id == null;

  factory JsonRpcMessage.fromJson(Map<String, dynamic> json) {
    if (json['jsonrpc'] != '2.0') {
      throw FormatException('Invalid or missing jsonrpc version: ${json['jsonrpc']}');
    }
    final method = json['method'];
    if (method == null || method is! String) {
      throw FormatException('Missing or invalid method: $method');
    }
    final rawParams = json['params'];
    Map<String, dynamic> params = const {};
    if (rawParams is Map) {
      params = rawParams.cast<String, dynamic>();
    }

    return JsonRpcMessage(
      id: json['id'],
      method: method,
      params: params,
    );
  }
}

/// Model Context Protocol stdio transport and JSON-RPC 2.0 dispatcher.
class McpProtocolServer {
  final String serverName;
  final String serverVersion;
  final String protocolVersion;
  final bool verbose;

  final Map<String, Future<dynamic> Function(Map<String, dynamic> params)> _methodHandlers = {};
  final List<void Function(String method, Map<String, dynamic> params)> _notificationHandlers = [];

  StreamSubscription<String>? _stdinSub;

  McpProtocolServer({
    this.serverName = 'learningapp-mcp',
    this.serverVersion = '1.0.0',
    this.protocolVersion = '2024-11-05',
    this.verbose = false,
  }) {
    _registerCoreHandlers();
  }

  void _log(String message) {
    if (verbose) {
      stderr.writeln('[$serverName] $message');
    }
  }

  void _registerCoreHandlers() {
    registerHandler('initialize', (params) async {
      _log('Received initialize request');
      return {
        'protocolVersion': protocolVersion,
        'capabilities': {
          'tools': {
            'listChanged': false,
          },
          'resources': {
            'subscribe': false,
            'listChanged': false,
          },
          'prompts': {
            'listChanged': false,
          },
        },
        'serverInfo': {
          'name': serverName,
          'version': serverVersion,
        },
      };
    });

    registerHandler('ping', (params) async {
      return {};
    });

    registerNotificationHandler((method, params) {
      if (method == 'notifications/initialized') {
        _log('Client sent initialized notification');
      }
    });
  }

  void registerHandler(String method, Future<dynamic> Function(Map<String, dynamic> params) handler) {
    _methodHandlers[method] = handler;
  }

  void registerNotificationHandler(void Function(String method, Map<String, dynamic> params) handler) {
    _notificationHandlers.add(handler);
  }

  /// Processes a single JSON-RPC incoming string message and returns response string if applicable.
  Future<String?> handleMessage(String line) async {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (e) {
      return jsonEncode({
        'jsonrpc': '2.0',
        'id': null,
        'error': {
          'code': McpErrorCodes.parseError,
          'message': 'Parse error: invalid JSON: $e',
        },
      });
    }

    if (decoded is! Map<String, dynamic>) {
      return jsonEncode({
        'jsonrpc': '2.0',
        'id': null,
        'error': {
          'code': McpErrorCodes.invalidRequest,
          'message': 'Invalid Request: expected JSON object',
        },
      });
    }

    JsonRpcMessage msg;
    try {
      msg = JsonRpcMessage.fromJson(decoded);
    } catch (e) {
      return jsonEncode({
        'jsonrpc': '2.0',
        'id': decoded['id'],
        'error': {
          'code': McpErrorCodes.invalidRequest,
          'message': 'Invalid Request: $e',
        },
      });
    }

    if (msg.isNotification) {
      for (final handler in _notificationHandlers) {
        try {
          handler(msg.method, msg.params);
        } catch (e) {
          _log('Error handling notification ${msg.method}: $e');
        }
      }
      return null;
    }

    final handler = _methodHandlers[msg.method];
    if (handler == null) {
      _log('Method not found: ${msg.method}');
      return jsonEncode({
        'jsonrpc': '2.0',
        'id': msg.id,
        'error': {
          'code': McpErrorCodes.methodNotFound,
          'message': 'Method not found: ${msg.method}',
        },
      });
    }

    try {
      final result = await handler(msg.params);
      return jsonEncode({
        'jsonrpc': '2.0',
        'id': msg.id,
        'result': result,
      });
    } catch (e, st) {
      _log('Error executing ${msg.method}: $e\n$st');
      return jsonEncode({
        'jsonrpc': '2.0',
        'id': msg.id,
        'error': {
          'code': McpErrorCodes.internalError,
          'message': 'Internal error: $e',
        },
      });
    }
  }

  /// Start listening on standard input and writing to standard output.
  Future<void> listenStdio() async {
    _log('Starting stdio transport...');
    final lines = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    _stdinSub = lines.listen((line) async {
      final response = await handleMessage(line);
      if (response != null) {
        stdout.writeln(response);
      }
    }, onError: (error) {
      _log('Error on stdin: $error');
    }, onDone: () {
      _log('stdin closed. Server shutting down.');
    });
  }

  Future<void> stop() async {
    await _stdinSub?.cancel();
    _stdinSub = null;
  }
}
