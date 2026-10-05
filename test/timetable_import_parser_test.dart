import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:todow/data/timetable_import_parser.dart';
import 'package:todow/domain/models/enums.dart';

void main() {
  group('TimetableImportParser OCR Spatial Reconstruction', () {
    const parser = TimetableImportParser();

    RecognizedText buildMockRecognizedText(List<(String, Rect)> textBlocks) {
      final blocks = <TextBlock>[];
      for (final tb in textBlocks) {
        final text = tb.$1;
        final rect = tb.$2;
        blocks.add(
          TextBlock(
            text: text,
            lines: [
              TextLine(
                text: text,
                elements: [
                  TextElement(
                    text: text,
                    boundingBox: rect,
                    cornerPoints: [],
                    recognizedLanguages: ['en'],
                    symbols: [],
                    angle: 0.0,
                    confidence: 1.0,
                  ),
                ],
                boundingBox: rect,
                cornerPoints: [],
                recognizedLanguages: ['en'],
                confidence: 1.0,
                angle: 0.0,
              ),
            ],
            boundingBox: rect,
            cornerPoints: [],
            recognizedLanguages: ['en'],
          ),
        );
      }
      return RecognizedText(text: textBlocks.map((e) => e.$1).join('\n'), blocks: blocks);
    }

    test('reconstructs a standard grid timetable (Days as columns, Times as rows)', () {
      final recognizedText = buildMockRecognizedText([
        // Column headers (Days)
        ('Monday', Rect.fromLTRB(100, 10, 200, 40)),
        ('Tuesday', Rect.fromLTRB(250, 10, 350, 40)),
        
        // Row headers (Times)
        ('08:00 - 09:30', Rect.fromLTRB(10, 50, 90, 80)),
        ('10:00 - 11:30', Rect.fromLTRB(10, 100, 90, 130)),

        // Classes (Intersections)
        ('CS101 Dr. Smith Room 4A', Rect.fromLTRB(100, 50, 200, 80)), // Monday 08:00
        ('MATH200 Prof. Jones', Rect.fromLTRB(250, 100, 350, 130)),   // Tuesday 10:00
      ]);

      final draft = parser.parseOcr(recognizedText);

      expect(draft.errors, isEmpty);
      expect(draft.rows, hasLength(2));

      final monClass = draft.rows.firstWhere((r) => r.weekday == Weekday.monday);
      expect(monClass.courseName, 'CS101');
      expect(monClass.instructor, 'Dr. Smith');
      expect(monClass.room, 'Room 4A');
      expect(monClass.startTime, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0));
      expect(monClass.endTime, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 9, 30));

      final tueClass = draft.rows.firstWhere((r) => r.weekday == Weekday.tuesday);
      expect(tueClass.courseName, 'MATH200');
      expect(tueClass.instructor, 'Prof. Jones');
      expect(tueClass.startTime, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 10, 0));
    });
    
    test('linear fallback when grid is not found', () {
      final recognizedText = buildMockRecognizedText([
        ('Monday 14:00 - 15:30 Physics 101 Lab 3', Rect.fromLTRB(10, 10, 300, 30)),
      ]);

      final draft = parser.parseOcr(recognizedText);

      expect(draft.errors, isEmpty);
      expect(draft.rows, hasLength(1));
      final entry = draft.rows.first;
      expect(entry.weekday, Weekday.monday);
      expect(entry.courseName, 'Physics 101');
      expect(entry.room, 'Lab 3');
      expect(entry.startTime, DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 14, 0));
    });
  });
}
