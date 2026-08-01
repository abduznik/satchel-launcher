import 'package:flutter_test/flutter_test.dart';
import 'package:satchel/models/api_search_result.dart';

void main() {
  test('ApiSearchResult creation', () {
    final result = ApiSearchResult(
      id: '1',
      name: 'Test Game',
      source: 'steamgriddb',
    );
    expect(result.id, '1');
    expect(result.name, 'Test Game');
    expect(result.source, 'steamgriddb');
  });
}
