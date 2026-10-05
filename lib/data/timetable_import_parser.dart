import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:todow/domain/models/enums.dart';
import 'package:todow/domain/models/timetable_import.dart';
import 'package:xml/xml.dart';

class TimetableImportParser {
  const TimetableImportParser();

  TimetableImportDraft parseFile({
    required String name,
    required Uint8List bytes,
  }) {
    try {
      final rows = name.toLowerCase().endsWith('.xlsx')
          ? _excelRows(bytes)
          : _csvRows(utf8.decode(bytes, allowMalformed: true));
      return _draftRows(rows);
    } catch (_) {
      return const TimetableImportDraft(
        rows: [],
        errors: [
          'This file could not be read. Check the template and try again.'
        ],
      );
    }
  }

  TimetableImportDraft parseOcr(RecognizedText recognizedText) {
    final rows = <TimetableDraftEntry>[];
    
    // 1. Gather all text elements with their bounding boxes
    final elements = <TextElement>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        elements.addAll(line.elements);
      }
    }

    if (elements.isEmpty) {
      return const TimetableImportDraft(
          rows: [], errors: ['No text was recognized in the image.']);
    }

    // 2. Identify structural landmarks (Days and Times)
    final dayPattern = RegExp(
      r'^\s*(mo(?:n(?:day)?)?|tu(?:e(?:sday)?)?|we(?:d(?:nesday)?)?|th(?:u(?:rsday)?)?|fr(?:i(?:day)?)?|sa(?:t(?:urday)?)?|su(?:n(?:day)?)?)\b',
      caseSensitive: false,
    );
    final timePattern = RegExp(
      r'^(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)$',
      caseSensitive: false,
    );

    final dayHeaders = <Rect, Weekday>{};
    final timeNodes = <Rect, DateTime>{};
    final contentElements = <TextElement>[];

    for (final el in elements) {
      final text = el.text.trim();
      
      final dayMatch = dayPattern.firstMatch(text);
      if (dayMatch != null && text.length < 15) {
        final day = _parseDay(dayMatch.group(1)!);
        if (day != null) {
          dayHeaders[el.boundingBox] = day;
          continue;
        }
      }

      final timeMatch = timePattern.firstMatch(text);
      if (timeMatch != null) {
        final time = _parseTime(text);
        if (time != null) {
          timeNodes[el.boundingBox] = time;
          continue;
        }
      }

      // If it looks like a time range combined (08:00-09:30)
      final timeRangeMatch = RegExp(
        r'(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\s*(?:-|–|—|to)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)',
        caseSensitive: false,
      ).firstMatch(text);
      
      if (timeRangeMatch != null) {
        final start = _parseTime(timeRangeMatch.group(1)!);
        var end = _parseTime(timeRangeMatch.group(2)!);
        if (start != null && end != null) {
           timeNodes[el.boundingBox] = start;
           // We approximate end time location slightly to the right to avoid overwriting map key
           timeNodes[el.boundingBox.translate(1, 0)] = end;
           if (text.length < timeRangeMatch.group(0)!.length + 5) {
             continue;
           }
        }
      }

      contentElements.add(el);
    }

    // 3. Reconstruct via spatial alignment
    // Use relative vertical overlap instead of hardcoded pixels
    bool overlapsY(Rect a, Rect b) {
      final aCenter = a.center.dy;
      return aCenter >= b.top && aCenter <= b.bottom;
    }

    // Group remaining content into logical lines by Y-overlap
    contentElements.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    final logicalLines = <List<TextElement>>[];
    
    for (final el in contentElements) {
      bool added = false;
      for (final line in logicalLines) {
        // Find average Y center of line
        final lineRects = line.map((e) => e.boundingBox);
        final avgTop = lineRects.map((r) => r.top).reduce((a, b) => a + b) / line.length;
        final avgBottom = lineRects.map((r) => r.bottom).reduce((a, b) => a + b) / line.length;
        final lineBounds = Rect.fromLTRB(0, avgTop, 0, avgBottom);
        
        if (overlapsY(el.boundingBox, lineBounds)) {
          line.add(el);
          added = true;
          break;
        }
      }
      if (!added) logicalLines.add([el]);
    }

    // For each logical line, build a text string and associate with nearest Day/Time
    for (final line in logicalLines) {
      line.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final text = line.map((e) => e.text).join(' ').trim();
      if (text.isEmpty) continue;
      
      final lineBounds = line.map((e) => e.boundingBox).reduce((a, b) => a.expandToInclude(b));

      // Find overlapping Day (Column)
      Weekday? assignedDay;
      if (dayHeaders.isNotEmpty) {
        assignedDay = dayHeaders.entries.fold<MapEntry<Rect, Weekday>?>(null, (closest, entry) {
          // Find day header whose X range aligns best with this line
          if (closest == null) return entry;
          final d1 = (entry.key.center.dx - lineBounds.center.dx).abs();
          final d2 = (closest.key.center.dx - lineBounds.center.dx).abs();
          return d1 < d2 ? entry : closest;
        })?.value;
      }

      // Find nearby Times (Rows)
      DateTime? startTime;
      DateTime? endTime;
      
      if (timeNodes.isNotEmpty) {
        // Get times roughly on the same Y axis
        final rowTimes = timeNodes.entries
            .where((e) => (e.key.center.dy - lineBounds.center.dy).abs() < lineBounds.height)
            .map((e) => e.value)
            .toList()
          ..sort();
        
        if (rowTimes.isNotEmpty) {
          startTime = rowTimes.first;
          endTime = rowTimes.length > 1 ? rowTimes.last : startTime.add(const Duration(hours: 1));
        }
      }

      var details = text;

      final timeRangeMatch = RegExp(
        r'(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\s*(?:-|–|—|to)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)',
        caseSensitive: false,
      ).firstMatch(details);

      if (timeRangeMatch != null) {
        if (startTime == null) {
          startTime = _parseTime(timeRangeMatch.group(1)!);
          endTime = _parseTime(timeRangeMatch.group(2)!);
        }
        details = details.replaceRange(timeRangeMatch.start, timeRangeMatch.end, ' ').trim();
      }

      if (assignedDay == null) {
        final inlineDay = dayPattern.firstMatch(details);
        if (inlineDay != null) {
          assignedDay = _parseDay(inlineDay.group(1)!);
        }
      }

      // Remove inline day names if they got mixed in
      details = details.replaceAll(dayPattern, ' ').trim();
      
      // Room extraction FIRST to prevent instructor regex from eating 'Room'
      String room = '';
      final roomMatch = RegExp(
        r'\b(?:room|lab|venue|c)\s*[#:.\-]?\s*\d+[a-zA-Z0-9 \-]*\b',
        caseSensitive: false,
      ).firstMatch(details);
      
      if (roomMatch != null) {
        room = roomMatch.group(0)!.trim();
        details = details.replaceRange(roomMatch.start, roomMatch.end, ' ');
      }
      
      // Instructor extraction
      String instructor = '';
      final instructorMatch = RegExp(
        r'\b(?:instructor|teacher|prof\.?|dr\.?|mr\.?|ms\.?|mrs\.?)\s*[:\-]?\s*[a-zA-Z]+(?:\s+[a-zA-Z]+)*',
        caseSensitive: false,
      ).firstMatch(details);
      
      if (instructorMatch != null) {
        instructor = instructorMatch.group(0)!.trim();
        details = details.replaceRange(instructorMatch.start, instructorMatch.end, ' ');
      }
      
      // Clean up course name
      final course = details
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'^[\s:|,.-]+|[\s:|,.-]+$'), '')
          .trim();

      // Ensure sensible end time
      if (startTime != null && endTime != null && !endTime.isAfter(startTime)) {
        endTime = endTime.add(const Duration(hours: 12));
      }

      // Don't add garbage tiny lines, only actual course records or warnings
      if (course.isNotEmpty && course.length > 2) {
        rows.add(TimetableDraftEntry(
          courseName: course,
          instructor: instructor,
          room: room,
          weekday: assignedDay,
          startTime: startTime,
          endTime: endTime,
        ));
      }
    }

    return TimetableImportDraft(
      rows: rows,
      errors: rows.isEmpty
          ? const ['No class rows were recognized in this image.']
          : const [],
    );
  }

  TimetableImportDraft _draftRows(List<List<String>> source) {
    if (source.isEmpty) {
      return const TimetableImportDraft(
          rows: [], errors: ['The file has no class rows.']);
    }
    final headers = {
      for (var i = 0; i < source.first.length; i++)
        _normalizeHeader(source.first[i]): i,
    };
    int? courseColumn = _column(headers, ['course', 'course_name', 'class']);
    int? dayColumn = _column(headers, ['day', 'weekday']);
    int? startColumn = _column(headers, ['start_time', 'start']);
    int? endColumn = _column(headers, ['end_time', 'end']);
    int? instructorColumn = _column(headers, ['instructor', 'teacher', 'professor']);
    int? roomColumn = _column(headers, ['room', 'lab', 'venue']);

    if (courseColumn == null || dayColumn == null || startColumn == null || endColumn == null) {
      courseColumn = 0;
      instructorColumn = 1;
      dayColumn = 2;
      startColumn = 3;
      endColumn = 4;
      roomColumn = 5;
    }

    final rows = <TimetableDraftEntry>[];
    final errors = <String>[];
    String value(List<String> row, int? index) {
      if (index == null) return '';
      return index >= row.length ? '' : row[index].trim();
    }

    for (var i = 1; i < source.length; i++) {
      final row = source[i];
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      final dayRaw = value(row, dayColumn);
      final startRaw = value(row, startColumn);
      final endRaw = value(row, endColumn);
      final draft = TimetableDraftEntry(
        courseName: value(row, courseColumn),
        instructor: value(row, instructorColumn),
        room: value(row, roomColumn),
        weekday: _parseDay(dayRaw),
        startTime: _parseTime(startRaw),
        endTime: _parseTime(endRaw),
      );
      final error = draft.validationError;
      if (error != null) {
        errors.add('Row ${i + 1}: $error');
      }
      rows.add(draft);
    }
    if (rows.isEmpty && errors.isEmpty) {
      errors.add('The file has no class rows.');
    }
    return TimetableImportDraft(rows: rows, errors: errors);
  }

  List<List<String>> _csvRows(String text) {
    final rows = <List<String>>[];
    final row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '"') {
        if (quoted && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == ',') {
        row.add(field.toString());
        field.clear();
      } else if (!quoted && (char == '\n' || char == '\r')) {
        if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
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

  List<List<String>> _excelRows(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    XmlDocument xml(String name) => XmlDocument.parse(
        utf8.decode(archive.findFile(name)!.content as List<int>));
    final sharedFile = archive.findFile('xl/sharedStrings.xml');
    final shared = sharedFile == null
        ? <String>[]
        : XmlDocument.parse(utf8.decode(sharedFile.content as List<int>))
            .findAllElements('si')
            .map((item) =>
                item.findAllElements('t').map((text) => text.innerText).join())
            .toList();
    final sheetFile = archive.findFile('xl/worksheets/sheet1.xml');
    if (sheetFile == null) throw const FormatException('Worksheet is missing.');
    final sheet = xml(sheetFile.name);
    return sheet
        .findAllElements('row')
        .map((row) {
          final values = <int, String>{};
          for (final cell in row.findAllElements('c')) {
            final column = _excelColumn(cell.getAttribute('r') ?? '');
            final value = cell.getElement('v')?.innerText ??
                cell
                    .getElement('is')
                    ?.findAllElements('t')
                    .map((t) => t.innerText)
                    .join() ??
                '';
            final resolved =
                cell.getAttribute('t') == 's' && int.tryParse(value) != null
                    ? shared[int.parse(value)]
                    : value;
            values[column] = resolved;
          }
          if (values.isEmpty) return <String>[];
          final max = values.keys.reduce((a, b) => a > b ? a : b);
          return List.generate(max + 1, (index) => values[index] ?? '');
        })
        .where((row) => row.isNotEmpty)
        .toList();
  }

  String _normalizeHeader(String header) => header
      .trim()
      .replaceFirst('\uFEFF', '')
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');

  int? _column(Map<String, int> headers, List<String> aliases) {
    for (final alias in aliases) {
      final index = headers[alias];
      if (index != null) return index;
    }
    return null;
  }

  Weekday? _parseDay(String value) {
    final key = value.trim().toLowerCase().replaceAll('.', '');
    if (key.isEmpty) return null;
    for (final day in Weekday.values) {
      if (day.name.startsWith(key) || day.fullLabel.toLowerCase() == key) {
        return day;
      }
    }
    return null;
  }

  DateTime? _parseTime(String value) {
    final raw = value.trim();
    final excelFraction = double.tryParse(raw);
    if (excelFraction != null && excelFraction >= 0 && excelFraction < 1) {
      final minutes = (excelFraction * 24 * 60).round() % (24 * 60);
      final now = DateTime.now();
      return DateTime(
          now.year, now.month, now.day, minutes ~/ 60, minutes.remainder(60));
    }
    final match = RegExp(
      r'^(\d{1,2})(?::|\.)(\d{2})\s*(am|pm)?$|^(\d{1,2})\s*(am|pm)?$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return null;
    var hour = int.parse(match.group(1) ?? match.group(4)!);
    final minute = int.parse(match.group(2) ?? '0');
    final period = (match.group(3) ?? match.group(5))?.toLowerCase();
    if (hour > 23 || minute > 59 || (period != null && hour > 12)) return null;
    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  int _excelColumn(String reference) {
    final letters = RegExp(r'^[A-Z]+', caseSensitive: false)
        .firstMatch(reference.toUpperCase())
        ?.group(0);
    if (letters == null) throw const FormatException('Invalid cell address.');
    var column = 0;
    for (final code in letters.codeUnits) {
      column = column * 26 + code - 64;
    }
    return column - 1;
  }
}
