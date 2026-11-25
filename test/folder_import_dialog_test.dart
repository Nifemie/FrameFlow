import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/features/media/widgets/folder_import_dialog.dart';

void main() {
  testWidgets('FolderImportDialog renders without throwing exception', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('test_folder');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FolderImportDialog(
            directoryPath: tempDir.path,
            onImportConfirmed: (paths, stamps) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(FolderImportDialog), findsOneWidget);
    tempDir.deleteSync(recursive: true);
  });
}
