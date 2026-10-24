/// A calm, user-presentable failure from a repository or rule check.
class CircleFailure implements Exception {
  const CircleFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
