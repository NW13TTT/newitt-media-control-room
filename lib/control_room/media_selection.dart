import 'dart:typed_data';

class MediaSelection {
  const MediaSelection(this.name, this.length, this.readBytes);

  final String name;
  final int length;
  final Future<Uint8List> Function() readBytes;

  String get extension => name.contains('.') ? name.split('.').last : '';
}
