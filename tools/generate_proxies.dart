import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/file_system.dart' as file_system;
import 'package:code_builder/code_builder.dart' as cb;
import 'package:collection/collection.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;

import 'generate_js_reconstructor.dart';
import 'generate_proxies_js.dart';
import 'generate_reconstructor.dart';

const String _inputLibraryPath = 'lib\\typesetting_prototype.dart';
const String _outputLibraryPath = 'lib/eval/script_stdlib.dart';

const Set<String> _methodsToSkip = {
  'toString',
  'hashCode',
  'runtimeType',
  'noSuchMethod',
  'createRenderNode',
  'resolve',
  'save',
};

const Map<String, Set<String>> _membersToSkip = {
  'PageFormat': {'copyWith', 'landscape', 'portrait', 'dimension', 'undefined', 'roll57', 'roll80'},
  'PageContext': {'settings', 'metadata', 'getMetadata'},
};

const Set<String> _typesToPrecalculate = {'PageFormat'};

const Map<String, String> _additionalRootClasses = {
  'Document': 'lib\\document\\document.dart',
  'FootnoteLayoutInfo': 'lib\\typesetting_prototype.dart',
  'TtfFont': 'lib\\text\\font.dart', //todo investigate why this isn't
  //added directly by being a subtype of Font
};

final Set<String> requiredImports = {};

void main() async {
  final stopwatch = Stopwatch()..start();
  print('Starting proxy generation...');

  final projectPath = Directory.current.path;
  final absoluteInputPath = p.join(projectPath, _inputLibraryPath);

  final collection = AnalysisContextCollection(includedPaths: [projectPath]);
  final session = collection.contextFor(absoluteInputPath).currentSession;

  final allProjectClasses = await _findAllProjectClasses(session);

  final initialClasses = <ClassElement2>[];

  final widgetClasses = await _findAllWidgetSubclasses(session);
  initialClasses.addAll(widgetClasses);
  print('Found ${widgetClasses.length} Widget classes.');

  for (final entry in _additionalRootClasses.entries) {
    final className = entry.key;
    final classPath = entry.value;
    final absoluteClassPath = p.join(projectPath, classPath);

    final classLibraryResult = await session.getResolvedLibrary(absoluteClassPath);

    if (classLibraryResult is! ResolvedLibraryResult) {
      print('WARNING: Could not resolve library for file "$classPath"');
      continue;
    }

    final classLibrary = classLibraryResult.element2;
    final classElement = classLibrary.getClass2(className);

    if (classElement != null) {
      print('Found additional root class: $className in $classPath');
      initialClasses.add(classElement);
    } else {
      print("WARNING: Could not find class '$className' in file '$classPath'");
    }
  }

  final allFoundElements = await _findDependentTypes(initialClasses, allProjectClasses, session);

  print('Resolving any name ambiguities...');
  final allElementsToProxy = _resolveAmbiguities(allFoundElements, session);

  final dataClasses = allElementsToProxy.whereType<ClassElement2>().toList()
    ..sort((a, b) => (a.name3 ?? '').compareTo(b.name3 ?? ''));
  final enumClasses = allElementsToProxy.whereType<EnumElement2>().toList()
    ..sort((a, b) => (a.name3 ?? '').compareTo(b.name3 ?? ''));
  print('Found ${dataClasses.length} total dependent data classes and ${enumClasses.length} enums.');

  final allProxyNames = <String?>{
    ...dataClasses.map((e) => e.name3),
    ...enumClasses.map((e) => e.name3),
  }.where((name) => name != null).cast<String>().toSet();

  final libraryBuilder = cb.LibraryBuilder();

  for (final enumElement in enumClasses) {
    libraryBuilder.body.add(_buildEnumProxy(enumElement));
  }

  final allProxyClasses = {
    ...initialClasses,
    ...dataClasses,
  }.toList().sorted((a, b) => (a.name3 ?? '').compareTo(b.name3 ?? ''));
  final generatedClasses = <String>{};

  for (final classElement in allProxyClasses) {
    final name = classElement.name3;
    if (name != null && !generatedClasses.contains(name)) {
      libraryBuilder.body.add(await _buildClassProxy(classElement, allProxyNames, session));
      generatedClasses.add(name);
    }
  }

  for (final importUri in requiredImports) {
    libraryBuilder.directives.add(cb.Directive.import(importUri));
  }

  final librarySpec = libraryBuilder.build();
  final emitter = cb.DartEmitter(useNullSafetySyntax: true, orderDirectives: true);
  final code = librarySpec.accept(emitter);

  final formatter = DartFormatter(languageVersion: DartFormatter.latestLanguageVersion);
  final formattedCode = formatter.format(code.toString());

  final header = _generateHeader();
  final finalContent = '$header\n\n$formattedCode';

  final outputFile = File(_outputLibraryPath);
  await outputFile.writeAsString(finalContent, flush: true);

  print('Generating reconstructor logic...');
  final reconstructorContent = generateReconstructorFile(dataClasses, enumClasses);
  final reconstructorFile = File('lib/eval/reconstructor_generated.dart');
  await reconstructorFile.writeAsString(reconstructorContent, flush: true);

  print('Successfully generated proxy library at $_outputLibraryPath');
  print('Successfully generated reconstructor library at ${reconstructorFile.path}');

  print('Generating JavaScript API library...');
  final jsApiContent = await generateJsApiFile(allProxyClasses, enumClasses, session, _membersToSkip);
  final jsApiFile = File('web/std_lib.js');
  await jsApiFile.writeAsString(jsApiContent, flush: true);
  print('Successfully generated JavaScript API library at ${jsApiFile.path}');

  print('Generating JavaScript reconstructor library...');
  final jsReconstructorContent = generateJsReconstructorFile(dataClasses, enumClasses);
  final jsReconstructorFile = File('lib/eval/js_reconstructor_generated.dart');
  await jsReconstructorFile.writeAsString(jsReconstructorContent, flush: true);
  print('Successfully generated JavaScript reconstructor library at ${jsReconstructorFile.path}');
  stopwatch.stop();
  print('Task completed in ${stopwatch.elapsed.inSeconds} seconds.');
}

Future<Set<InterfaceElement2>> _findDependentTypes(
  List<ClassElement2> initialClasses,
  List<ClassElement2> allProjectClasses,
  AnalysisSession session,
) async {
  final Set<InterfaceElement2> foundElements = {};
  final List<InterfaceElement2> queue = List.from(initialClasses);
  final Set<InterfaceElement2> processedElements = {};

  final projectPath = session.analysisContext.contextRoot.root.path;

  while (queue.isNotEmpty) {
    final currentElement = queue.removeAt(0);

    if (processedElements.contains(currentElement)) {
      continue;
    }

    final path = session.uriConverter.uriToPath(currentElement.library2.uri);
    if (path == null || !path.startsWith(projectPath)) {
      continue;
    }

    processedElements.add(currentElement);
    foundElements.add(currentElement);

    if (currentElement is! ClassElement2) continue;

    final classLibraryResult = await session.getResolvedLibraryByElement2(currentElement.library2);
    if (classLibraryResult is! ResolvedLibraryResult) continue;

    final visitor = _TypeFinderVisitor(queue, processedElements, session, projectPath);

    if (currentElement.isAbstract || currentElement.isSealed) {
      for (final potentialSubtype in allProjectClasses) {
        if (potentialSubtype.supertype?.element3 == currentElement) {
          if (!processedElements.contains(potentialSubtype)) {
            queue.add(potentialSubtype);
          }
        }
      }
    }

    final supertype = currentElement.supertype;
    if (supertype != null) {
      _collectTypes(supertype, queue, processedElements, session, projectPath);
    }

    for (final constructor in currentElement.constructors2) {
      for (final param in constructor.formalParameters) {
        _collectTypes(param.type, queue, processedElements, session, projectPath);
      }
      final declaration = classLibraryResult.getFragmentDeclaration(constructor.firstFragment);
      declaration?.node.accept(visitor);
    }

    for (final field in currentElement.fields2) {
      _collectTypes(field.type, queue, processedElements, session, projectPath);
      final declaration = classLibraryResult.getFragmentDeclaration(field.firstFragment);
      final initializer = (declaration?.node as VariableDeclaration?)?.initializer;
      initializer?.accept(visitor);
    }

    final executables = [...currentElement.methods2, ...currentElement.getters2, ...currentElement.setters2];

    for (final executable in executables) {
      if (executable.isPrivate || _methodsToSkip.contains(executable.name3)) {
        continue;
      }

      _collectTypes(executable.returnType, queue, processedElements, session, projectPath);
      for (final param in executable.formalParameters) {
        _collectTypes(param.type, queue, processedElements, session, projectPath);
      }

      final declaration = classLibraryResult.getFragmentDeclaration(executable.firstFragment);
      declaration?.node.accept(visitor);
    }
  }
  return foundElements;
}

void _collectTypes(
  DartType type,
  List<InterfaceElement2> queue,
  Set<InterfaceElement2> processedElements,
  AnalysisSession session,
  String projectPath,
) {
  if (type is FunctionType) {
    _collectTypes(type.returnType, queue, processedElements, session, projectPath);
    for (final parameter in type.formalParameters) {
      _collectTypes(parameter.type, queue, processedElements, session, projectPath);
    }
    return;
  }

  if (type is InterfaceType) {
    final element = type.element3;
    final uri = element.library2.uri;

    if (!uri.isScheme('dart')) {
      final path = session.uriConverter.uriToPath(uri);
      if (path != null && path.startsWith(projectPath)) {
        if (!processedElements.contains(element)) {
          queue.add(element);
        }
      }
    }
    for (final generic in type.typeArguments) {
      _collectTypes(generic, queue, processedElements, session, projectPath);
    }
  }
}

cb.Enum _buildEnumProxy(EnumElement2 enumElement) {
  final nativeName = enumElement.name3;
  if (nativeName == null || nativeName.startsWith('_')) return cb.Enum((b) {});

  return cb.Enum((b) {
    b.name = 'Script$nativeName';
    for (final field in enumElement.fields2) {
      if (field.isEnumConstant && field.name3 != null) {
        b.values.add(cb.EnumValue((v) => v.name = field.name3!));
      }
    }
  });
}

Future<cb.Class> _buildClassProxy(
  ClassElement2 classElement,
  Set<String> allProxyNames,
  AnalysisSession session,
) async {
  final nativeName = classElement.name3;
  if (nativeName == null) return cb.Class((b) {});

  final membersToSkipForThisClass = _membersToSkip[nativeName] ?? const <String>{};

  String proxyName;
  if (classElement.isPrivate) {
    if (!nativeName.startsWith('_')) return cb.Class((b) {});
    proxyName = 'Script${nativeName.substring(1)}';
  } else {
    proxyName = 'Script$nativeName';
  }

  final classLibraryResult = await session.getResolvedLibraryByElement2(classElement.library2);

  if (classLibraryResult is! ResolvedLibraryResult) {
    return cb.Class((b) => b.name = proxyName);
  }

  final classBuilder = cb.ClassBuilder()
    ..name = proxyName
    ..sealed = classElement.isSealed
    ..abstract = classElement.isAbstract && !classElement.isSealed;

  final supertype = classElement.supertype;
  if (supertype != null && !supertype.element3.library2.uri.isScheme('dart')) {
    var supertypeName = supertype.element3.name3 ?? '';
    if (supertypeName.startsWith('_')) {
      supertypeName = 'Script${supertypeName.substring(1)}';
    } else {
      supertypeName = 'Script$supertypeName';
    }
    classBuilder.extend = cb.refer(supertypeName);
  }

  final Map<String, dynamic> resolvedStaticValues = {};
  final List<VariableDeclaration> unresolvedStaticFields = [];

  final classDeclaration = classLibraryResult.getFragmentDeclaration(classElement.firstFragment)?.node;

  if (classDeclaration is ClassDeclaration) {
    for (final member in classDeclaration.members) {
      if (member is FieldDeclaration && member.isStatic && !member.fields.variables.first.name.lexeme.startsWith('_')) {
        for (final variable in member.fields.variables) {
          final fieldName = variable.name.lexeme;
          if (!membersToSkipForThisClass.contains(fieldName)) {
            unresolvedStaticFields.add(variable);
          }
        }
      }
    }

    int lastCount = -1;
    while (unresolvedStaticFields.isNotEmpty && unresolvedStaticFields.length != lastCount) {
      lastCount = unresolvedStaticFields.length;
      unresolvedStaticFields.removeWhere((variable) {
        final fieldName = variable.name.lexeme;
        final initializer = variable.initializer;

        final evaluatedValue = _evaluateConstantExpression(initializer, resolvedStaticValues, _typesToPrecalculate);

        if (evaluatedValue != null) {
          resolvedStaticValues[fieldName] = evaluatedValue;

          final fieldElement = classElement.getField2(fieldName);
          if (fieldElement == null) return true;

          final fieldType = fieldElement.type;
          final fieldTypeName = fieldType.element3?.name3;
          final isProxyableObject = fieldTypeName != null && allProxyNames.contains(fieldTypeName);
          final isPrimitive =
              fieldType.isDartCoreDouble ||
              fieldType.isDartCoreInt ||
              fieldType.isDartCoreBool ||
              fieldType.isDartCoreString;

          if (isProxyableObject || isPrimitive) {
            cb.Code assignmentCode;

            if (initializer is SimpleIdentifier) {
              assignmentCode = cb.Code(initializer.name);
            } else if (evaluatedValue is Map && evaluatedValue['__constructor__'] == true) {
              final String className = evaluatedValue['className'];
              final List<dynamic> posArgs = evaluatedValue['positionalArgs'];
              final posArgsStr = posArgs.map((v) => cb.literal(v).code).join(', ');
              assignmentCode = cb.Code('Script$className($posArgsStr)');
            } else {
              assignmentCode = cb.literal(evaluatedValue).code;
            }
            classBuilder.fields.add(
              cb.Field(
                (f) => f
                  ..name = fieldName
                  ..static = true
                  ..modifier = cb.FieldModifier.constant
                  ..type = _mapTypeToCodeBuilderType(fieldType, allProxyNames)
                  ..assignment = assignmentCode,
              ),
            );
          }
          return true;
        }
        return false;
      });
    }
  }

  for (final variable in unresolvedStaticFields) {
    final fieldName = variable.name.lexeme;
    final fieldElement = classElement.getField2(fieldName);
    final initializerSource = variable.initializer?.toSource();

    if (fieldElement != null && initializerSource != null) {
      classBuilder.fields.add(
        cb.Field(
          (f) => f
            ..name = fieldName
            ..static = true
            ..modifier = cb.FieldModifier.constant
            ..type = _mapTypeToCodeBuilderType(fieldElement.type, allProxyNames)
            ..assignment = cb.Code(_transformDefaultValue(initializerSource, allProxyNames)),
        ),
      );
    }
  }
  for (final field in classElement.fields2) {
    if (field.isStatic || field.isSynthetic) continue;
    final fieldName = field.name3;
    if (fieldName == null || membersToSkipForThisClass.contains(fieldName)) {
      continue;
    }

    final fieldBuilder = cb.FieldBuilder()
      ..name = fieldName
      ..type = _mapTypeToCodeBuilderType(field.type, allProxyNames, forceNullable: field.type.isNullable);

    if (field.isFinal) {
      fieldBuilder.modifier = cb.FieldModifier.final$;
    }

    final fieldLibraryResult = await session.getResolvedLibraryByElement2(field.library2);

    if (fieldLibraryResult is ResolvedLibraryResult) {
      final declaration = fieldLibraryResult.getFragmentDeclaration(field.firstFragment);

      AstNode? nodeWithInitializer;
      if (declaration?.node is VariableDeclaration) {
        nodeWithInitializer = declaration!.node;
      } else if (declaration?.node is FieldDeclaration) {
        final fieldDeclNode = declaration!.node as FieldDeclaration;
        nodeWithInitializer = fieldDeclNode.fields.variables.firstWhereOrNull((v) => v.name.lexeme == fieldName);
      }

      final initializer = (nodeWithInitializer as VariableDeclaration?)?.initializer;
      if (initializer != null) {
        final initializerCode = initializer.toSource();
        if (initializerCode != 'null') {
          fieldBuilder.assignment = cb.Code(_transformDefaultValue(initializerCode, allProxyNames));
        }
      }
    }

    classBuilder.fields.add(fieldBuilder.build());
  }

  final executables = [...classElement.methods2, ...classElement.getters2, ...classElement.setters2];

  for (final executable in executables) {
    final memberName = executable.name3;
    if (executable.isPrivate || executable.isSynthetic || memberName == null) continue;
    if (_methodsToSkip.contains(memberName) || membersToSkipForThisClass.contains(memberName)) {
      continue;
    }
    classBuilder.methods.add(_buildMethodProxy(executable, allProxyNames, classLibraryResult));
  }

  final constructors = classElement.constructors2.toList();

  if (constructors.isNotEmpty) {
    for (final constructor in constructors) {
      if (constructor.isFactory) {
        classBuilder.constructors.add(
          _buildFactoryConstructor(constructor, allProxyNames, classLibraryResult, nativeName),
        );
      } else {
        classBuilder.constructors.add(_buildConstructor(constructor, allProxyNames, classLibraryResult, nativeName));
      }
    }
  } else if (classElement.isAbstract) {
    classBuilder.constructors.add(cb.Constructor((c) => c..constant = true));
  }

  return classBuilder.build();
}

cb.Constructor _buildConstructor(
  ConstructorElement2 constructorElement,
  Set<String> allProxyNames,
  ResolvedLibraryResult libraryResult,
  String originalClassName,
) {
  final membersToSkipForThisClass = _membersToSkip[originalClassName] ?? const <String>{};

  return cb.Constructor((b) {
    b
      ..constant = constructorElement.isConst
      ..name =
          (constructorElement.name3 == null || constructorElement.name3!.isEmpty || constructorElement.name3 == "new")
          ? null
          : constructorElement.name3;

    for (final param in constructorElement.formalParameters) {
      final paramName = param.name3;
      if (paramName != null && membersToSkipForThisClass.contains(paramName)) {
        continue;
      }

      final parameter = cb.Parameter((p) {
        p
          ..name = param.name3!
          ..toThis = param.isInitializingFormal && param is! SuperFormalParameterElement2
          ..toSuper = param is SuperFormalParameterElement2
          ..required = param.isRequiredNamed
          ..named = param.isNamed;

        if (!param.isInitializingFormal) {
          p.type = _mapTypeToCodeBuilderType(param.type, allProxyNames);
        }

        if (param.hasDefaultValue && param.defaultValueCode != 'null') {
          String defaultValue = param.defaultValueCode!;
          if (param.type.isDartCoreDouble &&
              !defaultValue.contains('.') &&
              !defaultValue.contains('e') &&
              int.tryParse(defaultValue) != null) {
            defaultValue = '$defaultValue.0';
          }
          p.defaultTo = cb.Code(_transformDefaultValue(defaultValue, allProxyNames));
        }
      });

      if (param.isNamed) {
        b.optionalParameters.add(parameter);
      } else {
        b.requiredParameters.add(parameter);
      }
    }

    final declaration = libraryResult.getFragmentDeclaration(constructorElement.firstFragment);
    if (declaration?.node is! ConstructorDeclaration) {
      return;
    }
    final constructorNode = declaration!.node as ConstructorDeclaration;

    final Set<String> initializedByParameter = constructorElement.formalParameters
        .where((p) => p.isInitializingFormal)
        .map((p) => p.name3!)
        .toSet();

    for (final initializer in constructorNode.initializers) {
      bool shouldAdd = true;

      if (initializer is ConstructorFieldInitializer) {
        if (initializedByParameter.contains(initializer.fieldName.name)) {
          shouldAdd = false;
        }
      }

      if (shouldAdd) {
        final sourceCode = initializer.toSource();
        final transformedCode = _transformDefaultValue(sourceCode, allProxyNames);
        b.initializers.add(cb.Code(transformedCode));
      }
    }
  });
}

cb.Constructor _buildFactoryConstructor(
  ConstructorElement2 constructor,
  Set<String> allProxyNames,
  ResolvedLibraryResult libraryResult,
  String originalClassName,
) {
  final membersToSkipForThisClass = _membersToSkip[originalClassName] ?? const <String>{};

  return cb.Constructor((b) {
    b
      ..factory = true
      ..name = (constructor.name3 == null || constructor.name3!.isEmpty || constructor.name3 == "new")
          ? null
          : constructor.name3;

    for (final param in constructor.formalParameters) {
      final paramName = param.name3;
      if (paramName != null && membersToSkipForThisClass.contains(paramName)) {
        continue;
      }

      final parameter = cb.Parameter((p) {
        p
          ..name = param.name3!
          ..required = param.isRequiredNamed
          ..named = param.isNamed;

        p.type = _mapTypeToCodeBuilderType(param.type, allProxyNames);

        if (param.hasDefaultValue && param.defaultValueCode != 'null') {
          String defaultValue = param.defaultValueCode!;
          if (param.type.isDartCoreDouble &&
              !defaultValue.contains('.') &&
              !defaultValue.contains('e') &&
              int.tryParse(defaultValue) != null) {
            defaultValue = '$defaultValue.0';
          }
          p.defaultTo = cb.Code(_transformDefaultValue(defaultValue, allProxyNames));
        }
      });

      if (param.isNamed) {
        b.optionalParameters.add(parameter);
      } else {
        b.requiredParameters.add(parameter);
      }
    }

    final declaration = libraryResult.getFragmentDeclaration(constructor.firstFragment);
    if (declaration?.node is! ConstructorDeclaration) return;

    final constructorNode = declaration!.node as ConstructorDeclaration;

    if (constructorNode.redirectedConstructor != null) {
      final redirectSource = constructorNode.redirectedConstructor!.toSource();
      b.redirect = cb.refer(_transformDefaultValue(redirectSource, allProxyNames));
      return;
    }

    final body = constructorNode.body;

    if (body is ExpressionFunctionBody) {
      b.lambda = true;
      final expressionSource = body.expression.toSource();
      b.body = cb.Code(_transformDefaultValue(expressionSource, allProxyNames));
    } else if (body is BlockFunctionBody) {
      final blockSource = body.block.toSource();
      final statements = blockSource.substring(1, blockSource.length - 1).trim();
      b.body = cb.Code(_transformDefaultValue(statements, allProxyNames));
    } else if (body is EmptyFunctionBody) {}
  });
}

cb.Method _buildMethodProxy(
  ExecutableElement2 executable,
  Set<String> allProxyNames,
  ResolvedLibraryResult libraryResult,
) {
  final declaration = libraryResult.getFragmentDeclaration(executable.firstFragment);
  if (declaration?.node is! MethodDeclaration) {
    print('  - WARNING: Could not find MethodDeclaration for ${executable.name3}');
    return cb.Method((b) {});
  }
  final methodNode = declaration!.node as MethodDeclaration;

  return cb.Method((b) {
    b
      ..name = executable.name3
      ..static = executable.isStatic
      ..returns = _mapTypeToCodeBuilderType(executable.returnType, allProxyNames);

    for (final param in executable.typeParameters2) {
      b.types.add(
        cb.TypeReference((t) {
          t.symbol = param.name3;
          final bound = param.bound;
          if (bound != null && !bound.isDartCoreObject) {
            t.bound = _mapTypeToCodeBuilderType(bound, allProxyNames);
          }
        }),
      );
    }

    if (methodNode.isGetter) {
      b.type = cb.MethodType.getter;
    } else if (methodNode.isSetter) {
      b.type = cb.MethodType.setter;
    }

    for (final param in executable.formalParameters) {
      final parameter = cb.Parameter((p) {
        p
          ..name = param.name3!
          ..required = param.isRequiredNamed
          ..named = param.isNamed
          ..type = _mapTypeToCodeBuilderType(param.type, allProxyNames);

        if (param.hasDefaultValue && param.defaultValueCode != 'null') {
          String defaultValue = param.defaultValueCode!;
          if (param.type.isDartCoreDouble &&
              !defaultValue.contains('.') &&
              !defaultValue.contains('e') &&
              int.tryParse(defaultValue) != null) {
            defaultValue = '$defaultValue.0';
          }
          p.defaultTo = cb.Code(_transformDefaultValue(defaultValue, allProxyNames));
        }
      });

      if (param.isNamed) {
        b.optionalParameters.add(parameter);
      } else {
        b.requiredParameters.add(parameter);
      }
    }

    final body = methodNode.body;

    if (body is ExpressionFunctionBody) {
      b.lambda = true;
      final expressionSource = body.expression.toSource();
      b.body = cb.Code(_transformDefaultValue(expressionSource, allProxyNames));
    } else if (body is BlockFunctionBody) {
      final blockSource = body.block.toSource();
      final statements = blockSource.substring(1, blockSource.length - 1).trim();
      b.body = cb.Code(_transformDefaultValue(statements, allProxyNames));
    }
  });
}

cb.Reference _mapTypeToCodeBuilderType(DartType type, Set<String> allProxyNames, {bool forceNullable = false}) {
  final isNullable = forceNullable || type.nullabilitySuffix == NullabilitySuffix.question;

  if (type is FunctionType) {
    return cb.FunctionType((b) {
      b
        ..isNullable = isNullable
        ..returnType = _mapTypeToCodeBuilderType(type.returnType, allProxyNames);

      for (final param in type.formalParameters) {
        final paramType = _mapTypeToCodeBuilderType(param.type, allProxyNames);
        if (param.isNamed) {
          b.namedParameters[param.name3!] = paramType;
        } else if (param.isOptionalPositional) {
          b.optionalParameters.add(paramType);
        } else {
          b.requiredParameters.add(paramType);
        }
      }
    });
  }

  final element = type.element3;
  if (element == null || element.name3 == 'dynamic') return cb.refer('dynamic');

  if (element.isPrivate) {
    final supertype = (element as ClassElement2).supertype;
    if (supertype != null && !supertype.isDartCoreObject) {
      return _mapTypeToCodeBuilderType(supertype, allProxyNames, forceNullable: isNullable);
    }
  }

  final elementName = element.name3!;
  final libraryUri = element.library2!.uri;

  if (libraryUri.isScheme('dart')) {
    requiredImports.add(libraryUri.toString());
    return cb.TypeReference((b) {
      b
        ..symbol = elementName
        ..url = libraryUri.toString()
        ..isNullable = isNullable;

      if (type is InterfaceType) {
        b.types.addAll(type.typeArguments.map((t) => _mapTypeToCodeBuilderType(t, allProxyNames)));
      }
    });
  }

  final name = elementName;
  final finalName = allProxyNames.contains(name) ? 'Script$name' : name;

  return cb.TypeReference((b) {
    b
      ..symbol = finalName
      ..isNullable = isNullable;

    if (type is InterfaceType) {
      b.types.addAll(type.typeArguments.map((t) => _mapTypeToCodeBuilderType(t, allProxyNames)));
    }
  });
}

String _transformDefaultValue(String defaultValue, Set<String> proxyNames) {
  if (proxyNames.isEmpty) {
    return defaultValue;
  }

  final sortedNames = proxyNames.toList()..sort((a, b) => b.length.compareTo(a.length));

  final pattern = sortedNames.map((name) => RegExp.escape(name)).join('|');
  final regex = RegExp('(?<!Script)\\b($pattern)\\b');

  return defaultValue.replaceAllMapped(regex, (match) {
    final matchedName = match.group(1)!;

    if (matchedName.startsWith('_')) {
      return 'Script${matchedName.substring(1)}';
    } else {
      return 'Script$matchedName';
    }
  });
}

class _TypeFinderVisitor extends RecursiveAstVisitor<void> {
  final List<InterfaceElement2> queue;
  final Set<InterfaceElement2> processedElements;
  final AnalysisSession session;
  final String projectPath;

  _TypeFinderVisitor(this.queue, this.processedElements, this.session, this.projectPath);

  @override
  void visitNamedType(NamedType node) {
    final element = node.element2;
    if (element is InterfaceElement2) {
      _collectTypes(element.thisType, queue, processedElements, session, projectPath);
    }
    super.visitNamedType(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final element = node.prefix.element;
    if (element is InterfaceElement2) {
      _collectTypes(element.thisType, queue, processedElements, session, projectPath);
    }
    super.visitPrefixedIdentifier(node);
  }
}

String _generateHeader() {
  return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated by tool/generate_proxies.dart

// ignore_for_file: unused_field

''';
}

extension on DartType {
  bool get isNullable => nullabilitySuffix == NullabilitySuffix.question;
}

Set<InterfaceElement2> _resolveAmbiguities(Set<InterfaceElement2> elements, AnalysisSession session) {
  final projectPath = session.analysisContext.contextRoot.root.path;
  final uriConverter = session.uriConverter;

  final groupedByName = groupBy(elements, (e) => e.name3);
  final resolvedElements = <InterfaceElement2>{};

  groupedByName.forEach((name, elementList) {
    if (name == null || elementList.isEmpty) return;

    if (elementList.length == 1) {
      resolvedElements.add(elementList.first);
    } else {
      final localCandidates = elementList.where((e) {
        final path = uriConverter.uriToPath(e.library2.uri);
        return path != null && path.startsWith(projectPath);
      }).toList();

      if (localCandidates.length == 1) {
        final localElement = localCandidates.first;
        print('  - Resolving ambiguity for "$name": Prioritizing local version from ${localElement.library2.uri}');
        resolvedElements.add(localElement);
      } else if (localCandidates.isEmpty) {
        print(
          '  - WARNING: Ambiguity for "$name" could not be resolved between external packages. Skipping proxy generation. Candidates: ${elementList.map((e) => e.library2.uri).join(', ')}',
        );
      } else {
        print(
          '  - WARNING: Ambiguity for "$name" exists within your own project files. Skipping proxy generation. Candidates: ${localCandidates.map((e) => e.library2.uri).join(', ')}',
        );
      }
    }
  });

  return resolvedElements;
}

dynamic _evaluateConstantExpression(
  Expression? expression,
  Map<String, dynamic> knownValues,
  Set<String> typesToPrecalculate,
) {
  if (expression == null) {
    return null;
  }

  if (expression is IntegerLiteral) return expression.value;
  if (expression is DoubleLiteral) return expression.value;
  if (expression is BooleanLiteral) return expression.value;
  if (expression is StringLiteral) return expression.stringValue;
  if (expression is PrefixedIdentifier && expression.toSource() == 'double.infinity') {
    return double.infinity;
  }

  if (expression is SimpleIdentifier) {
    if (knownValues.containsKey(expression.name)) {
      return knownValues[expression.name];
    }
  }

  if (expression is BinaryExpression) {
    final left = _evaluateConstantExpression(expression.leftOperand, knownValues, typesToPrecalculate);
    final right = _evaluateConstantExpression(expression.rightOperand, knownValues, typesToPrecalculate);

    if (left == null || right == null || left is! num || right is! num) {
      return null;
    }

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
    if (className == null || !typesToPrecalculate.contains(className)) {
      return null;
    }
    final positionalArgs = <dynamic>[];
    final namedArgs = <String, dynamic>{};
    bool canEvaluateAllArgs = true;

    for (final arg in expression.argumentList.arguments) {
      final argValue = _evaluateConstantExpression(
        arg is NamedExpression ? arg.expression : arg,
        knownValues,
        typesToPrecalculate,
      );

      if (argValue == null) {
        canEvaluateAllArgs = false;
        break;
      }

      final valueToStore = argValue is Map && argValue['__constructor__'] == true
          ? argValue['positionalArgs'].first
          : argValue;

      if (arg is NamedExpression) {
        namedArgs[arg.name.label.name] = valueToStore;
      } else {
        positionalArgs.add(valueToStore);
      }
    }

    if (canEvaluateAllArgs) {
      return {
        '__constructor__': true,
        'className': className,
        'constructorName': expression.constructorName.name?.name,
        'positionalArgs': positionalArgs,
        'namedArgs': namedArgs,
      };
    }
  }

  return null;
}

Future<List<ClassElement2>> _findAllWidgetSubclasses(AnalysisSession session) async {
  final projectPath = session.analysisContext.contextRoot.root.path;
  final libFolder = session.resourceProvider.getFolder(p.join(projectPath, 'lib'));
  final allWidgetClasses = <ClassElement2>[];

  Future<void> findDartFiles(file_system.Folder folder) async {
    final children = folder.getChildren();
    for (final child in children) {
      if (child is file_system.Folder) {
        await findDartFiles(child);
      } else if (child is file_system.File && child.path.endsWith('.dart')) {
        final filePath = child.path;
        final libraryResult = await session.getResolvedLibrary(filePath);
        if (libraryResult is ResolvedLibraryResult) {
          final libraryElement = libraryResult.element2;
          for (final classElement in libraryElement.classes) {
            if (!classElement.isAbstract && classElement.allSupertypes.any((type) => type.element3.name3 == 'Widget')) {
              if (!allWidgetClasses.any((existing) => existing.name3 == classElement.name3)) {
                allWidgetClasses.add(classElement);
              }
            }
          }
        }
      }
    }
  }

  await findDartFiles(libFolder);

  return allWidgetClasses;
}

Future<List<ClassElement2>> _findAllProjectClasses(AnalysisSession session) async {
  print('Scanning project for all class definitions...');
  final projectPath = session.analysisContext.contextRoot.root.path;
  final libFolder = session.resourceProvider.getFolder(p.join(projectPath, 'lib'));
  final allProjectClasses = <ClassElement2>[];
  final seenClassNames = <String>{};

  Future<void> findDartFiles(file_system.Folder folder) async {
    try {
      final children = folder.getChildren();
      for (final child in children) {
        if (child is file_system.Folder) {
          await findDartFiles(child);
        } else if (child is file_system.File && child.path.endsWith('.dart')) {
          final filePath = child.path;
          final libraryResult = await session.getResolvedLibrary(filePath);
          if (libraryResult is ResolvedLibraryResult) {
            final libraryElement = libraryResult.element2;
            for (final classElement in libraryElement.classes) {
              final name = classElement.name3;
              if (name != null && seenClassNames.add(name)) {
                allProjectClasses.add(classElement);
              }
            }
          }
        }
      }
    } catch (e) {
      print('  - Warning: Could not read children of folder ${folder.path}: $e');
    }
  }

  await findDartFiles(libFolder);
  print('Found ${allProjectClasses.length} total classes in the project.');
  return allProjectClasses;
}
