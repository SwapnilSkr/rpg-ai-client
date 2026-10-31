import 'rig_expression.dart';

/// One scripted line shown as a subtitle while the mouth flaps.
class TalkLine {
  const TalkLine(this.text, this.expression, {this.seconds = 2.5});

  final String text;
  final RigExpression expression;
  final double seconds;

  /// The mouth closes for the last beat so lines don't run together.
  static const double closingBeat = 0.35;
}

const List<TalkLine> talkLines = [
  TalkLine('You made it. I was starting to wonder.', RigExpression.neutral),
  TalkLine("I'm glad. It has been quiet without you.", RigExpression.happy),
  TalkLine("Don't look at me like that. I'll lose my place.", RigExpression.shy),
  TalkLine('Wait. Is that really for me?', RigExpression.surprised),
];

enum ScriptAction { talk, lookAway }

class ScriptEvent {
  const ScriptEvent(this.at, this.action);

  final double at;
  final ScriptAction action;
}

/// The fixed 30 s clip, so A and B can be recorded identically:
/// 8 s idle, the four lines (10 s), 2 s idle, look away and back (6 s), 4 s idle.
abstract final class RecordScript {
  static const double total = 30;
  static const int seed = 20261031;
  static const List<ScriptEvent> events = [
    ScriptEvent(8, ScriptAction.talk),
    ScriptEvent(20, ScriptAction.lookAway),
  ];
}
