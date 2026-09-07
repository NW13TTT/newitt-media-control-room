import 'package:file_picker/file_picker.dart';
import 'package:file_picker_web/file_picker_web.dart';

/// Mobile browsers regain window focus before the file input reports a
/// selection, and cloud-backed files take longer still, so blur cancellation
/// discards the pick. Bytes are read on demand so oversized videos can be
/// rejected before they are loaded into memory.
WebOptions mediaPickerWebOptions() => const FilePickerWebOptions(
  withData: false,
  cancelUploadOnWindowBlur: false,
);
