/// Central place for all "who made this / what version is this" facts.
/// Keep this as the single source of truth — every About/footer/settings
/// screen should read from here rather than hardcoding strings.
class AppInfo {
  static const String appName = 'Result Desk';
  static const String tagline = 'Find Results. Trust Result Desk.';
  static const String developer = 'Taimoor Hassan';

  /// Custom versioning scheme requested by the developer:
  /// THC.RD.YY MM DD.NN
  ///   THC = Taimoor Hassan Creation
  ///   RD  = Result Desk
  ///   26  = year 2026
  ///   08  = month August
  ///   16  = day 16
  ///   01  = release number for that day
  ///
  /// NOTE: bump the trailing NN (and the date block) on every release you
  /// ship, and mirror the numeric part into pubspec.yaml's `version:` field
  /// (that one must stay strictly numeric for the Play Store / Gradle).
  static const String versionCode = 'THC.RD.260816.01';

  static const String copyrightLine =
      'Result Desk is an independent search tool built from official board '
      'result gazettes. Not affiliated with any examination board. '
      'For certified results, always confirm with the issuing board.';
}
