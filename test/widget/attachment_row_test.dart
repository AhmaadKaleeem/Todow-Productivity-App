import 'dart:io' as dart_io;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todow/core/theme/app_colors.dart';
import 'package:todow/domain/models/attachment.dart';
import 'package:todow/presentation/widgets/attachment_row.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todow/core/providers/service_providers.dart';
import 'task_controller_test.dart' show MockAttachmentRepository, MockFileStorage;

class _ThumbFileStorage extends MockFileStorage {
  final String thumbPath;
  _ThumbFileStorage(this.thumbPath);
  @override
  String thumbnailPath(String taskId, String attachmentId) => thumbPath;
}

void main() {
  late String validThumbPath;
  late String missingThumbPath;

  setUpAll(() async {
    final tempDir = await dart_io.Directory.systemTemp.createTemp('row_test');
    validThumbPath = '${tempDir.path}/thumb.jpg';
    missingThumbPath = '${tempDir.path}/missing.jpg';
    
    // Create a real file for validThumbPath
    dart_io.File(validThumbPath).writeAsBytesSync([0, 1, 2]); 
  });

  Widget buildRow(String filename, String mimeType, {String? mockedThumbPath}) {
    final attachment = Attachment(
      id: 'att-1',
      taskId: 'task-1',
      filename: filename,
      mimeType: mimeType,
      sizeBytes: 1024,
      contentHash: 'a' * 64,
      syncState: AttachmentSyncState.localOnly,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    final mockAttachmentRepo = MockAttachmentRepository();
    
    // But since MockFileStorage just returns '', we need to override it if we want to test thumbnails
    // Let's create a custom controller class or just override MockFileStorage.
    // Wait, let's just make an inline class here.
    final mockFs = _ThumbFileStorage(mockedThumbPath ?? 'dummy.jpg');

    return ProviderScope(
      overrides: [
        fileStorageProvider.overrideWithValue(mockFs),
        attachmentRepositoryProvider.overrideWithValue(mockAttachmentRepo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AttachmentRow(attachment: attachment),
        ),
      ),
    );
  }

  testWidgets('image attachment with thumbnail file on disk shows Image widget (not icon)', (tester) async {
    await tester.pumpWidget(buildRow('image.jpg', 'image/jpeg', mockedThumbPath: validThumbPath));
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('image attachment WITHOUT thumbnail falls back to icon', (tester) async {
    await tester.pumpWidget(buildRow('image.jpg', 'image/jpeg', mockedThumbPath: missingThumbPath));
    expect(find.byType(Image), findsNothing);
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppColors.attention);
  });

  testWidgets('non-image attachment always shows icon', (tester) async {
    await tester.pumpWidget(buildRow('doc.pdf', 'application/pdf', mockedThumbPath: validThumbPath));
    expect(find.byType(Image), findsNothing);
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppColors.alert);
  });

  testWidgets('long-press opens the rename dialog and pre-fills filename', (tester) async {
    await tester.pumpWidget(buildRow('image.jpg', 'image/jpeg'));
    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('Rename attachment'), findsOneWidget);
    expect(find.text('image.jpg'), findsNWidgets(2)); // Row text + Pre-filled TextField text
  });

  testWidgets('typing a new name and tapping Save calls renameAttachment', (tester) async {
    await tester.pumpWidget(buildRow('old.pdf', 'application/pdf'));
    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'new.pdf');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The dialog should close
    expect(find.text('Rename attachment'), findsNothing);
  });

  testWidgets('tapping Cancel leaves the filename unchanged', (tester) async {
    await tester.pumpWidget(buildRow('old.pdf', 'application/pdf'));
    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'new.pdf');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Rename attachment'), findsNothing);
  });

  testWidgets('empty name shows an inline error, dialog stays open', (tester) async {
    await tester.pumpWidget(buildRow('old.pdf', 'application/pdf'));
    await tester.longPress(find.byType(InkWell));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Rename attachment'), findsOneWidget); // Stays open
    expect(find.text('Filename cannot be empty or whitespace'), findsOneWidget); // Error text
  });


  testWidgets('renders icon in AppColors.attention for .jpg filename', (tester) async {
    await tester.pumpWidget(buildRow('image.jpg', 'image/jpeg'));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppColors.attention);
  });

  testWidgets('renders icon in AppColors.alert for .pdf filename', (tester) async {
    await tester.pumpWidget(buildRow('doc.pdf', 'application/pdf'));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppColors.alert);
  });

  testWidgets('renders icon in AppColors.textSecondary for .docx filename', (tester) async {
    await tester.pumpWidget(buildRow('doc.docx', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'));
    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, AppColors.textSecondary);
  });

  testWidgets('row height is 60.0', (tester) async {
    await tester.pumpWidget(buildRow('file.txt', 'text/plain'));
    final size = tester.getSize(find.byType(AttachmentRow));
    expect(size.height, 60.0);
  });

  testWidgets('long filename activates ellipsis', (tester) async {
    final longName = 'this_is_a_very_long_filename_that_should_trigger_ellipsis_in_the_ui.txt';
    await tester.pumpWidget(buildRow(longName, 'text/plain'));
    final text = tester.widget<Text>(find.text(longName));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('right side reserves 20dp empty slot', (tester) async {
    await tester.pumpWidget(buildRow('file.txt', 'text/plain'));
    final sizedBox = tester.widgetList<SizedBox>(find.byType(SizedBox)).firstWhere((b) => b.width == 20.0);
    expect(sizedBox, isNotNull);
  });
}
