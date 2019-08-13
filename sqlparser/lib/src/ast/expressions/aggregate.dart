part of '../ast.dart';

class AggregateExpression extends Expression {
  final IdentifierToken function;

  String get functionName => function.identifier;

  final FunctionParameters parameters;
  final Expression filter;
  final WindowDefinition over; // todo support window references

  AggregateExpression(
      {@required this.function,
      @required this.parameters,
      this.filter,
      @required this.over});

  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitAggregateExpression(this);

  @override
  Iterable<AstNode> get childNodes {
    return [
      if (parameters is ExprFunctionParameters)
        ...(parameters as ExprFunctionParameters).parameters,
      if (filter != null) filter,
      over,
    ];
  }

  @override
  bool contentEquals(AggregateExpression other) {
    return other.functionName == functionName;
  }
}

class WindowDefinition extends AstNode {
  final String baseWindowName;
  final List<Expression> partitionBy;
  final OrderBy orderBy;

  WindowDefinition(
      {this.baseWindowName, this.partitionBy = const [], this.orderBy});

  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitWindowDefinition(this);

  @override
  Iterable<AstNode> get childNodes =>
      [...partitionBy, if (orderBy != null) orderBy];

  @override
  bool contentEquals(WindowDefinition other) {
    return other.baseWindowName == baseWindowName;
  }
}

class FrameSpec extends AstNode {
  final FrameType type;
  final ExcludeMode excludeMode;
  final FrameBoundary start;
  final FrameBoundary end;

  FrameSpec({
    @required this.type,
    this.start = const FrameBoundary.unboundedPreceding(),
    this.end = const FrameBoundary.currentRow(),
    this.excludeMode = ExcludeMode.noOthers,
  });

  @override
  T accept<T>(AstVisitor<T> visitor) => visitor.visitFrameSpec(this);

  @override
  Iterable<AstNode> get childNodes => [
        if (start.isExpressionOffset) start.offset,
        if (end.isExpressionOffset) end.offset,
      ];

  @override
  bool contentEquals(FrameSpec other) {
    return other.type == type &&
        other.excludeMode == excludeMode &&
        other.start == start &&
        other.end == end;
  }
}

/// Defines how a [FrameBoundary] count rows or groups. See
/// https://www.sqlite.org/windowfunctions.html#frame_type for details.
enum FrameType { rows, groups, range }

/// Defines if rows are omitted inside a [FrameBoundary].
enum ExcludeMode {
  /// default, no rows are excluded from the window frame
  noOthers,

  /// the current row is excluded from the window frame
  currentRow,

  /// The row and and its peers (rows considered to be equal to the ORDER BY
  /// clause) are excluded
  group,

  /// Peers of the row are excluded (see [group]), but not the row itself.
  ties,
}

enum _BoundaryType {
  currentRow,
  exprOffset,
  unboundedOffset,
}

/// Defines how many rows before or after a current row should be included in
/// a window.
class FrameBoundary {
  final _BoundaryType _type;

  /// The (integer) expression that specifies the amount of rows to include
  /// before or after the row being processed.
  final Expression offset;

  /// Whether this boundary refers to a row before the current row.
  final bool preceding;
  bool get following => !preceding;

  /// Whether this boundary is a `<expr> PRECEDING` or `<expr> FOLLOWING`
  /// boundary.
  bool get isExpressionOffset => _type == _BoundaryType.exprOffset;

  /// Whether this boundary is a `UNBOUNDED PRECEDING` or `UNBOUNDED FOLLOWING`.
  bool get isUnbounded => _type == _BoundaryType.unboundedOffset;

  /// Whether this boundary only refers to the current row.
  bool get isCurrentRow => _type == _BoundaryType.currentRow;

  const FrameBoundary._(this._type, this.preceding, {this.offset});

  const FrameBoundary.unboundedPreceding()
      : this._(_BoundaryType.unboundedOffset, true);
  const FrameBoundary.unboundedFollowing()
      : this._(_BoundaryType.unboundedOffset, false);

  const FrameBoundary.currentRow() : this._(_BoundaryType.currentRow, false);

  const FrameBoundary.preceding(Expression amount)
      : this._(_BoundaryType.exprOffset, true, offset: amount);
  const FrameBoundary.following(Expression amount)
      : this._(_BoundaryType.exprOffset, false, offset: amount);

  @override
  int get hashCode {
    return (preceding ? 2 : 3) * (5 * offset.hashCode + _type.hashCode);
  }

  @override
  bool operator ==(other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;

    // lint bug: https://github.com/dart-lang/linter/issues/1397
    final typedOther = other as FrameBoundary; // ignore: test_types_in_equals
    return typedOther._type == _type &&
        typedOther.offset.contentEquals(offset) &&
        typedOther.preceding == preceding;
  }
}