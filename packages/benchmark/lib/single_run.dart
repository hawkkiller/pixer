import 'package:benchmark_harness/benchmark_harness.dart';

/// `BenchmarkBase.exercise` runs `run` 10 times, so `measure` would report the
/// cost of 10 operations. This makes it report a single operation.
mixin SingleRun on BenchmarkBase {
  @override
  void exercise() => run();
}
