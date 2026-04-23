// File: lib/core/utils/app_file_utils.dart
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AppFileUtils {
  static Future<String> getApplicationDocumentsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Converte un path relativo memorizzato nel DB in un path assoluto reale
  static Future<String> resolve(String relativePath) async {
    // Se è vuoto o già assoluto (gestione legacy), restituiamo così com'è
    if (relativePath.isEmpty || p.isAbsolute(relativePath)) return relativePath;

    final base = await getApplicationDocumentsPath();
    return p.join(base, relativePath);
  }

  /// Converte un path assoluto in relativo per la memorizzazione nel DB
  static Future<String> toRelative(String absolutePath) async {
    if (absolutePath.isEmpty || !p.isAbsolute(absolutePath)) {
      return absolutePath;
    }

    final base = await getApplicationDocumentsPath();
    try {
      return p.relative(absolutePath, from: base);
    } catch (e) {
      // Fallback: se il path è fuori dal base, prendiamo solo il nome file
      return p.basename(absolutePath);
    }
  }
}
