import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/attachment.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/presentation/providers/task_providers.dart';

class AttachmentListWidget extends ConsumerStatefulWidget {
  const AttachmentListWidget({super.key, required this.task});
  final Task task;

  @override
  ConsumerState<AttachmentListWidget> createState() => _AttachmentListWidgetState();
}

class _AttachmentListWidgetState extends ConsumerState<AttachmentListWidget> {
  List<Attachment> _attachments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final atts = await ref.read(taskAttachmentsProvider(widget.task.id).future);
    if (!mounted) return;
    setState(() {
      _attachments = atts;
      _loading = false;
    });
  }

  Future<void> _attach() async {
    final res = await FilePicker.platform.pickFiles();
    if (res == null || res.files.isEmpty) return;
    final file = res.files.first;
    if (file.path == null) return;

    if (!mounted) return;
    final ctrl = ref.read(taskAttachmentsNotifierProvider);
    try {
      await ctrl.attachFile(
        widget.task.id,
        file.path!,
        file.name,
        _guessMime(file.extension),
      );
      await _load();
    } catch (e, st) {
      debugPrint('[ERR-ATT-01] Failed to open attachment: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("We couldn't open this attachment. The file may have been moved or deleted.")),
        );
      }
    }
  }

  String _guessMime(String? ext) {
    if (ext == null) return 'application/octet-stream';
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _iconFor(String filename) {
    final l = filename.toLowerCase();
    if (l.endsWith('.pdf')) return CupertinoIcons.doc_text;
    if (l.endsWith('.jpg') || l.endsWith('.jpeg') || l.endsWith('.png')) {
      return CupertinoIcons.photo;
    }
    return CupertinoIcons.doc;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ATTACHMENTS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            IconButton(
              icon: const Icon(CupertinoIcons.paperclip, size: 20),
              color: AppColors.action,
              onPressed: _attach,
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_attachments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'No attachments yet.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ..._attachments.map((a) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.action.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _iconFor(a.filename),
                      color: AppColors.action,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _fmtSize(a.sizeBytes),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Sync seam placeholder
                            const Icon(
                              CupertinoIcons.cloud_upload,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.trash, size: 20),
                    color: AppColors.alert,
                    onPressed: () async {
                      final ctrl = ref.read(taskAttachmentsNotifierProvider);
                      await ctrl.removeAttachment(a.id);
                      await _load();
                    },
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.eye, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () async {
                      final ctrl = ref.read(taskAttachmentsNotifierProvider);
                      await ctrl.openAttachment(a);
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
