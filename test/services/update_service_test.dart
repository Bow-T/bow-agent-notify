import 'package:bow_notify/src/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('so phiên bản: theo từng số, không theo chữ', () {
    expect(isNewerVersion('1.12.0', '1.11.0'), isTrue);
    expect(
      isNewerVersion('1.10.0', '1.9.1'),
      isTrue,
    ); // so chữ thì "1.10" < "1.9"
    expect(isNewerVersion('2.0.0', '1.99.99'), isTrue);
    expect(isNewerVersion('1.11.1', '1.11.0'), isTrue);
    expect(isNewerVersion('1.11.0', '1.11.0'), isFalse);
    expect(isNewerVersion('1.10.9', '1.11.0'), isFalse);
  });

  test('chấp nhận tiền tố v, số build và độ dài khác nhau', () {
    expect(isNewerVersion('v1.12.0', '1.11.0+16'), isTrue);
    expect(isNewerVersion('1.12', '1.11.5'), isTrue);
    expect(isNewerVersion('1.11', '1.11.0'), isFalse);
    expect(isNewerVersion('1.11.0.1', '1.11.0'), isTrue);
  });

  test('chuỗi không đọc được thì không mời cập nhật', () {
    expect(isNewerVersion('latest', '1.11.0'), isFalse);
    expect(isNewerVersion('', '1.11.0'), isFalse);
    expect(isNewerVersion('1.x.0', '1.11.0'), isFalse);
    expect(isNewerVersion('2.0.0', 'dev'), isFalse);
  });
}
