enum SyncUrlProblem { empty, notAUrl, unsupportedScheme }

sealed class SyncUrlCheck {
  const SyncUrlCheck();
}

class SyncUrlUsable extends SyncUrlCheck {
  const SyncUrlUsable(this.uri);

  final Uri uri;
}

class SyncUrlInsecure extends SyncUrlCheck {
  const SyncUrlInsecure(this.uri);

  final Uri uri;
}

class SyncUrlRejected extends SyncUrlCheck {
  const SyncUrlRejected(this.problem);

  final SyncUrlProblem problem;
}

const _loopbackHosts = {'localhost', '127.0.0.1', '::1', '0.0.0.0'};

SyncUrlCheck checkSyncUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return const SyncUrlRejected(SyncUrlProblem.empty);

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const SyncUrlRejected(SyncUrlProblem.notAUrl);
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return const SyncUrlRejected(SyncUrlProblem.unsupportedScheme);
  }
  if (uri.scheme == 'http' && !isLoopbackHost(uri.host)) {
    return SyncUrlInsecure(uri);
  }
  return SyncUrlUsable(uri);
}

bool isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return _loopbackHosts.contains(normalized) ||
      normalized.endsWith('.localhost');
}
