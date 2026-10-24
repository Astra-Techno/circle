/// The outcome of a pure domain rule: allowed, or denied with calm copy that
/// can be shown to the person as-is. Shared by every feature's rules.
class RuleResult {
  const RuleResult.allowed() : reason = null;
  const RuleResult.denied(String this.reason);
  final String? reason;
  bool get allowed => reason == null;
}
