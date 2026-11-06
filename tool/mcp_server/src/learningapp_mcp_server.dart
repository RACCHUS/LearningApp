import 'learning_data_source.dart';
import 'mcp_prompts.dart';
import 'mcp_protocol.dart';
import 'mcp_resources.dart';
import 'mcp_tools.dart';

/// The high-level LearningApp Model Context Protocol (MCP) Server.
class LearningAppMcpServer {
  final LearningDataSource dataSource;
  final McpProtocolServer protocolServer;
  late final McpToolsRegistry toolsRegistry;
  late final McpResourcesRegistry resourcesRegistry;
  late final McpPromptsRegistry promptsRegistry;

  LearningAppMcpServer({
    required this.dataSource,
    String serverName = 'learningapp-mcp',
    String serverVersion = '1.0.0',
    bool verbose = false,
  }) : protocolServer = McpProtocolServer(
          serverName: serverName,
          serverVersion: serverVersion,
          verbose: verbose,
        ) {
    toolsRegistry = McpToolsRegistry(dataSource: dataSource);
    resourcesRegistry = McpResourcesRegistry(dataSource: dataSource);
    promptsRegistry = McpPromptsRegistry(dataSource: dataSource);

    _wireHandlers();
  }

  void _wireHandlers() {
    // Tools
    protocolServer.registerHandler('tools/list', (params) async {
      return {
        'tools': toolsRegistry.listTools(),
      };
    });

    protocolServer.registerHandler('tools/call', (params) async {
      final name = params['name'] as String?;
      if (name == null || name.isEmpty) {
        throw FormatException('Missing "name" in tools/call parameters');
      }
      final rawArgs = params['arguments'];
      Map<String, dynamic> arguments = const {};
      if (rawArgs is Map) {
        arguments = rawArgs.cast<String, dynamic>();
      }
      return await toolsRegistry.callTool(name, arguments);
    });

    // Resources
    protocolServer.registerHandler('resources/list', (params) async {
      return {
        'resources': resourcesRegistry.listResources(),
      };
    });

    protocolServer.registerHandler('resources/read', (params) async {
      final uri = params['uri'] as String?;
      if (uri == null || uri.isEmpty) {
        throw FormatException('Missing "uri" in resources/read parameters');
      }
      return await resourcesRegistry.readResource(uri);
    });

    // Prompts
    protocolServer.registerHandler('prompts/list', (params) async {
      return {
        'prompts': promptsRegistry.listPrompts(),
      };
    });

    protocolServer.registerHandler('prompts/get', (params) async {
      final name = params['name'] as String?;
      if (name == null || name.isEmpty) {
        throw FormatException('Missing "name" in prompts/get parameters');
      }
      final rawArgs = params['arguments'];
      Map<String, dynamic> arguments = const {};
      if (rawArgs is Map) {
        arguments = rawArgs.cast<String, dynamic>();
      }
      return await promptsRegistry.getPrompt(name, arguments);
    });
  }

  Future<String?> handleMessage(String line) => protocolServer.handleMessage(line);

  Future<void> start() => protocolServer.listenStdio();

  Future<void> stop() => protocolServer.stop();
}
