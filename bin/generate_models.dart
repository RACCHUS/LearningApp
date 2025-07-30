import 'package:build_runner/build_runner.dart';
import 'package:source_gen/builder.dart';

Future<void> main() async {
  await build([
    applyToRoot(),
    apply(
      'learning_pwa',
      [
        JsonSerializableGenerator(),
      ],
      to: allPackageAssets(),
    ),
  ], deleteFilesByDefault: true);
}
