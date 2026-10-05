import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:todow/domain/models/task.dart';
import 'package:todow/domain/models/attachment.dart';
import 'package:todow/domain/attachment_limits.dart';
import 'package:todow/presentation/providers/task_providers.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'attachment_row.dart';

class AttachmentsSection extends ConsumerStatefulWidget {
  final Task? task;
  final Future<Task> Function()? onAutoSave;

  const AttachmentsSection({super.key, this.task, this.onAutoSave});

  @override
  ConsumerState<AttachmentsSection> createState() => _AttachmentsSectionState();
}

class _AttachmentsSectionState extends ConsumerState<AttachmentsSection> {
  List<Attachment> _attachments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttachments();
  }

  @override
  void didUpdateWidget(AttachmentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task?.id != oldWidget.task?.id) {
      _loadAttachments();
    }
  }

  Future<void> _loadAttachments([String? explicitTaskId]) async {
    final tId = explicitTaskId ?? widget.task?.id;
    if (tId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final attachments = await ref.read(taskAttachmentsProvider(tId).future);
    if (mounted) {
      setState(() {
        _attachments = attachments;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickFile() async {
    
    final allowedExts = kAllowedExtensions.map((e) => e.substring(1)).toList();
    
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExts,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Web attachments are not supported in local-only mode.')));
      }
      return;
    }

    if (!mounted) return;
    final controller = ref.read(taskAttachmentsNotifierProvider);
    
    try {
      final sizeBytes = await File(file.path!).length();
      validateAttachment(file.name, sizeBytes);
      
      final taskToAttach = widget.task ?? await widget.onAutoSave?.call();
      if (taskToAttach == null) return;

      final ext = file.extension?.toLowerCase() ?? '';
      final mimeType = ext == 'pdf' ? 'application/pdf' : 
          ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'].contains(ext) ? 'image/$ext' : 'application/octet-stream';

      await controller.attachFile(taskToAttach.id, file.path!, file.name, mimeType);
      _loadAttachments(taskToAttach.id);
    } on FileTooLargeException catch (e, st) {
      debugPrint('[ERR-ATT-02] File too large: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This file is too large. Please select a file smaller than the limit.")));
      }
    } on UnsupportedFileTypeException catch (e, st) {
      debugPrint('[ERR-ATT-03] Unsupported file type: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This file type isn't supported. Please use a supported format like PDF, PNG, or JPG.")));
      }
    } catch (e, st) {
      debugPrint('[ERR-ATT-04] Failed to attach file: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("We couldn't attach this file. Please ensure it isn't corrupted and try again.")));
      }
    }
  }
  
  Future<void> _openFile(Attachment attachment) async {
    final controller = ref.read(taskAttachmentsNotifierProvider);
    await controller.openAttachment(attachment);
  }
  
  Future<void> _removeAttachment(Attachment attachment) async {
    final controller = ref.read(taskAttachmentsNotifierProvider);
    await controller.removeAttachment(attachment.id);
    _loadAttachments();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task == null && widget.onAutoSave == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ATTACHMENTS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            TextButton(
              onPressed: _pickFile,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              ),
              child: const Text('+ Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.5), width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: _isLoading 
            ? const SizedBox(
                height: 60, 
                child: Center(child: CircularProgressIndicator(strokeWidth: 2))
              )
            : _attachments.isEmpty
              ? const SizedBox(
                  height: 60,
                  child: Center(
                    child: Text(
                      'No attachments',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _attachments.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1, 
                    thickness: 1, 
                    color: AppColors.divider, 
                    indent: 0, 
                    endIndent: 0
                  ),
                  itemBuilder: (context, index) {
                    final att = _attachments[index];
                    return Slidable(
                      key: ValueKey(att.id),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        extentRatio: 0.2,
                        children: [
                          SlidableAction(
                            onPressed: (_) => _removeAttachment(att),
                            backgroundColor: AppColors.alert,
                            foregroundColor: Colors.white,
                            icon: Icons.delete_outline_rounded,
                          ),
                        ],
                      ),
                      child: AttachmentRow(
                        attachment: att,
                        onTap: () => _openFile(att),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
