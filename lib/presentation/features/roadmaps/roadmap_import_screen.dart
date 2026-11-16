import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/presentation/shared/beautiful_back_button.dart';
import 'package:todow/domain/models/roadmap_import.dart';
import 'package:todow/presentation/features/roadmaps/roadmap_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/features/tasks/task_providers.dart';
import 'package:todow/presentation/features/roadmaps/roadmap_detail_screen.dart';

const _csvHeaders = [
  'roadmap_title',
  'roadmap_description',
  'topic_title',
  'topic_description',
  'topic_order',
  'topic_status',
  'task_title',
  'task_description',
  'due_date',
  'due_time',
  'priority',
  'task_status',
  'reminder',
];

class RoadmapImportScreen extends ConsumerStatefulWidget {
  const RoadmapImportScreen({super.key});

  @override
  ConsumerState<RoadmapImportScreen> createState() => _RoadmapImportScreenState();
}

class _RoadmapImportScreenState extends ConsumerState<RoadmapImportScreen> {
  RoadmapImportDraft? _draft;
  bool _loading = false;
  String? _fileName;

  Future<void> _downloadCsvTemplate() async {
    final rows = [
      _csvHeaders,
      [
        'Sample Roadmap',
        'A sample plan you can replace with your own.',
        'Python foundations',
        'Start with the core concepts.',
        '1',
        'active',
        'Set up your Python environment',
        '',
        '',
        '',
        'medium',
        'active',
        'none',
      ],
      [
        'Sample Roadmap',
        'A sample plan you can replace with your own.',
        'Python foundations',
        'Start with the core concepts.',
        '1',
        'active',
        'Practice variables and types',
        '',
        '',
        '',
        'none',
        'active',
        'none',
      ],
      [
        'Sample Roadmap',
        'A sample plan you can replace with your own.',
        'Build a small project',
        '',
        '2',
        'pending',
        'Create a command-line app',
        '',
        '',
        '',
        'low',
        'active',
        'none',
      ],
    ];
    final bytes = Uint8List.fromList(utf8.encode(
      rows.map((row) => row.map(_csvCell).join(',')).join('\r\n'),
    ));

    setState(() => _loading = true);
    try {
      final saved = kIsWeb
          ? await FileSaver.instance.saveFile(
              name: 'roadmap-template',
              bytes: bytes,
              ext: 'csv',
              mimeType: MimeType.csv,
            )
          : (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)
              ? await () async {
                  final tempDir = await getTemporaryDirectory();
                  final tempFile = File('${tempDir.path}/roadmap-template.csv');
                  await tempFile.writeAsBytes(bytes);
                  return await FileSaver.instance.saveAs(
                    name: 'roadmap-template',
                    filePath: tempFile.path,
                    ext: 'csv',
                    mimeType: MimeType.csv,
                  );
                }()
              : await FileSaver.instance.saveFile(
                  name: 'roadmap-template',
                  bytes: bytes,
                  ext: 'csv',
                  mimeType: MimeType.csv,
                );
      if (!mounted || saved == null) return;
      _showTemplateMessage('CSV template downloaded.');
    } catch (_) {
      if (!mounted) return;
      _showTemplateMessage(
        'Couldn’t download the template. Try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showTemplateMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        elevation: 0,
        backgroundColor: isError ? AppColors.alert : AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _chooseFile([String? extension]) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extension == null ? ['csv', 'xlsx'] : [extension],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file?.bytes == null) {
      return;
    }
    setState(() => _loading = true);
    final draft = _RoadmapImportParser.parse(file!);
    if (mounted) {
      setState(() {
        _draft = draft;
        _fileName = file.name;
        _loading = false;
      });
    }
  }

  Future<void> _import() async {
    final draft = _draft;
    if (draft == null || !draft.isValid) return;
    setState(() => _loading = true);
    final roadmapController = ref.read(roadmapsProvider.notifier);
    final roadmap = await roadmapController.importDraft(draft);
    ref.invalidate(tasksProvider);
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => RoadmapDetailScreen(roadmap: roadmap)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leadingWidth: 104,
          leading: const Center(child: BeautifulBackButton()),
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          title: const Text('Import Roadmap',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  const Text(
                    'Choose a file',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Import a plan from a CSV or Excel file.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ImportFormatPanel(
                    fileName: _fileName,
                    enabled: !_loading,
                    onCsv: () => _chooseFile('csv'),
                    onExcel: () => _chooseFile('xlsx'),
                    onChange: () => _chooseFile(),
                  ),
                  const SizedBox(height: 14),
                  const SizedBox(height: 12),
                  Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: _loading ? null : _downloadCsvTemplate,
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
                                  SizedBox(height: 3),
                                  Text(
                                    'Download editable CSV file to get started with your roadmap.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.action,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: _loading
                                  ? const Padding(
                                      padding: EdgeInsets.all(11),
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.download_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 20),
                    const LinearProgressIndicator(color: AppColors.action),
                  ],
                  if (_draft != null) _ImportPreview(draft: _draft!),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _draft?.isValid ?? false
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _import,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.action,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Import Roadmap'),
                  ),
                ),
              )
            : null,
      );
}

class _ImportFormatPanel extends StatelessWidget {
  const _ImportFormatPanel({
    required this.fileName,
    required this.enabled,
    required this.onCsv,
    required this.onExcel,
    required this.onChange,
  });

  final String? fileName;
  final bool enabled;
  final VoidCallback onCsv;
  final VoidCallback onExcel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: fileName == null
            ? Column(
                children: [
                  _ImportFormatOption(
                    title: 'CSV',
                    subtitle: 'Comma-separated values',
                    enabled: enabled,
                    onTap: onCsv,
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  _ImportFormatOption(
                    title: 'Excel',
                    subtitle: 'Excel workbook (.xlsx)',
                    enabled: enabled,
                    onTap: onExcel,
                  ),
                ],
              )
            : _ImportFormatOption(
                title: fileName!,
                subtitle: 'Selected file',
                enabled: enabled,
                trailing: const Text(
                  'Change',
                  style: TextStyle(
                    color: AppColors.action,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: onChange,
              ),
      );
}

class _ImportFormatOption extends StatelessWidget {
  const _ImportFormatOption({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.action.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.upload_file_rounded,
                    color: AppColors.action,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
              ],
            ),
          ),
        ),
      );
}

class _ImportPreview extends StatelessWidget {
  const _ImportPreview({required this.draft});
  final RoadmapImportDraft draft;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(draft.isValid ? draft.title : 'Fix import errors',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Text('${draft.topicCount} Topics · ${draft.rows.length} Tasks',
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              if (draft.errors.isEmpty)
                const Text('Ready to import',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.action))
              else
                for (final error in draft.errors)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error,
                          style: const TextStyle(color: AppColors.alert))),
            ],
          ),
        ),
      );
}

class _RoadmapImportParser {
  static const _requiredHeaders = [
    'roadmap_title',
    'topic_title',
    'topic_order',
    'task_title',
  ];

  static RoadmapImportDraft parse(PlatformFile file) {
    try {
      final rows = file.extension?.toLowerCase() == 'xlsx'
          ? _xlsxRows(file.bytes!)
          : _csvRows(utf8.decode(file.bytes!));
      return _normalize(rows);
    } catch (_) {
      return const RoadmapImportDraft(rows: [], errors: [
        'Could not read this file. Use the Roadmap CSV or Excel template.'
      ]);
    }
  }

  static RoadmapImportDraft _normalize(List<List<String>> source) {
    if (source.isEmpty) {
      return const RoadmapImportDraft(rows: [], errors: ['The file is empty.']);
    }
    final columns = {
      for (var i = 0; i < source.first.length; i++)
        source.first[i].trim().toLowerCase(): i
    };
    final missing = _requiredHeaders
        .where((header) => !columns.containsKey(header))
        .toList();
    if (missing.isNotEmpty) {
      for (var i = 0; i < _requiredHeaders.length; i++) {
        columns[_requiredHeaders[i]] = i;
      }
      missing.clear();
    }
    String value(List<String> row, String header) {
      final index = columns[header];
      return index == null || index >= row.length ? '' : row[index].trim();
    }

    final errors = <String>[];
    final rows = <RoadmapImportRow>[];
    String? title;
    for (var i = 1; i < source.length; i++) {
      final row = source[i];
      if (row.every((value) => value.trim().isEmpty)) continue;
      final roadmapTitle = value(row, 'roadmap_title');
      final topicTitle = value(row, 'topic_title');
      final taskTitle = value(row, 'task_title');
      final topicOrder = int.tryParse(value(row, 'topic_order'));
      final topicStatus = value(row, 'topic_status').toLowerCase();
      final priority = value(row, 'priority').toLowerCase();
      var taskStatus = value(row, 'task_status').toLowerCase();
      final dueDate = value(row, 'due_date');
      final dueTime = value(row, 'due_time');
      final reminder = value(row, 'reminder').toLowerCase();
      final line = i + 1;
      if (roadmapTitle.isEmpty) {
        errors.add('Row $line: Roadmap title is required.');
      }
      if (topicTitle.isEmpty) errors.add('Row $line: Topic title is required.');
      if (taskTitle.isEmpty) errors.add('Row $line: Task title is required.');
      if (topicOrder == null || topicOrder < 1) {
        errors.add('Row $line: Topic order must be a positive number.');
      }
      if (!{'pending', 'active', 'completed'}
          .contains(topicStatus.isEmpty ? 'pending' : topicStatus)) {
        errors.add('Row $line: Invalid Topic status.');
      }
      if (!{'none', 'low', 'medium', 'high', 'critical'}
          .contains(priority.isEmpty ? 'none' : priority)) {
        errors.add('Row $line: Invalid priority.');
      }
      if (taskStatus == 'pending') taskStatus = 'active';
      if (taskStatus.isEmpty) taskStatus = 'active';
      if (!{'inbox', 'active', 'completed', 'archived'}.contains(taskStatus)) {
        errors.add('Row $line: Invalid task status.');
      }
      if (dueDate.isNotEmpty && DateTime.tryParse(dueDate) == null) {
        errors.add('Row $line: Invalid date.');
      }
      if (dueTime.isNotEmpty &&
          !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(dueTime)) {
        errors.add('Row $line: Invalid time.');
      }
      if (!{'none', 'normal', 'assignment', 'critical'}
          .contains(reminder.isEmpty ? 'none' : reminder)) {
        errors.add('Row $line: Invalid reminder.');
      }
      title ??= roadmapTitle;
      if (roadmapTitle.isNotEmpty && title != roadmapTitle) {
        errors.add('Row $line: Only one Roadmap can be imported at a time.');
      }
      if (topicOrder != null) {
        rows.add(RoadmapImportRow(
            roadmapTitle: roadmapTitle,
            roadmapDescription: value(row, 'roadmap_description'),
            topicTitle: topicTitle,
            topicDescription: value(row, 'topic_description'),
            topicOrder: topicOrder,
            topicStatus: topicStatus.isEmpty ? 'pending' : topicStatus,
            taskTitle: taskTitle,
            taskDescription: value(row, 'task_description'),
            dueDate: dueDate,
            dueTime: dueTime,
            priority: priority.isEmpty ? 'none' : priority,
            taskStatus: taskStatus,
            reminder: reminder.isEmpty ? 'none' : reminder));
      }
    }
    return RoadmapImportDraft(rows: rows, errors: errors);
  }

  static List<List<String>> _csvRows(String input) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        if (quoted && i + 1 < input.length && input[i + 1] == '"') {
          field.write(char);
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (char == ',' && !quoted) {
        row.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !quoted) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        rows.add(List.of(row));
        row.clear();
      } else {
        field.write(char);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }

  static List<List<String>> _xlsxRows(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String text(String name) =>
        utf8.decode(archive.findFile(name)!.content as List<int>);
    final shared = archive.findFile('xl/sharedStrings.xml') == null
        ? <String>[]
        : RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
            .allMatches(text('xl/sharedStrings.xml'))
            .map((match) => _decode(match.group(1)!))
            .toList();
    final sheet = archive.files.firstWhere((file) =>
        file.name.startsWith('xl/worksheets/') && file.name.endsWith('.xml'));
    final rows = <List<String>>[];
    for (final row in RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true)
        .allMatches(utf8.decode(sheet.content as List<int>))) {
      final values = <int, String>{};
      for (final cell
          in RegExp(r'<c[^>]*r="([A-Z]+)\d+"[^>]*>(.*?)</c>', dotAll: true)
              .allMatches(row.group(1)!)) {
        final column = _column(cell.group(1)!);
        final xml = cell.group(2)!;
        final value =
            RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(xml)?.group(1) ??
                RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
                    .firstMatch(xml)
                    ?.group(1) ??
                '';
        values[column] = xml.contains('t="s"') && int.tryParse(value) != null
            ? shared[int.parse(value)]
            : _decode(value);
      }
      rows.add([
        for (var i = 0;
            i <=
                (values.keys.isEmpty
                    ? 0
                    : values.keys.reduce((a, b) => a > b ? a : b));
            i++)
          values[i] ?? ''
      ]);
    }
    return rows;
  }

  static int _column(String letters) {
    var value = 0;
    for (final code in letters.codeUnits) {
      value = value * 26 + code - 64;
    }
    return value - 1;
  }

  static String _decode(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"');
}

String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';
