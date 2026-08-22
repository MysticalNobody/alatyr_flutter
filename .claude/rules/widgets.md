---
paths:
  - "packages/design_system/**"
  - "**/widgets/**"
  - "**/ui/**"
---

# Widget conventions

- One public `StatelessWidget`/`StatefulWidget` per file (lint
  `alatyr_one_widget_per_file`); no named function or method other than
  `build` returns `Widget` (`alatyr_no_widget_returning_function`); no
  nested ternaries (`alatyr_no_nested_ternary`).
- Every interactive widget carries a `ValueKey` from its feature's key
  namespace: a `<Feature>Keys` class in the feature's `*_api` package with a
  private `_ns` and `ValueKey<String>('<ns>.<screen>.<element>')` members
  (template: `SettingsKeys`). Base widgets make the key a constructor
  requirement (`required Key super.key`, see `AppChoiceTile`).
- Tokens before numbers: `AppSpacing`, `AppRadii`; colours come from
  `Theme.of(context).colorScheme`; themes from `AppTheme.light()/dark()`.
- Public fields never promote: shadow them (`final failure = this.failure;`)
  before null checks.
