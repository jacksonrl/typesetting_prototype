import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';

class JsCodeBuilder {
  final StringBuffer _buffer = StringBuffer();
  int _indent = 0;

  void _write(String s) {
    _buffer.write('  ' * _indent);
    _buffer.writeln(s);
  }

  void blankLine() => _buffer.writeln();
  void writeLine(String line) => _write(line);

  void writeConst(String name, Map<String, String> values) {
    if (values.isEmpty) {
      _write('const $name = {};');
      return;
    }
    final entries = values.entries.map((e) => "${e.key}: ${e.value}").join(', ');
    _write('const $name = { $entries };');
  }

  void writeIife(String name, void Function(JsCodeBuilder builder) body) {
    _write('const $name = (function() {');
    _indent++;
    body(this);
    _indent--;
    _write('})();');
  }

  void writeFunction(String name, List<String> params, void Function(JsCodeBuilder builder) body) {
    final signature = name.contains('.')
        ? '$name = function(${params.join(', ')})'
        : 'function $name(${params.join(', ')})';
    _write('$signature {');
    _indent++;
    body(this);
    _indent--;
    _write('};');
  }

  void writeReturnObject(Map<String, String> properties) {
    if (properties.isEmpty) {
      _write('return {};');
      return;
    }
    _write('return {');
    _indent++;
    final lastKey = properties.keys.last;
    properties.forEach((key, value) {
      final comma = key == lastKey ? '' : ',';
      _write('$key: $value$comma');
    });
    _indent--;
    _write('};');
  }

  @override
  String toString() => _buffer.toString();
}

class JsExpressionVisitor extends GeneralizingAstVisitor<String> {
  final List<ClassElement2> _allClasses;
  final List<EnumElement2> _allEnums;
  final String? _iifeContextClassName;

  JsExpressionVisitor(this._allClasses, this._allEnums, {String? iifeContextClassName})
    : _iifeContextClassName = iifeContextClassName;

  String _getJsClassName(String dartName) {
    return dartName.startsWith('_') ? dartName.substring(1) : dartName;
  }

  String translateClassName(String dartClassName) {
    if (dartClassName == _iifeContextClassName) {
      return 'mainFactory';
    }
    return _getJsClassName(dartClassName);
  }

  @override
  String visitNode(AstNode node) => node.toSource();

  @override
  String visitBooleanLiteral(BooleanLiteral node) => node.toSource();
  @override
  String visitDoubleLiteral(DoubleLiteral node) => node.toSource();
  @override
  String visitIntegerLiteral(IntegerLiteral node) => node.toSource();
  @override
  String visitNullLiteral(NullLiteral node) => 'null';
  @override
  String visitSimpleStringLiteral(SimpleStringLiteral node) => node.toSource();
  @override
  String visitAdjacentStrings(AdjacentStrings node) => node.toSource();
  @override
  String visitListLiteral(ListLiteral node) => '[${node.elements.map((e) => e.accept(this)).join(', ')}]';
  @override
  String visitSetOrMapLiteral(SetOrMapLiteral node) => '{${node.elements.map((e) => e.accept(this)).join(', ')}}';
  @override
  String visitThisExpression(ThisExpression node) => 'mainFactory';

  @override
  String visitNamedType(NamedType node) {
    final name = node.name2.lexeme;
    if (name == _iifeContextClassName) {
      return 'mainFactory';
    }
    return _getJsClassName(name);
  }

  @override
  String visitConstructorName(ConstructorName node) {
    final typeName = node.type.accept(this)!;
    if (node.name != null) {
      return '$typeName.${node.name!.name}';
    }
    return typeName;
  }

  @override
  String visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == _iifeContextClassName) {
      return 'mainFactory';
    }
    final jsName = _getJsClassName(node.name);
    final matchedClass = _allClasses.firstWhereOrNull((c) => c.name3 == node.name);
    if (matchedClass != null) {
      if (node.parent is PropertyAccess && (node.parent as PropertyAccess).target == node) {
        return jsName;
      }
      if (_iifeContextClassName == node.name) {
        return node.name;
      }
      return jsName;
    }
    return node.name;
  }

  @override
  String visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix.name;
    final identifier = node.identifier.name;
    if (_allEnums.any((e) => e.name3 == prefix)) {
      return "'$identifier'";
    }
    final jsPrefix = _getJsClassName(prefix);
    if (_allClasses.any((c) => c.name3 == prefix)) {
      return '$jsPrefix.$identifier';
    }
    return node.toSource();
  }

  @override
  String visitPropertyAccess(PropertyAccess node) {
    final targetSource = node.target?.accept(this);
    if (node.target is SimpleIdentifier && (node.target as SimpleIdentifier).name == _iifeContextClassName) {
      return node.propertyName.name;
    }
    final property = node.propertyName.name;
    return '$targetSource.$property';
  }

  @override
  String visitNamedExpression(NamedExpression node) {
    if (node.parent is SetOrMapLiteral) {
      final key = node.name.label.accept(this);
      final value = node.expression.accept(this);
      return '$key: $value';
    }
    final value = node.expression.accept(this)!;
    return '${node.name.label.name}: $value';
  }

  String _translateInvocation(String functionName, ArgumentList argumentList) {
    final positionalArgs = <String>[];
    final namedArgs = <String>[];
    for (final arg in argumentList.arguments) {
      final acceptedArg = arg.accept(this);
      if (acceptedArg == null) continue;
      if (arg is NamedExpression) {
        namedArgs.add(acceptedArg);
      } else {
        positionalArgs.add(acceptedArg);
      }
    }
    final jsArgs = <String>[];
    if (positionalArgs.isNotEmpty) jsArgs.add(positionalArgs.join(', '));
    if (namedArgs.isNotEmpty) jsArgs.add('{ ${namedArgs.join(', ')} }');
    return '$functionName(${jsArgs.join(', ')})';
  }

  @override
  String visitInstanceCreationExpression(InstanceCreationExpression node) {
    final functionName = node.constructorName.accept(this)!;
    return _translateInvocation(functionName, node.argumentList);
  }

  @override
  String visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.accept(this);
    final methodName = node.methodName.name;
    final fullName = target != null ? '$target.$methodName' : methodName;
    return _translateInvocation(fullName, node.argumentList);
  }

  @override
  String visitRedirectingConstructorInvocation(RedirectingConstructorInvocation node) {
    final ctorName = node.constructorName?.name ?? '';
    final targetName = ctorName.isEmpty ? 'mainFactory' : 'mainFactory.$ctorName';
    return _translateInvocation(targetName, node.argumentList);
  }
}

Map<String, Set<String>> _membersToSkip = {};
const Set<String> _typesToPrecalculate = {
  'PageFormat',
  'Alignment',
  'BorderSide',
  'Color',
  'FontFamily',
  'TextStyle',
  'Size',
  'Border',
  'Font',
  'EdgeInsets',
};

const Set<String> _typesToInlineAggressively = {'_BuiltInFont'};

Future<String> generateJsApiFile(
  List<ClassElement2> classes,
  List<EnumElement2> enums,
  AnalysisSession session,
  Map<String, Set<String>> membersToSkip,
) async {
  _membersToSkip = membersToSkip;
  final builder = JsCodeBuilder();
  final visitor = JsExpressionVisitor(classes, enums);

  builder.writeLine('// GENERATED CODE - DO NOT MODIFY BY HAND');
  builder.blankLine();
  builder.writeLine('\n// --- ENUMERATIONS ---\n');
  for (final enumElement in enums) {
    final jsName = visitor._getJsClassName(enumElement.name3!);
    final values = {for (var f in enumElement.fields2.where((f) => f.isEnumConstant)) f.name3!: "'${f.name3}'"};
    builder.writeConst(jsName, values);
  }
  builder.blankLine();

  final allConstructorAsts = <ConstructorElement2, ConstructorDeclaration>{};
  for (final classElement in classes) {
    final libraryResult = await session.getResolvedLibraryByElement2(classElement.library2);
    if (libraryResult is! ResolvedLibraryResult) continue;
    for (final ctor in classElement.constructors2) {
      final node = libraryResult.getFragmentDeclaration(ctor.firstFragment)?.node;
      if (node is ConstructorDeclaration) {
        allConstructorAsts[ctor] = node;
      }
    }
  }

  final globalConstants = <String, dynamic>{};
  await _preEvaluateConstants(
    classes.where((c) => _typesToPrecalculate.contains(c.name3)).toList(),
    session,
    globalConstants,
    allConstructorAsts,
  );

  builder.writeLine('\n// --- FACTORIES & HELPERS (IIFE) ---\n');
  final sortedClasses = classes.toList()..sort((a, b) => a.name3!.compareTo(b.name3!));

  for (final classElement in sortedClasses) {
    if (classElement.name3 == 'Widget') continue;
    await _buildJsClassAsIife(builder, classElement, classes, enums, session, globalConstants, allConstructorAsts);
    builder.blankLine();
  }

  builder.writeLine('''

// --- Helpers ---
function getMetadata(context, key, policy = MetadataRetrievalPolicy.onPageThenLatest) {
    if (!context || !context.metadata) return [];
    switch (policy) {
        case MetadataRetrievalPolicy.onPage:
            return context.metadata.filter(r => r.key === key && r.pageNumber === context.pageNumber).map(r => r.value);
        case MetadataRetrievalPolicy.latest:
            const record = context.metadata.slice().reverse().find(r => r.key === key && r.pageNumber <= context.pageNumber);
            return record ? [record.value] : [];
        case MetadataRetrievalPolicy.onPageThenLatest:
            const onPageResults = getMetadata(context, key, MetadataRetrievalPolicy.onPage);
            if (onPageResults.length > 0) return onPageResults;
            return getMetadata(context, key, MetadataRetrievalPolicy.latest);
    }
    return [];
}

// --- API Contract ---
function defineDocument() { throw new Error("User script must define a 'defineDocument' function."); }
''');
  return builder.toString();
}

Future<void> _preEvaluateConstants(
  List<ClassElement2> classesToPrecalculate,
  AnalysisSession session,
  Map<String, dynamic> globalConstants,
  Map<ConstructorElement2, ConstructorDeclaration> allConstructorAsts,
) async {
  final allStaticFields = <VariableDeclaration>[];
  final classNameByField = <VariableDeclaration, String>{};
  final localConstantsForEval = <String, dynamic>{...globalConstants};

  for (final classElement in classesToPrecalculate) {
    final libraryResult = await session.getResolvedLibraryByElement2(classElement.library2);
    if (libraryResult is! ResolvedLibraryResult) continue;

    final classDeclaration =
        libraryResult.getFragmentDeclaration(classElement.firstFragment)?.node as ClassDeclaration?;
    if (classDeclaration == null) continue;

    final staticFields = classDeclaration.members
        .whereType<FieldDeclaration>()
        .where((f) => f.isStatic)
        .expand((f) => f.fields.variables);

    for (final field in staticFields) {
      allStaticFields.add(field);
      classNameByField[field] = classElement.name3!;
    }
  }

  int lastResolvedCount = -1;
  while (localConstantsForEval.length > lastResolvedCount) {
    lastResolvedCount = localConstantsForEval.length;
    for (final field in allStaticFields) {
      final className = classNameByField[field]!;
      final fieldName = field.name.lexeme;
      final constantKey = '$className.$fieldName';
      if (localConstantsForEval.containsKey(constantKey)) continue;

      final value = _evaluateConstantExpression(
        field.initializer,
        localConstantsForEval,
        _typesToPrecalculate,
        allConstructorAsts,
        currentClassName: className,
      );
      if (value != null) {
        localConstantsForEval[constantKey] = value;
        localConstantsForEval[fieldName] = value;
      }
    }
  }
  globalConstants.addAll(
    localConstantsForEval.entries.where((e) => e.key.contains('.')).fold({}, (p, e) => p..[e.key] = e.value),
  );
}

Future<void> _buildJsClassAsIife(
  JsCodeBuilder builder,
  ClassElement2 classElement,
  List<ClassElement2> allProxyClasses,
  List<EnumElement2> allProxyEnums,
  AnalysisSession session,
  Map<String, dynamic> globalConstants,
  Map<ConstructorElement2, ConstructorDeclaration> allConstructorAsts,
) async {
  final standardVisitor = JsExpressionVisitor(allProxyClasses, allProxyEnums);
  final jsName = standardVisitor._getJsClassName(classElement.name3!);
  final iifeVisitor = JsExpressionVisitor(allProxyClasses, allProxyEnums, iifeContextClassName: classElement.name3!);
  final classLibraryResult = await session.getResolvedLibraryByElement2(classElement.library2);
  if (classLibraryResult is! ResolvedLibraryResult) return;

  builder.writeIife(jsName, (iife) {
    var primaryCtor = classElement.constructors2.firstWhereOrNull(
      (c) => !c.isFactory && _normalizeConstructorName(c.name3).isEmpty,
    );
    final hasInstantiableConstructor = classElement.constructors2.any((c) => !c.isFactory);

    if (classElement.isAbstract && !hasInstantiableConstructor) {
      // no mainFactory
    } else if (primaryCtor != null) {
      _buildJsConstructor(
        iife,
        'mainFactory',
        primaryCtor,
        allProxyClasses,
        allProxyEnums,
        classLibraryResult,
        iifeVisitor,
        globalConstants,
        allConstructorAsts,
      );
    } else {
      iife.writeFunction(
        'mainFactory',
        [],
        (b) => b.writeLine('throw new Error("$jsName cannot be instantiated directly.");'),
      );
    }
    iife.blankLine();

    final classDeclaration =
        classLibraryResult.getFragmentDeclaration(classElement.firstFragment)?.node as ClassDeclaration?;
    if (classDeclaration == null) {
      iife.writeLine('// Could not find ClassDeclaration to process static members.');
    } else {
      final className = classElement.name3!;
      final membersToSkip = _membersToSkip[className] ?? const <String>{};
      final staticFields = classDeclaration.members.whereType<FieldDeclaration>().where((f) => f.isStatic);

      for (final member in staticFields) {
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          if (fieldName.startsWith('_') || membersToSkip.contains(fieldName)) continue;

          final constantKey = '$className.$fieldName';
          final resolvedValue = globalConstants[constantKey];

          if (resolvedValue != null) {
            if (resolvedValue is num || resolvedValue is bool || resolvedValue is String) {
              iife.writeLine(
                "const $fieldName = ${_evaluatedValueToJs(resolvedValue, iifeVisitor, allConstructorAsts)};",
              );
            }
          }
        }
      }

      final staticProperties = <String, String>{};

      for (final member in staticFields) {
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          if (fieldName.startsWith('_') || membersToSkip.contains(fieldName)) continue;

          final constantKey = '$className.$fieldName';
          final resolvedValue = globalConstants[constantKey];
          if (resolvedValue != null) {
            final jsValue = _evaluatedValueToJs(resolvedValue, iifeVisitor, allConstructorAsts);
            if (jsValue != 'null') {
              final accessor = hasInstantiableConstructor ? 'mainFactory' : 'exports';
              iife.writeLine("$accessor.$fieldName = $jsValue;");
              if (!hasInstantiableConstructor) {
                staticProperties[fieldName] = fieldName;
              }
            }
          } else if (variable.initializer != null) {
            final initializer = variable.initializer!;
            String? jsValue;

            if (initializer is InstanceCreationExpression) {
              jsValue = _tryInlineNonConstCreation(initializer, iifeVisitor, allProxyClasses);
            }

            jsValue ??= initializer.accept(iifeVisitor);

            if (jsValue != 'null') iife.writeLine("mainFactory.$fieldName = $jsValue;");
          }
        }
      }
      if (!hasInstantiableConstructor) {
        iife.writeLine("const exports = {};");
      }
    }

    for (final ctor in classElement.constructors2.where(
      (c) => c != primaryCtor && !c.isPrivate && _normalizeConstructorName(c.name3).isNotEmpty,
    )) {
      iife.blankLine();
      _buildJsConstructor(
        iife,
        'mainFactory.${ctor.name3}',
        ctor,
        allProxyClasses,
        allProxyEnums,
        classLibraryResult,
        iifeVisitor,
        globalConstants,
        allConstructorAsts,
      );
    }
    iife.blankLine();

    if (hasInstantiableConstructor) {
      iife.writeLine('return mainFactory;');
    } else {
      iife.writeLine('return exports;');
    }
  });
}

void _buildJsConstructor(
  JsCodeBuilder builder,
  String functionName,
  ConstructorElement2 ctor,
  List<ClassElement2> allProxyClasses,
  List<EnumElement2> allProxyEnums,
  ResolvedLibraryResult libraryResult,
  JsExpressionVisitor visitor,
  Map<String, dynamic> globalConstants,
  Map<ConstructorElement2, ConstructorDeclaration> allConstructorAsts,
) {
  final originalClassName = ctor.enclosingElement2.name3!;
  final membersToSkip = _membersToSkip[originalClassName] ?? const <String>{};
  final positionalParams = ctor.formalParameters
      .where((p) => p.isPositional && !membersToSkip.contains(p.name3))
      .map((p) => p.name3!)
      .toList();
  final namedParams = ctor.formalParameters.where((p) => p.isNamed && !membersToSkip.contains(p.name3)).toList();
  final allJsParams = namedParams.isNotEmpty ? [...positionalParams, 'options'] : positionalParams;

  builder.writeFunction(functionName, allJsParams, (body) {
    if (namedParams.isNotEmpty) {
      body.writeLine("const { ${namedParams.map((p) => p.name3!).join(', ')} } = options || {};");
    }

    final constructorNode = libraryResult.getFragmentDeclaration(ctor.firstFragment)?.node as ConstructorDeclaration?;
    if (constructorNode == null) {
      body.writeReturnObject({'// ERROR': "'Could not resolve constructor AST.'"});
      return;
    }

    if (constructorNode.factoryKeyword != null) {
      if (constructorNode.body is ExpressionFunctionBody) {
        final expr = (constructorNode.body as ExpressionFunctionBody).expression;
        body.writeLine('return ${expr.accept(visitor)};');
        return;
      }
      final returnStatement = constructorNode.body.childEntities
          .whereType<BlockFunctionBody>()
          .firstOrNull
          ?.block
          .statements
          .whereType<ReturnStatement>()
          .firstOrNull;
      if (returnStatement?.expression != null) {
        body.writeLine('return ${returnStatement!.expression!.accept(visitor)};');
        return;
      }
    } else if (constructorNode.initializers.firstOrNull is RedirectingConstructorInvocation) {
      final redirect = constructorNode.initializers.first as RedirectingConstructorInvocation;
      body.writeLine('return ${redirect.accept(visitor)};');
      return;
    }

    final publicClassName = visitor._getJsClassName(originalClassName);
    final returnObjectProperties = <String, String>{'_type': "'Script$publicClassName'"};
    final paramAstNodes = constructorNode.parameters.parameters;
    final resolvedParamExpressions = <String, String>{};
    for (final param in ctor.formalParameters) {
      if (membersToSkip.contains(param.name3)) continue;

      final paramName = param.name3!;
      final paramNode = paramAstNodes.firstWhereOrNull((p) => (p as dynamic).name?.lexeme == paramName);

      String jsParamExpression;
      if (paramNode is DefaultFormalParameter && paramNode.defaultValue != null) {
        final constantKey = _getConstantKeyFromExpression(paramNode.defaultValue);
        final constantValue = constantKey != null ? globalConstants[constantKey] : null;
        final jsDefault = constantValue != null
            ? _evaluatedValueToJs(constantValue, visitor, allConstructorAsts)
            : paramNode.defaultValue!.accept(visitor)!;
        jsParamExpression = "$paramName !== undefined ? $paramName : $jsDefault";
      } else {
        jsParamExpression = paramName;
      }
      resolvedParamExpressions[paramName] = jsParamExpression;

      if (param.isInitializingFormal) {
        returnObjectProperties[paramName] = jsParamExpression;
      }
    }

    for (final initializer in constructorNode.initializers.whereType<ConstructorFieldInitializer>()) {
      final fieldName = initializer.fieldName.name;
      final expression = initializer.expression;
      String? jsValue;

      if (expression is SimpleIdentifier && resolvedParamExpressions.containsKey(expression.name)) {
        jsValue = resolvedParamExpressions[expression.name];
      } else {
        jsValue = expression.accept(visitor);
      }

      if (jsValue != null) {
        returnObjectProperties[fieldName] = jsValue;
      }
    }

    body.writeReturnObject(returnObjectProperties);
  });
}

String? _tryInlineNonConstCreation(
  InstanceCreationExpression node,
  JsExpressionVisitor visitor,
  List<ClassElement2> allClasses,
) {
  final staticType = node.staticType;
  if (staticType is! InterfaceType) return null;

  final className = staticType.element3.name3;
  if (className == null || !_typesToInlineAggressively.contains(className)) {
    return null;
  }

  final classEl = allClasses.firstWhereOrNull((c) => c.name3 == className);
  if (classEl == null) return null;

  final constructorName = _normalizeConstructorName(node.constructorName.name?.name);
  final ctor = classEl.constructors2.firstWhereOrNull((c) => _normalizeConstructorName(c.name3) == constructorName);
  if (ctor == null) return null; // Could not find constructor to analyze

  final jsClassName = visitor._getJsClassName(className);
  final props = <String, String>{'_type': "'Script$jsClassName'"};

  final positionalArgs = node.argumentList.arguments.where((arg) => arg is! NamedExpression).toList();
  final namedArgs = node.argumentList.arguments.whereType<NamedExpression>().toList();
  int positionalIndex = 0;

  for (final param in ctor.formalParameters) {
    if (!param.isInitializingFormal) continue;
    final paramName = param.name3!;

    if (param.isPositional) {
      if (positionalIndex < positionalArgs.length) {
        final arg = positionalArgs[positionalIndex];
        props[paramName] = arg.accept(visitor) ?? 'null';
        positionalIndex++;
      }
    } else if (param.isNamed) {
      final arg = namedArgs.firstWhereOrNull((a) => a.name.label.name == paramName);
      if (arg != null) {
        props[paramName] = arg.expression.accept(visitor) ?? 'null';
      }
    }
  }

  final propsString = props.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  return '{ $propsString }';
}

String _normalizeConstructorName(String? name) {
  if (name == null || name.isEmpty || name == 'new') {
    return '';
  }
  return name;
}

String? _getConstantKeyFromExpression(Expression? exp) {
  if (exp is PrefixedIdentifier) {
    return '${exp.prefix.name}.${exp.identifier.name}';
  }
  if (exp is PropertyAccess) {
    final target = exp.target;
    if (target is SimpleIdentifier) {
      return '${target.name}.${exp.propertyName.name}';
    }
  }
  return null;
}

dynamic _evaluateConstantExpression(
  Expression? expression,
  Map<String, dynamic> knownValues,
  Set<String> typesToPrecalculate,
  Map<ConstructorElement2, ConstructorDeclaration> constructorAsts, {
  String? currentClassName,
}) {
  if (expression == null) return null;
  if (expression is IntegerLiteral) return expression.value;
  if (expression is DoubleLiteral) return expression.value;
  if (expression is BooleanLiteral) return expression.value;
  if (expression is StringLiteral) return expression.stringValue;
  if (expression is PrefixedIdentifier && expression.toSource() == 'double.infinity') return double.infinity;

  if (expression is SimpleIdentifier && currentClassName != null) {
    final selfKey = '$currentClassName.${expression.name}';
    if (knownValues.containsKey(selfKey)) return knownValues[selfKey];
    if (knownValues.containsKey(expression.name)) return knownValues[expression.name];
  }

  final constantKey = _getConstantKeyFromExpression(expression);
  if (constantKey != null && knownValues.containsKey(constantKey)) {
    return knownValues[constantKey];
  }

  if (expression is BinaryExpression) {
    final left = _evaluateConstantExpression(
      expression.leftOperand,
      knownValues,
      typesToPrecalculate,
      constructorAsts,
      currentClassName: currentClassName,
    );
    final right = _evaluateConstantExpression(
      expression.rightOperand,
      knownValues,
      typesToPrecalculate,
      constructorAsts,
      currentClassName: currentClassName,
    );
    if (left == null || right == null || left is! num || right is! num) return null;
    switch (expression.operator.type) {
      case TokenType.PLUS:
        return left + right;
      case TokenType.MINUS:
        return left - right;
      case TokenType.STAR:
        return left * right;
      case TokenType.SLASH:
        return left / right;
      default:
        return null;
    }
  }
  if (expression is InstanceCreationExpression) {
    final staticType = expression.staticType;
    if (staticType is! InterfaceType) return null;
    final className = staticType.element3.name3;
    if (className == null || !typesToPrecalculate.contains(className)) return null;

    final ctorElement = expression.constructorName.element;
    final ctorNode = ctorElement != null ? constructorAsts[ctorElement] : null;

    final positionalArgs = <dynamic>[];
    final namedArgs = <String, dynamic>{};
    bool canEvaluateAllArgs = true;

    for (final arg in expression.argumentList.arguments) {
      final argValue = _evaluateConstantExpression(
        arg is NamedExpression ? arg.expression : arg,
        knownValues,
        typesToPrecalculate,
        constructorAsts,
        currentClassName: currentClassName,
      );
      if (argValue == null) {
        canEvaluateAllArgs = false;
        break;
      }
      if (arg is NamedExpression) {
        namedArgs[arg.name.label.name] = argValue;
      } else {
        positionalArgs.add(argValue);
      }
    }
    if (!canEvaluateAllArgs) return null;

    if (ctorNode != null) {
      for (final param in ctorNode.parameters.parameters) {
        if (param is DefaultFormalParameter && param.defaultValue != null) {
          final paramName = param.name?.lexeme;
          if (paramName != null && !namedArgs.containsKey(paramName)) {
            final defaultValue = _evaluateConstantExpression(
              param.defaultValue,
              knownValues,
              typesToPrecalculate,
              constructorAsts,
              currentClassName: currentClassName,
            );
            if (defaultValue != null) namedArgs[paramName] = defaultValue;
          }
        }
      }
    }

    return {
      '__constructor__': true,
      'className': className,
      'constructorName': ctorElement?.name3,
      'positionalArgs': positionalArgs,
      'namedArgs': namedArgs,
    };
  }
  return null;
}

String _evaluatedValueToJs(
  dynamic value,
  JsExpressionVisitor visitor,
  Map<ConstructorElement2, ConstructorDeclaration> allConstructorAsts,
) {
  if (value == null) return 'null';
  if (value == double.infinity) return 'Infinity';
  if (value is String) return "'$value'";
  if (value is bool || value is num) return value.toString();

  if (value is Map && value['__constructor__'] == true) {
    final dartClassName = value['className'] as String;

    if (dartClassName == visitor._iifeContextClassName) {
      final constructorName = value['constructorName'] as String?;
      final isDefaultCtor = _normalizeConstructorName(constructorName).isEmpty;
      final functionName = isDefaultCtor ? 'mainFactory' : 'mainFactory.$constructorName';

      final positionalArgs = (value['positionalArgs'] as List)
          .map((a) => _evaluatedValueToJs(a, visitor, allConstructorAsts))
          .toList();
      final namedArgs = (value['namedArgs'] as Map<String, dynamic>).entries
          .map((e) => '${e.key}: ${_evaluatedValueToJs(e.value, visitor, allConstructorAsts)}')
          .toList();

      final jsArgs = <String>[];
      if (positionalArgs.isNotEmpty) jsArgs.add(positionalArgs.join(', '));
      if (namedArgs.isNotEmpty) jsArgs.add('{ ${namedArgs.join(', ')} }');

      return '$functionName(${jsArgs.join(', ')})';
    }

    final className = visitor.translateClassName(dartClassName);
    final positionalArgs = value['positionalArgs'] as List;
    final namedArgs = value['namedArgs'] as Map<String, dynamic>;

    final classEl = visitor._allClasses.firstWhereOrNull((c) => c.name3 == dartClassName);
    if (classEl == null) return "'<ERROR: Class $dartClassName not found>'";

    final constructorNameToFind = _normalizeConstructorName(value['constructorName'] as String?);
    final ctor = classEl.constructors2.firstWhereOrNull(
      (c) => _normalizeConstructorName(c.name3) == constructorNameToFind,
    );

    if (ctor == null) {
      final available = classEl.constructors2.map((c) => "'${_normalizeConstructorName(c.name3)}'").join(', ');
      print(
        "CRITICAL: Could not find constructor '$constructorNameToFind' for class '$dartClassName'. Available: [$available]",
      );
      return "'<ERROR: Constructor for $dartClassName not found>'";
    }

    final ctorNode = allConstructorAsts[ctor];
    if (ctorNode == null) {
      return "'<ERROR: Constructor AST for $dartClassName not found>'";
    }
    final paramNodesByName = {
      for (final p in ctorNode.parameters.parameters)
        if (p.name != null) p.name!.lexeme: p,
    };

    final props = <String, String>{'_type': "'Script$className'"};
    int positionalIndex = 0;
    for (final param in ctor.formalParameters) {
      final paramName = param.name3!;
      if (param.isPositional) {
        if (positionalIndex < positionalArgs.length) {
          props[paramName] = _evaluatedValueToJs(positionalArgs[positionalIndex], visitor, allConstructorAsts);
          positionalIndex++;
        }
      } else if (param.isNamed) {
        if (namedArgs.containsKey(paramName)) {
          props[paramName] = _evaluatedValueToJs(namedArgs[paramName], visitor, allConstructorAsts);
        } else {
          final paramNode = paramNodesByName[paramName];
          if (paramNode is DefaultFormalParameter && paramNode.defaultValue != null) {
            props[paramName] = paramNode.defaultValue!.accept(visitor)!;
          }
        }
      }
    }

    final propsString = props.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    return '{ $propsString }';
  }
  if (value is Expression) return value.accept(visitor) ?? value.toSource();
  return value.toString();
}
