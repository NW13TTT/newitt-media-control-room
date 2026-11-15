import 'package:file_picker/file_picker.dart';

import 'media_selection.dart';

Future<List<MediaSelection>> pickMedia() async {
  final files = await FilePicker.pickFiles(type: FileType.any);
  return [
    for (final file in files)
      MediaSelection(file.name, await file.length(), file.readAsBytes),
  ];
}
