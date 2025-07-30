import 'package:build_runner/build_runner.dart';
import 'package:source_gen/source_gen.dart';
import 'package:json_serializable/builder.dart';
import 'dart:io';

Future<void> main() async {
  final generated = await generate(
    [
      apply(
        'json_serializable',
        [
          _generateBuilder,
        ],
        toRoot(),
      )
    ],
    deleteFilesByDefault: true,
  );
  
  // Save the generated code to a file
  final outputFile = File('lib/models/concept.g.dart');
  await outputFile.writeAsString(generated.toString());
  print('Generated file: ${outputFile.path}');
}

Builder _generateBuilder(_) => PartBuilder(
      [
        JsonSerializableGenerator(
          config: const {
            'explicit_to_json': true,
          },
        ),
      ],
      '.g.dart',
      header: '// GENERATED CODE - DO NOT MODIFY BY HAND\n\n',
    );
