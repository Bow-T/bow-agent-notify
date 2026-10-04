import 'pairing.dart';

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
    this.options = const [],
  });

  /// Máy gửi thẻ — quyết định phải mã hoá bằng khoá của đúng máy này.
  final Pairing pairing;

  /// Nhánh của tiến trình bow đã gửi (cổng của nó) — trả lời ghi về đúng nhánh đó.
  final String port;
  final String id;

  /// `approval` (cho phép / từ chối), `question` (chọn đáp án) hoặc `reply` (lượt đã xong, bow mời vài câu trả lời
  /// nhanh — chọn một câu là tab trên máy gửi đúng câu đó).
  final String kind;
  final String label;
  final String tool;
  final String text;

  /// Thao tác rủi ro (push, xoá…) — phải xác thực vân tay / mật mã máy trước khi gửi "cho phép".
  final bool risky;
  final DateTime at;
  final List<Question> questions;

  /// Thẻ `reply`: các câu được mời. Chỉ gửi lại được đúng một câu trong đó.
  final List<String> options;

  static PendingCard? fromJson(
    Pairing pairing,
    String port,
    String id,
    Object? json,
  ) {
    if (json is! Map) return null;
    final kind = json['kind'];
    if (json['id'] != id ||
        (kind != 'approval' && kind != 'question' && kind != 'reply')) {
      return null;
    }
    final options = <String>[
      for (final o
          in (json['options'] is List ? json['options'] as List : const []))
        if (o is String && o.isNotEmpty) o,
    ];
    if (kind == 'reply' && options.isEmpty) return null;
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
      options: options,
    );
  }
}
