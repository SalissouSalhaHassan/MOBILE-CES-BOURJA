String getHomeRouteForRole(String role) {
  final normalized = role.toLowerCase().trim();
  if (normalized == 'ministere' ||
      normalized == 'dren' ||
      normalized == 'dden' ||
      normalized == 'inspection') {
    return '/ministry/dashboard';
  }
  if (normalized == 'owner' || normalized == 'super_admin') {
    return '/owner/dashboard';
  }
  if (normalized == 'student' || normalized == 'parent') {
    return '/family/dashboard';
  }
  return '/dashboard';
}
