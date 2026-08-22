/// Failure codes the settings feature reports (`<area>.<reason>`).
abstract final class SettingsFailureCodes {
  /// The persisted settings could not be read (storage stream error).
  static const String load = 'settings.load-failed';
  static const String save = 'settings.save-failed';
}
