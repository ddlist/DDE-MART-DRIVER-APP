// DDE-Mart driver app — launch gate logic (original, unit-tested).

enum GateDecision { ok, updateRequired, maintenance }

GateDecision gateStatus({
  required String current,
  required String minimum,
  required bool maintenance,
}) {
  if (maintenance) return GateDecision.maintenance;
  return _compareVersions(current, minimum) < 0
      ? GateDecision.updateRequired
      : GateDecision.ok;
}

int _compareVersions(String a, String b) {
  final pa = a.split('.').map(_head).toList();
  final pb = b.split('.').map(_head).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

int _head(String segment) {
  final match = RegExp(r'^\d+').firstMatch(segment);
  return match == null ? 0 : int.parse(match.group(0)!);
}
