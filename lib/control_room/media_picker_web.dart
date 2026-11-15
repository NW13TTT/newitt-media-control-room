import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'media_selection.dart';

Future<List<MediaSelection>> pickMedia() {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..style.display = 'none';
  final result = Completer<List<MediaSelection>>();

  final change = ((web.Event _) {
    final files = input.files;
    result.complete([
      if (files != null)
        for (var i = 0; i < files.length; i++)
          if (files.item(i) case final file?) _selection(file),
    ]);
  }).toJS;
  final cancel = ((web.Event _) => result.complete(<MediaSelection>[])).toJS;

  input.addEventListener('change', change);
  input.addEventListener('cancel', cancel);
  web.document.body!.appendChild(input);
  // Safari can return focus before dispatching change. Keep the input attached
  // until the picker actually reports a result.
  try {
    input.click();
  } catch (error, stack) {
    result.completeError(error, stack);
  }
  return result.future.timeout(const Duration(minutes: 2)).whenComplete(() {
    input.removeEventListener('change', change);
    input.removeEventListener('cancel', cancel);
    input.remove();
  });
}

MediaSelection _selection(web.File file) {
  final heifExtension = RegExp(r'\.hei[cf]$', caseSensitive: false);
  final convert =
      heifExtension.hasMatch(file.name) ||
      const {'image/heic', 'image/heif'}.contains(file.type);
  if (!convert) {
    return MediaSelection(
      file.name,
      file.size,
      () async => (await file.arrayBuffer().toDart).toDart.asUint8List(),
    );
  }
  final baseName = file.name.replaceFirst(heifExtension, '');
  return MediaSelection('$baseName.jpg', file.size, () => _jpegBytes(file));
}

Future<Uint8List> _jpegBytes(web.File file) async {
  final url = web.URL.createObjectURL(file);
  final image = web.HTMLImageElement()..src = url;
  final canvas = web.HTMLCanvasElement();
  try {
    try {
      await image.decode().toDart.timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const FormatException(
        'This browser could not open the HEIC or HEIF photo. Export it as JPEG and retry.',
      );
    }
    final longest = math.max(image.naturalWidth, image.naturalHeight);
    if (longest == 0) throw const FormatException('The photo is empty.');
    final scale = math.min(1.0, 4096 / longest);
    canvas
      ..width = math.max(1, (image.naturalWidth * scale).round())
      ..height = math.max(1, (image.naturalHeight * scale).round());
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context.drawImage(image, 0, 0, canvas.width, canvas.height);
    final encoded = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? result) => encoded.complete(result)).toJS,
      'image/jpeg',
      0.9.toJS,
    );
    final jpeg = await encoded.future.timeout(const Duration(seconds: 10));
    if (jpeg == null || jpeg.type != 'image/jpeg') {
      throw const FormatException('The photo could not be converted to JPEG.');
    }
    return (await jpeg.arrayBuffer().toDart).toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(url);
    canvas
      ..width = 0
      ..height = 0;
  }
}
