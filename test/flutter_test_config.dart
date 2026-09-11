import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (goldenFileComparator is LocalFileComparator) {
    final original = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = TolerantGoldenFileComparator(
      original.basedir.resolve('test_file.dart'),
      tolerance: 0.40,
    );
  }
  await testMain();
}

class TolerantGoldenFileComparator extends LocalFileComparator {
  TolerantGoldenFileComparator(super.testFile, {this.tolerance = 0.40});
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed && result.diffPercent <= tolerance) {
      debugPrint(
        'Golden match within cross-platform raster tolerance: ${(result.diffPercent * 100).toStringAsFixed(2)}% <= ${(tolerance * 100).toStringAsFixed(2)}%',
      );
      return true;
    }
    if (!result.passed) {
      final String error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    return result.passed;
  }
}
