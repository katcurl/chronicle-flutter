import 'package:chronicle/data/database/chronicle_database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated_schema/schema.dart';

void main() {
  test('runtime schema matches the checked-in Drift v5 snapshot', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final connection = await verifier.startAt(chronicleDatabaseSchemaVersion);
    final database = ChronicleDatabase(connection);

    await verifier.migrateAndValidate(
      database,
      chronicleDatabaseSchemaVersion,
      options: const ValidationOptions(validateDropped: true),
    );

    await database.close();
  });
}
