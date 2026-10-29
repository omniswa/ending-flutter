/// Central, compile-time configuration.
abstract final class AppConfig {
  static const appName = '3NDING';
  static const tagline = 'READ MORE · DISCOVER MORE';

  /// Where `books.json` and the book zips are hosted. Must end with '/'.
  /// Override: `--dart-define=BASE_URL=https://example.com/`
  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://omniswa.github.io/ending-web-draft1/',
  );
  static const booksIndex = 'books.json';

  /// Resolves a catalog path against [baseUrl]. Absolute URLs pass through
  /// unchanged, so this is safe to call on already-resolved values.
  static String resolve(String path) =>
      Uri.parse(baseUrl).resolve(path.trim()).toString();
  static const requestTimeout = Duration(seconds: 20);
  static const wordsPerMinute = 220;
  static const charsPerWord = 5.8;
}
