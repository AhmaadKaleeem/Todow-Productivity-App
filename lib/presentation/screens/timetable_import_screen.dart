import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/core/utils/date_format.dart';
import 'package:todow/data/timetable_import_parser.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/timetable_import.dart';
import 'package:todow/presentation/providers/timetable_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TimetableImportScreen extends ConsumerStatefulWidget {
  const TimetableImportScreen({required this.scheduleKind, super.key});

  final TimetableKind scheduleKind;

  @override
  ConsumerState<TimetableImportScreen> createState() => _TimetableImportScreenState();
}

class _TimetableImportScreenState extends ConsumerState<TimetableImportScreen> {
  static const _parser = TimetableImportParser();
  static const _csvPrompt =
      'Extract this timetable to a CSV with headers: course, instructor, day, start_time, end_time, room. One row per class. Use full days (e.g., Monday) and 24h times (e.g., 08:30). Leave missing info blank. Output RAW CSV ONLY.';
  final _imagePicker = ImagePicker();
  TimetableImportDraft? _draft;
  String? _sourceName;
  String? _ocrMessage;
  int _ocrAttempts = 0;
  bool _loading = false;

  bool get _supportsOcr =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      _showMessage('Could not read this file. Try another CSV or Excel file.');
      return;
    }
    setState(() {
      _loading = true;
      _ocrMessage = null;
    });
    final draft = _parser.parseFile(name: file.name, bytes: file.bytes!);
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _sourceName = file.name;
      _loading = false;
    });
  }

  Future<void> _pickImage(ImageSource source, {bool newImage = false}) async {
    if (!_supportsOcr) {
      _showMessage('Image scanning is available on Android and iOS.');
      return;
    }
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image == null) return;
      if (newImage) _ocrAttempts = 0;
      setState(() {
        _loading = true;
        _draft = null;
        _ocrMessage = null;
        _sourceName = image.name;
      });
      _ocrAttempts++;
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      late final RecognizedText recognizedText;
      try {
        recognizedText =
            await recognizer.processImage(InputImage.fromFilePath(image.path));
      } finally {
        await recognizer.close();
      }
      final draft = _parser.parseOcr(recognizedText);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _draft = draft.rows.isEmpty ? null : draft;
        _ocrMessage = draft.rows.isEmpty ? _failureMessage : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _ocrMessage = _failureMessage;
      });
    }
  }

  String get _failureMessage => switch (_ocrAttempts) {
        0 || 1 => "We couldn't extract the timetable clearly. Please ensure the photo is well-lit and in focus.",
        2 => "Still having trouble. Please check the image quality or try a different photo.",
        _ => "We couldn't read the text. You may need to crop the image or type the details manually.",
      };

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: _csvPrompt));
    if (mounted) _showMessage('CSV extraction prompt copied.');
  }

  Future<void> _saveCsvTemplate() async {
    const contents =
        'course,instructor,day,start_time,end_time,room\r\nAI,Dr Smith,Monday,08:00,09:30,Lab 04\r\n';
    final bytes = Uint8List.fromList(utf8.encode(contents));
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: 'timetable-template',
          bytes: bytes,
          ext: 'csv',
          mimeType: MimeType.csv,
        );
      } else if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/timetable-template.csv');
        await tempFile.writeAsBytes(bytes);
        await FileSaver.instance.saveAs(
          name: 'timetable-template',
          filePath: tempFile.path,
          ext: 'csv',
          mimeType: MimeType.csv,
        );
      } else {
        await FileSaver.instance.saveFile(
          name: 'timetable-template',
          bytes: bytes,
          ext: 'csv',
          mimeType: MimeType.csv,
        );
      }
      if (mounted) _showMessage('CSV template saved.');
    } catch (_) {
      if (mounted) _showMessage('Could not save the CSV template. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Import ${_scheduleLabel(widget.scheduleKind)} timetable'),
        backgroundColor: AppColors.background,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.action))
          : draft == null
              ? _ImportChoices(
                  supportsOcr: _supportsOcr,
                  failureMessage: _ocrMessage,
                  attempts: _ocrAttempts,
                  onFile: _pickFile,
                  onCamera: () => _pickImage(ImageSource.camera),
                  onGallery: () => _pickImage(ImageSource.gallery),
                  onScanAgain: () => _pickImage(ImageSource.camera),
                  onAnotherImage: () =>
                      _pickImage(ImageSource.gallery, newImage: true),
                  onCopyPrompt: _copyPrompt,
                  onTemplate: _saveCsvTemplate,
                )
              : _TimetableDraftReview(
                  key: ObjectKey(draft),
                  draft: draft,
                  sourceName: _sourceName ?? 'Timetable file',
                  scheduleKind: widget.scheduleKind,
                  onCancel: () => setState(() {
                    _draft = null;
                    _sourceName = null;
                  }),
                  onImport: (rows) async {
                    final timetableNotifier = ref.read(timetableProvider.notifier);
                    setState(() => _loading = true);
                    try {
                      await timetableNotifier.importEntries(
                          rows, widget.scheduleKind);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    } catch (error, st) {
                      if (!mounted) return;
                      setState(() => _loading = false);
                      debugPrint('[ERR-IMP-01] Timetable import failed: $error\n$st');
                      _showMessage("We encountered an issue importing your timetable. Please review the CSV format and try again.");
                    }
                  },
                ),
    );
  }
}

String _scheduleLabel(TimetableKind kind) =>
    kind == TimetableKind.university ? 'University' : 'Personal';

class _ImportChoices extends StatelessWidget {
  const _ImportChoices({
    required this.supportsOcr,
    required this.failureMessage,
    required this.attempts,
    required this.onFile,
    required this.onCamera,
    required this.onGallery,
    required this.onScanAgain,
    required this.onAnotherImage,
    required this.onCopyPrompt,
    required this.onTemplate,
  });

  final bool supportsOcr;
  final String? failureMessage;
  final int attempts;
  final VoidCallback onFile;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onScanAgain;
  final VoidCallback onAnotherImage;
  final VoidCallback onCopyPrompt;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          const Text('Bring your classes in',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          const Text(
              'Choose a timetable file or scan an image. Nothing is saved until you review and confirm it.',
              style: TextStyle(
                  fontSize: 15, height: 1.45, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          _ImportOption(
            icon: Icons.table_chart_outlined,
            title: 'CSV file',
            subtitle: 'A row for each weekday class',
            onTap: onFile,
          ),
          const SizedBox(height: 10),
          _ImportOption(
            icon: Icons.grid_on_outlined,
            title: 'Excel workbook',
            subtitle: 'Import the first worksheet',
            onTap: onFile,
          ),
          if (supportsOcr) ...[
            const SizedBox(height: 20),
            const Text('SCAN A TIMETABLE',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: onCamera,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Use camera'))),
              const SizedBox(width: 10),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: onGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose image'))),
            ]),
          ],
          if (failureMessage != null) ...[
            const SizedBox(height: 24),
            _OcrFailure(
              message: failureMessage!,
              attempts: attempts,
              onScanAgain: onScanAgain,
              onAnotherImage: onAnotherImage,
              onImportFile: onFile,
              onCopyPrompt: onCopyPrompt,
            ),
          ],
          const SizedBox(height: 24),
          _CsvFormatNote(onTemplate: onTemplate),
        ],
      );
}

class _ImportOption extends StatelessWidget {
  const _ImportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: AppColors.action),
          title: Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          subtitle: Text(subtitle,
              style: const TextStyle(color: AppColors.textSecondary)),
          trailing:
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ),
      );
}

class _OcrFailure extends StatelessWidget {
  const _OcrFailure({
    required this.message,
    required this.attempts,
    required this.onScanAgain,
    required this.onAnotherImage,
    required this.onImportFile,
    required this.onCopyPrompt,
  });

  final String message;
  final int attempts;
  final VoidCallback onScanAgain;
  final VoidCallback onAnotherImage;
  final VoidCallback onImportFile;
  final VoidCallback onCopyPrompt;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$attempts of 3 scans used',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 5),
          Text(message,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          if (attempts < 2) ...[
            const SizedBox(height: 12),
            FilledButton(
                onPressed: onScanAgain, child: const Text('Scan again')),
          ] else if (attempts == 2) ...[
            const SizedBox(height: 12),
            FilledButton(
                onPressed: onScanAgain, child: const Text('Scan again')),
            TextButton(
                onPressed: onAnotherImage,
                child: const Text('Choose another image')),
          ] else ...[
            const SizedBox(height: 12),
            TextButton(
                onPressed: onAnotherImage,
                child: const Text('Try another image')),
            FilledButton.tonal(
                onPressed: onImportFile,
                child: const Text('Import CSV / Excel')),
            const SizedBox(height: 8),
            const Text(
                'You can ask an AI assistant to turn the image into Todow CSV. The timetable stays on this device.',
                style: TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
            TextButton.icon(
                onPressed: onCopyPrompt,
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy CSV extraction prompt')),
          ],
        ]),
      );
}

class _CsvFormatNote extends StatelessWidget {
  const _CsvFormatNote({required this.onTemplate});
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTemplate,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download Sample CSV',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'CSV columns: course, instructor, day, start_time, end_time, room. Days can use full or short names; times can use 24-hour or AM/PM format.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.action,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.download_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TimetableDraftReview extends StatefulWidget {
  const _TimetableDraftReview({
    required this.draft,
    required this.sourceName,
    required this.scheduleKind,
    required this.onCancel,
    required this.onImport,
    super.key,
  });

  final TimetableImportDraft draft;
  final String sourceName;
  final TimetableKind scheduleKind;
  final VoidCallback onCancel;
  final ValueChanged<List<TimetableDraftEntry>> onImport;

  @override
  State<_TimetableDraftReview> createState() => _TimetableDraftReviewState();
}

class _TimetableDraftReviewState extends State<_TimetableDraftReview> {
  late final List<_DraftRow> _rows =
      widget.draft.rows.map(_DraftRow.fromEntry).toList();

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _rows.isNotEmpty &&
      _rows.every((row) => row.toEntry.validationError == null);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              children: [
                Text('Review ${_rows.length} classes',
                    style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    '${widget.sourceName} · ${_scheduleName(widget.scheduleKind)} timetable',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                const Text(
                    'Check every course, day, and time before adding it.',
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary)),
                if (widget.draft.errors.isNotEmpty && !_valid) ...[
                  const SizedBox(height: 12),
                  for (final error in widget.draft.errors)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(error,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.alert)),
                    ),
                ],
                const SizedBox(height: 14),
                for (var i = 0; i < _rows.length; i++)
                  _DraftRowCard(
                    row: _rows[i],
                    index: i,
                    onChanged: () => setState(() {}),
                    onDelete: () => setState(() {
                      _rows.removeAt(i).dispose();
                    }),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _rows.add(_DraftRow.empty())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add another class'),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(children: [
                TextButton(
                    onPressed: widget.onCancel, child: const Text('Cancel')),
                const Spacer(),
                FilledButton(
                  onPressed: _valid
                      ? () => widget
                          .onImport(_rows.map((row) => row.toEntry).toList())
                      : null,
                  child: Text('Import ${_rows.length} classes'),
                ),
              ]),
            ),
          ),
        ],
      );
}

String _scheduleName(TimetableKind kind) =>
    kind == TimetableKind.university ? 'University' : 'Personal';

class _DraftRow {
  _DraftRow({
    required this.course,
    required this.instructor,
    required this.room,
    required this.day,
    required this.start,
    required this.end,
  });

  factory _DraftRow.fromEntry(TimetableDraftEntry entry) => _DraftRow(
        course: TextEditingController(text: entry.courseName),
        instructor: TextEditingController(text: entry.instructor),
        room: TextEditingController(text: entry.room),
        day: entry.weekday,
        start: entry.startTime,
        end: entry.endTime,
      );

  factory _DraftRow.empty() => _DraftRow(
        course: TextEditingController(),
        instructor: TextEditingController(),
        room: TextEditingController(),
        day: null,
        start: null,
        end: null,
      );

  final TextEditingController course;
  final TextEditingController instructor;
  final TextEditingController room;
  Weekday? day;
  DateTime? start;
  DateTime? end;

  TimetableDraftEntry get toEntry => TimetableDraftEntry(
        courseName: course.text,
        instructor: instructor.text,
        room: room.text,
        weekday: day,
        startTime: start,
        endTime: end,
      );

  void dispose() {
    course.dispose();
    instructor.dispose();
    room.dispose();
  }
}

class _DraftRowCard extends StatelessWidget {
  const _DraftRowCard({
    required this.row,
    required this.index,
    required this.onChanged,
    required this.onDelete,
  });

  final _DraftRow row;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final value = isStart ? row.start : row.end;
    final initial = value == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay.fromDateTime(value);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final now = DateTime.now();
    final time =
        DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (isStart) {
      row.start = time;
    } else {
      row.end = time;
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final error = row.toEntry.validationError;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: error == null ? AppColors.divider : AppColors.alert)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('CLASS ${index + 1}',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textSecondary))),
          IconButton(
              onPressed: onDelete,
              tooltip: 'Remove class from draft',
              icon: const Icon(Icons.close, size: 19)),
        ]),
        TextField(
          controller: row.course,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(labelText: 'Course'),
        ),
        TextField(
          controller: row.instructor,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(labelText: 'Instructor'),
        ),
        TextField(
          controller: row.room,
          onChanged: (_) => onChanged(),
          decoration: const InputDecoration(labelText: 'Room'),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Weekday>(
          value: row.day,
          decoration: const InputDecoration(labelText: 'Day'),
          items: Weekday.values
              .map((day) =>
                  DropdownMenuItem(value: day, child: Text(day.fullLabel)))
              .toList(),
          onChanged: (value) {
            row.day = value;
            onChanged();
          },
        ),
        Row(children: [
          Expanded(
              child: TextButton(
                  onPressed: () => _pickTime(context, true),
                  child: Text(row.start == null
                      ? 'Start time'
                      : 'Start ${AppDateFormat.time(row.start!)}'))),
          Expanded(
              child: TextButton(
                  onPressed: () => _pickTime(context, false),
                  child: Text(row.end == null
                      ? 'End time'
                      : 'End ${AppDateFormat.time(row.end!)}'))),
        ]),
        if (error != null)
          Text(error,
              style: const TextStyle(fontSize: 12, color: AppColors.alert)),
      ]),
    );
  }
}
