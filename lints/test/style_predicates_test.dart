import 'package:alatyr_lints/src/rules/style_predicates.dart';
import 'package:test/test.dart';

void main() {
  group('isPublicWidgetClass', () {
    test('public StatelessWidget/StatefulWidget subclass', () {
      expect(
        isPublicWidgetClass(
          className: 'HomeCard',
          superclassName: 'StatelessWidget',
        ),
        isTrue,
      );
      expect(
        isPublicWidgetClass(
          className: 'HomePage',
          superclassName: 'StatefulWidget',
        ),
        isTrue,
      );
    });
    test('private or non-widget superclass', () {
      expect(
        isPublicWidgetClass(
          className: '_HomeCard',
          superclassName: 'StatelessWidget',
        ),
        isFalse,
      );
      expect(
        isPublicWidgetClass(className: 'HomeCard', superclassName: 'Bloc'),
        isFalse,
      );
      expect(
        isPublicWidgetClass(className: 'HomeCard', superclassName: null),
        isFalse,
      );
    });
  });

  group('isDisallowedWidgetReturn', () {
    test('bare Widget return fires', () {
      expect(
        isDisallowedWidgetReturn(
          name: 'buildHeader',
          returnTypeName: 'Widget',
          isAccessor: false,
        ),
        isTrue,
      );
    });
    test('build(), accessors, and non-bare-Widget types are exempt', () {
      expect(
        isDisallowedWidgetReturn(
          name: 'build',
          returnTypeName: 'Widget',
          isAccessor: false,
        ),
        isFalse,
      );
      expect(
        isDisallowedWidgetReturn(
          name: 'header',
          returnTypeName: 'Widget',
          isAccessor: true,
        ),
        isFalse,
      );
      expect(
        isDisallowedWidgetReturn(
          name: 'items',
          returnTypeName: 'PreferredSizeWidget',
          isAccessor: false,
        ),
        isFalse,
      );
      expect(
        isDisallowedWidgetReturn(
          name: 'x',
          returnTypeName: null,
          isAccessor: false,
        ),
        isFalse,
      );
    });
  });
}
