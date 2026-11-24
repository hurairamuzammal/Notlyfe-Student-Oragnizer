import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notlyfe/models/note.dart';
import 'package:notlyfe/models/note_style_settings.dart';
import 'package:notlyfe/services/e2ee_service.dart';
import 'package:notlyfe/services/secure_storage_service.dart';
import 'package:notlyfe/utils/note_content_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NoteContentCodec', () {
    test('decodes legacy plain text cleanly into a Quill Document', () {
      const legacy = 'Lecture 1: Introduction to Operating Systems';
      final decoded = NoteContentCodec.decode(legacy);
      expect(decoded.isRichText, isFalse);
      expect(decoded.document.toPlainText().trim(), legacy);
      expect(NoteContentCodec.extractPlainText(legacy), legacy);
    });

    test('encodes and decodes rich Delta formatting + per-note style', () {
      final delta = Delta()
        ..insert('Heading', {'header': 1})
        ..insert('\n')
        ..insert('Bold', {'bold': true})
        ..insert(' ')
        ..insert('Highlighted', {'background': '#FEF08A', 'color': '#1D4ED8'})
        ..insert('\n')
        ..insert('Buy milk', {'list': 'unchecked'})
        ..insert('\n')
        ..insert('Read paper', {'list': 'checked'})
        ..insert('\n');

      final doc = Document.fromDelta(delta);
      final perNoteStyle = NoteStyleSettings(
        fontFamily: 'Merriweather',
        bodyFontSize: 17,
        lineHeight: 1.65,
        headingScale: 1.1,
        paperColorValue: 0xFFFFFBF0,
      );

      final encoded = NoteContentCodec.encode(doc, perNoteStyle: perNoteStyle);
      final decoded = NoteContentCodec.decode(encoded);

      expect(decoded.isRichText, isTrue);
      expect(decoded.noteStyle, isNotNull);
      expect(decoded.noteStyle!.fontFamily, 'Merriweather');
      expect(decoded.noteStyle!.paperColorValue, 0xFFFFFBF0);
      expect(
        NoteContentCodec.extractPlainText(encoded),
        contains('Highlighted'),
      );

      final stats = NoteContentCodec.extractChecklistStats(encoded);
      expect(stats.total, 2);
      expect(stats.checked, 1);
    });
  });

  group('NoteStyleSettings', () {
    test('serializes and deserializes cleanly across platforms', () {
      final original = NoteStyleSettings(
        fontFamily: 'Caveat',
        bodyFontSize: 19,
        lineHeight: 1.7,
        headingScale: 1.2,
        defaultTextColorValue: 0xFF1D4ED8,
        defaultHighlightColorValue: 0xFFFEF08A,
        paperColorValue: 0xFFF2FBF5,
        updatedAt: DateTime.utc(2026, 11, 16, 12, 0),
      );
      final roundtrip =
          NoteStyleSettings.tryParseJsonString(original.toJsonString());
      expect(roundtrip, equals(original));
      expect(roundtrip!.updatedAt, original.updatedAt);
    });
  });

  group('E2EE + SecureStorageService', () {
    test('encrypts and decrypts rich Note content end-to-end', () async {
      await E2eeService.instance.setUser('test-user-e2ee');
      final note = Note(
        id: 'n1',
        userId: 'test-user-e2ee',
        title: 'Secret Rich Note',
        content: NoteContentCodec.encode(
          Document.fromDelta(Delta()
            ..insert('Confidential', {'bold': true, 'underline': true})
            ..insert('\n')),
        ),
      );

      final map = note.toSupabaseMap();
      expect(map['title'].toString().startsWith('enc:v2:'), isTrue);
      expect(map['content'].toString().startsWith('enc:v2:'), isTrue);

      final decrypted = Note.fromMap(map);
      expect(decrypted.title, 'Secret Rich Note');
      expect(
        NoteContentCodec.extractPlainText(decrypted.content),
        'Confidential',
      );
    });

    test('SecureStorageService writes v2 AES+HMAC and reads back cleanly',
        () async {
      await SecureStorageService.writeSecure('webdav_pass', 's3cr3t-token!');
      final read = await SecureStorageService.readSecure('webdav_pass');
      expect(read, 's3cr3t-token!');

      await SecureStorageService.deleteSecure('webdav_pass');
      expect(await SecureStorageService.readSecure('webdav_pass'), isNull);
    });
  });
}
