abstract final class AppConfig {
  static const appName = '3NDING';
  static const tagline = 'READ MORE · DISCOVER MORE';

  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://omniswa.github.io/ending-web-draft1/',
  );

  static const bundledFonts = true;

  static const booksIndex = 'books.json';

  static String resolve(String path) =>
      Uri.parse(baseUrl).resolve(path.trim()).toString();
  static const requestTimeout = Duration(seconds: 20);
  static const wordsPerMinute = 220;
  static const charsPerWord = 5.8;
}
