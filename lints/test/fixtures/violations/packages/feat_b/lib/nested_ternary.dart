// Fires alatyr_no_nested_ternary exactly once: ternary expressions are
// right-associative, so `a ? 1 : b ? 2 : 3` parses as
// `a ? 1 : (b ? 2 : 3)` - the inner ternary is the elseExpression of the
// outer one, which is exactly what the rule flags.
const bool a = true;
const bool b = false;

final v = a
    ? 1
    : b
    ? 2
    : 3;
