class AppManagedFilePathResolution {
  const AppManagedFilePathResolution({
    required this.originalPath,
    required this.resolvedPath,
    required this.exists,
    required this.rebased,
  });

  final String originalPath;
  final String? resolvedPath;
  final bool exists;
  final bool rebased;
}

Future<AppManagedFilePathResolution> resolveAppManagedFilePath(
  String? path,
) async {
  final originalPath = path?.trim() ?? '';
  return AppManagedFilePathResolution(
    originalPath: originalPath,
    resolvedPath: null,
    exists: false,
    rebased: false,
  );
}

String? resolveExistingAppManagedFilePathSync(String? path) => null;

bool hasPotentiallyRebasableAppManagedFilePath(String? path) => false;
