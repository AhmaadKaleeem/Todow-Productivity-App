import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/presentation/features/tasks/task_providers.dart';
import 'package:todow/core/providers/service_providers.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/attachment.dart';

class AttachmentRow extends ConsumerWidget {
  final Attachment attachment;
  final VoidCallback? onTap;

  const AttachmentRow({
    super.key,
    required this.attachment,
    this.onTap,
  });

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Color _getIconColor(String mimeType) {
    if (mimeType.startsWith('image/')) return AppColors.attention;
    if (mimeType == 'application/pdf') return AppColors.alert;
    return AppColors.textSecondary;
  }

  IconData _getIconData(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Future<void> _showRenameDialog(BuildContext context, TaskAttachmentsNotifier controller) async {
    final textController = TextEditingController(text: attachment.filename);
    textController.selection = TextSelection(baseOffset: 0, extentOffset: textController.text.length);
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Rename attachment'),
              content: Semantics(
                label: 'Attachment name',
                child: TextField(
                  controller: textController,
                  autofocus: true,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: 'New name',
                    errorText: errorText,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await controller.renameAttachment(attachment.id, textController.text);
                      if (context.mounted) Navigator.of(context).pop();
                    } on ArgumentError catch (e) {
                      setState(() {
                        errorText = e.message.toString();
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(taskAttachmentsNotifierProvider);
    final fileStorage = ref.read(fileStorageProvider);
    final isImage = attachment.mimeType.startsWith('image/');
    final thumbPath = isImage ? fileStorage.thumbnailPath(attachment.taskId, attachment.id) : null;
    final hasThumb = thumbPath != null && File(thumbPath).existsSync();

    return Semantics(
      label: 'Attachment, ${attachment.filename}, ${_formatSize(attachment.sizeBytes)}. Long-press to rename.',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showRenameDialog(context, controller),
          child: Container(
            height: 60.0,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                if (hasThumb)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(thumbPath),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        _getIconData(attachment.mimeType),
                        size: 24.0,
                        color: _getIconColor(attachment.mimeType),
                      ),
                    ),
                  )
                else
                  Icon(
                    _getIconData(attachment.mimeType),
                    size: 24.0,
                    color: _getIconColor(attachment.mimeType),
                  ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        attachment.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _formatSize(attachment.sizeBytes),
                        style: const TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20.0), // Reserved for future sync badge
              ],
            ),
          ),
        ),
      ),
    );
  }
}
