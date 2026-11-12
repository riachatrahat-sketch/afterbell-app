import 'package:afterbell_app/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON helpers read values safely', () {
    expect(str(null, 'x'), 'x');
    expect(num0('12'), 12);
    expect(yes(1), true);
    expect(rows(<dynamic>[<String, dynamic>{'a': 1}, 'skip']).length, 1);
    expect(strings(<dynamic>[1, 'b']), <String>['1', 'b']);
  });
}
