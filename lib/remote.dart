import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'pairing.dart';

/// Duyệt từ điện thoại — nửa của app. Nửa server: `src/core/remoteApproval.ts` (repo bow-agent).
///
/// Server ghi thẻ chờ duyệt lên Realtime Database của người dùng, app đọc; app ghi quyết định, server đọc rồi tự áp.
/// MỌI thứ đi qua đó là bản mã AES-256-GCM bằng khoá ghép máy (trong mã QR): Google chỉ thấy bản mã, và trả lời
/// không tạo được bằng đúng khoá thì server bỏ. Dữ liệu kèm (AAD) buộc bản mã vào đúng chiều + đúng mã thẻ.

/// Một lựa chọn của câu hỏi.
typedef QuestionOption = ({String label, String description});

/// Một câu hỏi agent gửi (tool AskUserQuestion).
typedef Question = ({
  String question,
  String header,
  bool multiSelect,
  List<QuestionOption> options,
});

/// Một thẻ đang chờ trên máy chạy bow.
class PendingCard {
  const PendingCard({
    required this.pairing,
    required this.port,
    required this.id,
    required this.kind,
    required this.label,
    required this.tool,
    required this.text,
    required this.risky,
    required this.at,
    required this.questions,
  });

  /// Máy gửi thẻ — quyết định phải mã hoá bằng khoá của đúng máy này.
  final Pairing pairing;

  /// Nhánh của tiến trình bow đã gửi (cổng của nó) — trả lời ghi về đúng nhánh đó.
  final String port;
  final String id;

  /// `approval` (cho phép / từ chối) hoặc `question` (chọn đáp án).
  final String kind;
  final String label;
  final String tool;
  final String text;

  /// Thao tác rủi ro (push, xoá…) — phải xác thực vân tay / mật mã máy trước khi gửi "cho phép".
  final bool risky;
  final DateTime at;
  final List<Question> questions;

  static PendingCard? fromJson(
    Pairing pairing,
    String port,
    String id,
    Object? json,
  ) {
    if (json is! Map) return null;
    final kind = json['kind'];
    if (json['id'] != id || (kind != 'approval' && kind != 'question')) {
      return null;
    }
    String text(Object? v) => v is String ? v : '';
    final questions = <Question>[
      for (final q
          in (json['questions'] is List ? json['questions'] as List : const []))
        if (q is Map)
          (
            question: text(q['question']),
            header: text(q['header']),
            multiSelect: q['multiSelect'] == true,
            options: [
              for (final o
                  in (q['options'] is List ? q['options'] as List : const []))
                if (o is Map)
                  (
                    label: text(o['label']),
                    description: text(o['description']),
                  ),
            ],
          ),
    ];
    return PendingCard(
      pairing: pairing,
      port: port,
      id: id,
      kind: kind as String,
      label: text(json['label']),
      tool: text(json['tool']),
      text: text(json['text']),
      risky: json['risky'] == true,
      at: DateTime.fromMillisecondsSinceEpoch(
        json['at'] is int ? json['at'] as int : 0,
      ),
      questions: questions,
    );
  }
}

final _aes = AesGcm.with256bits();
const _timeout = Duration(seconds: 12);

SecretKey _key(Pairing pairing) =>
    SecretKey(base64Url.decode(base64Url.normalize(pairing.key!)));

/// Mở một bản mã của server: nonce (12) + bản mã + thẻ xác thực (16), base64url. `null` = sai khoá / bị sửa / sai mã thẻ.
Future<Object?> openCard(Pairing pairing, String id, String blob) async {
  try {
    final box = SecretBox.fromConcatenation(
      base64Url.decode(base64Url.normalize(blob)),
      nonceLength: 12,
      macLength: 16,
    );
    final clear = await _aes.decrypt(
      box,
      secretKey: _key(pairing),
      aad: utf8.encode('bow-req:$id'),
    );
    return jsonDecode(utf8.decode(clear));
  } catch (_) {
    return null;
  }
}

/// Mã hoá một trả lời cho thẻ [id] — cùng khuôn với `seal(key, 'reply', id, …)` của server.
Future<String> sealReply(Pairing pairing, String id, Object reply) async {
  final box = await _aes.encrypt(
    utf8.encode(jsonEncode(reply)),
    secretKey: _key(pairing),
    aad: utf8.encode('bow-rep:$id'),
  );
  return base64Url.encode(box.concatenation()).replaceAll('=', '');
}

Future<(int, String)> _call(String method, Uri url, [String? body]) async {
  final client = HttpClient()..connectionTimeout = _timeout;
  try {
    final request = await client.openUrl(method, url).timeout(_timeout);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body);
    }
    final response = await request.close().timeout(_timeout);
    final text = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_timeout);
    return (response.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

/// Các thẻ đang chờ trên máy [pairing]. Thẻ không mở được bằng khoá (của máy khác / hỏng) bị bỏ qua.
Future<List<PendingCard>> fetchPending(Pairing pairing) async {
  if (!pairing.canApprove) return const [];
  final (status, body) = await _call(
    'GET',
    Uri.https(pairing.dbHost!, '/bow/${pairing.topic}/pending.json'),
  );
  if (status != 200) throw HttpException('HTTP $status');
  final data = jsonDecode(body);
  final cards = <PendingCard>[];
  if (data is! Map) return cards; // null = không có thẻ nào
  for (final MapEntry(key: port, value: byId) in data.entries) {
    if (byId is! Map) continue;
    for (final MapEntry(key: id, value: blob) in byId.entries) {
      if (blob is! String) continue;
      final card = PendingCard.fromJson(
        pairing,
        '$port',
        '$id',
        await openCard(pairing, '$id', blob),
      );
      if (card != null) cards.add(card);
    }
  }
  return cards..sort((a, b) => a.at.compareTo(b.at));
}

/// Mã thẻ / nhánh tới từ thông báo đẩy — chỉ nhận đúng khuôn này trước khi ghép vào đường dẫn.
final _safeKey = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// MỘT thẻ theo mã (thông báo đẩy mang mã thẻ + nhánh). `null` = thẻ không còn chờ, hoặc không mở được bằng khoá.
/// Ném lỗi khi mã sai khuôn / database không trả lời — khác hẳn "thẻ đã hết".
Future<PendingCard?> fetchCard(Pairing pairing, String port, String id) async {
  if (!pairing.canApprove) return null;
  if (!_safeKey.hasMatch(port) || !_safeKey.hasMatch(id)) {
    throw const FormatException('mã thẻ sai khuôn');
  }
  final (status, body) = await _call(
    'GET',
    Uri.https(pairing.dbHost!, '/bow/${pairing.topic}/pending/$port/$id.json'),
  );
  if (status != 200) throw HttpException('HTTP $status');
  final blob = jsonDecode(body);
  if (blob is! String) return null;
  return PendingCard.fromJson(
    pairing,
    port,
    id,
    await openCard(pairing, id, blob),
  );
}

/// Gửi quyết định cho [card]: `{allow: bool}` hoặc `{answers: {...} | null}`. Ném lỗi khi server cơ sở dữ liệu từ
/// chối — thường là thẻ này đã có trả lời (mỗi thẻ chỉ ghi được MỘT lần).
Future<void> sendReply(PendingCard card, Map<String, Object?> reply) async {
  final (status, _) = await _call(
    'PUT',
    Uri.https(
      card.pairing.dbHost!,
      '/bow/${card.pairing.topic}/replies/${card.port}/${card.id}.json',
    ),
    jsonEncode(await sealReply(card.pairing, card.id, reply)),
  );
  if (status != 200) throw HttpException('HTTP $status');
}
