import 'dart:async';
import 'dart:js_interop';

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
          if (files.item(i) case final file?)
            MediaSelection(
              file.name,
              file.size,
              () async =>
                  (await file.arrayBuffer().toDart).toDart.asUint8List(),
            ),
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
