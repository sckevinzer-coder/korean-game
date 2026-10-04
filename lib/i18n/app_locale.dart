/// UI locales. Japanese is the default and the fallback language.
enum AppLocale {
  japanese('ja', '日本語'),
  korean('ko', '한국어'),
  english('en', 'English');

  const AppLocale(this.code, this.label);

  final String code;
  final String label;

  static AppLocale parse(String? code) {
    for (final locale in AppLocale.values) {
      if (locale.code == code) return locale;
    }
    return AppLocale.japanese;
  }
}
