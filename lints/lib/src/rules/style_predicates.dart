const Set<String> _widgetBaseNames = {'StatelessWidget', 'StatefulWidget'};

bool isPublicWidgetClass({
  required String className,
  required String? superclassName,
}) => !className.startsWith('_') && _widgetBaseNames.contains(superclassName);

bool isDisallowedWidgetReturn({
  required String name,
  required String? returnTypeName,
  required bool isAccessor,
}) => !isAccessor && name != 'build' && returnTypeName == 'Widget';
