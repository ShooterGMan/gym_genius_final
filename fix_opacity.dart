import 'dart:io';

void main() {
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('lib directory not found');
    return;
  }

  int count = 0;
  for (final file in libDir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      if (content.contains('.withOpacity(')) {
        content = content.replaceAllMapped(
          RegExp(r'\.withOpacity\(([^)]+)\)'),
          (match) => '.withValues(alpha: ${match.group(1)})'
        );
        file.writeAsStringSync(content);
        count++;
        print('Updated ${file.path}');
      }
    }
  }
  print('Updated $count files.');
}
