import 'package:petitparser/petitparser.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart';


class ScriptEngine {
  final Parser _parser;
  final Evaluator _evaluator;

  ScriptEngine()
      : _parser = TypesettingGrammar().build(),
        _evaluator = Evaluator();

  Widget parseAndBuild(String scriptText, Map<String, dynamic> initialData) {
    final result = _parse(scriptText);
    final context = _createContext(initialData);
    
    final dynamic scriptResult = _evaluator.visit(result.value, context);
    
    return _evaluator.normalizeToWidget(scriptResult);
  }

  ScriptExecutionResult parseAndBuildDocument(String scriptText, Map<String, dynamic> initialData) {
    final result = _parse(scriptText);
    final context = _createContext(initialData);
    
    dynamic scriptResult;
    
    if (result.value is MarkupBlockNode) {
      scriptResult = _evaluator.processList((result.value as MarkupBlockNode).children, context);
    } else {
      scriptResult = _evaluator.visit(result.value, context);
    }
    
    final Widget bodyWidget = _evaluator.normalizeToWidget(scriptResult);

    final pageConfigObj = context.getVariable('__config_page');
    
    PageFormat format = PageFormat.a4;
    EdgeInsets margin = const EdgeInsets.all(30);
    
    if (pageConfigObj != null && pageConfigObj.rawValue is Map) {
      final config = pageConfigObj.rawValue as Map<String, dynamic>;
      format = Evaluator._resolvePageFormat(config);
      margin = Evaluator._resolvePageMargin(config);
    }

    final doc = Document(
      pageFormat: format,
      pageMargin: margin,
      body: PageLayout(
        body: [bodyWidget], 
      ),
    );

    return ScriptExecutionResult(doc, context);
  }

  Result checkSyntax(String text) {
    return _parser.parse(text);
  }

  dynamic analyze(String text) {
    try {
      final result = _parser.parse(text);
      
      if (result is Failure) {
        return ScriptException(
          "Syntax Error: ${result.message}", 
          result.position, 
          1 // Highlights 1 char
        );
      }

      final context = _createContext({});
      // Mock print
      context.setVariable('print', ScriptFunction.native((pos, named, ctx) => null));

      if (result.value is MarkupBlockNode) {
        _evaluator.processList((result.value as MarkupBlockNode).children, context);
      } else {
        _evaluator.visit(result.value, context);
      }
      
      return null;
    } on ScriptException catch (e) {
      return e;
    } catch (e) {
      return e.toString();
    }
  }

  Result _parse(String text) {
    final result = _parser.parse(text);
    if (result is Failure) {
      final start = (result.position - 40).clamp(0, text.length);
      final end = (result.position + 40).clamp(0, text.length);
      final snippet = text.substring(start, end).replaceAll('\n', ' ');
      throw Exception('Script parsing failed at line ${result.toPositionString()}.\nError: ${result.message}\nContext: "...$snippet..."');
    }
    return result;
  }

  ExecutionContext _createContext(Map<String, dynamic> data) {
    final ctx = ExecutionContext();
    Evaluator.standardLibrary.forEach((key, value) => ctx.setVariable(key, value));
    data.forEach((key, value) {
      ctx.setVariable(key, value is ScriptObject ? value : ScriptValue(value));
    });
    return ctx;
  }
}

class ScriptExecutionResult {
  final Document document;
  final ExecutionContext context;

  ScriptExecutionResult(this.document, this.context);
}

// --- AST NODES ---

abstract class ScriptNode {
  int offset = 0;
  int length = 0;
}

class TextLiteralNode extends ScriptNode {
  final String text;
  TextLiteralNode(this.text);
}

class LiteralNode extends ScriptNode {
  final dynamic value;
  LiteralNode(this.value);
}

class MapNode extends ScriptNode {
  final Map<String, ScriptNode> entries;
  MapNode(this.entries);
}

class RangeNode extends ScriptNode {
  final ScriptNode left;
  final ScriptNode right;
  final bool inclusive;
  RangeNode(this.left, this.right, this.inclusive);
}

class BinaryOpNode extends ScriptNode {
  final ScriptNode left;
  final String operator;
  final ScriptNode right;
  BinaryOpNode(this.left, this.operator, this.right);
}

class LetBindingNode extends ScriptNode {
  final String name;
  final ScriptNode expression;
  LetBindingNode(this.name, this.expression);
}

class SetContextNode extends ScriptNode {
  final String target;
  final Map<String, ScriptNode> arguments;
  SetContextNode(this.target, this.arguments);
}

class FunctionDefinitionNode extends ScriptNode {
  final List<String> params;
  final ScriptNode body;
  FunctionDefinitionNode(this.params, this.body);
}

class IdentifierNode extends ScriptNode {
  final String name;
  IdentifierNode(this.name);
}

class PropertyAccessNode extends ScriptNode {
  final ScriptNode target;
  final String propertyName;
  PropertyAccessNode(this.target, this.propertyName);
}

class FunctionCallNode extends ScriptNode {
  final ScriptNode callee;
  final List<ScriptNode> positionalArgs;
  final Map<String, ScriptNode> namedArgs;
  
  FunctionCallNode(this.callee, this.positionalArgs, this.namedArgs);
}

class SpreadArgumentNode extends ScriptNode {
  final ScriptNode expression;
  SpreadArgumentNode(this.expression);
}

class IfExpressionNode extends ScriptNode {
  final ScriptNode condition;
  final ScriptNode thenBlock;
  final ScriptNode? elseBlock;
  IfExpressionNode(this.condition, this.thenBlock, this.elseBlock);
}

class ForLoopNode extends ScriptNode {
  final List<String> itemNames;
  final ScriptNode collection;
  final ScriptNode body;
  ForLoopNode(this.itemNames, this.collection, this.body);
}

class CodeBlockNode extends ScriptNode {
  final List<ScriptNode> statements;
  CodeBlockNode(this.statements);
}

class MarkupBlockNode extends ScriptNode {
  final List<ScriptNode> children;
  MarkupBlockNode(this.children);
}

class ListNode extends ScriptNode {
  final List<ScriptNode> elements;
  ListNode(this.elements);
}

// --- PARSER DEFINITION ---

class TypesettingGrammar extends GrammarDefinition {
  static const Set<String> keywords = {'if', 'else', 'for', 'in', 'let', 'set', 'true', 'false', 'null'};

  @override
  Parser start() => ref0(markupDocument).end();

  // --- MARKUP MODE ---

  Parser markupDocument() => ref0(markupContent).map((nodes) => MarkupBlockNode(nodes.cast<ScriptNode>()));

  Parser markupContent() => (
    ref0(codeInterpolation) | 
    ref0(paragraphBreak) | 
    ref0(implicitText)
  ).star();

  Parser paragraphBreak() => (char('\n') & char('\n').plus()).map((_) {
    return FunctionCallNode(
      IdentifierNode('SizedBox'), 
      [], 
      {'height': LiteralNode(12.0)}
    );
  });

  Parser implicitText() => _ImplicitTextParser().map((raw) {
    return TextLiteralNode(raw.replaceAll(RegExp(r'\s*\n\s*'), ' '));
  });

  // --- CODE MODE ---

  Parser codeInterpolation() => (char('#').trim() & ref0(expression)).pick(1).cast<ScriptNode>();

  // Expressions (with precedence)
  Parser expression() => ref0(ternary);

  Parser ternary() => (ref0(logicOr) & (char('?').trim() & ref0(expression) & char(':').trim() & ref0(expression)).optional()).map((v) {
    final condition = v[0] as ScriptNode;
    final rest = v[1] as List?;
    if (rest == null) return condition;
    return IfExpressionNode(condition, rest[1] as ScriptNode, rest[3] as ScriptNode);
  });

  Parser logicOr() => (ref0(logicAnd) & (string('||').trim() & ref0(logicAnd)).star()).map(_buildBinary);
  Parser logicAnd() => (ref0(equality) & (string('&&').trim() & ref0(equality)).star()).map(_buildBinary);
  Parser equality() => (ref0(relational) & ((string('==') | string('!=')).trim() & ref0(relational)).star()).map(_buildBinary);
  Parser relational() => (ref0(range) & ((string('<=') | string('>=') | char('<') | char('>')).trim() & ref0(range)).star()).map(_buildBinary);

  // Range: 0..10 or 0...10
  Parser range() => (ref0(additive) & ((string('...').trim() | string('..').trim()) & ref0(additive)).optional()).map((v) {
    final left = v[0] as ScriptNode;
    final suffix = v[1] as List?;
    if (suffix != null) {
      final op = suffix[0] as String;
      final right = suffix[1] as ScriptNode;
      return RangeNode(left, right, op == '...'); 
    }
    return left;
  });

  Parser additive() => (ref0(multiplicative) & ((char('+') | char('-')).trim() & ref0(multiplicative)).star()).map(_buildBinary);
  Parser multiplicative() => (ref0(prefix) & ((char('*') | char('/') | char('%')).trim() & ref0(prefix)).star()).map(_buildBinary);

  Parser prefix() => (char('!').trim() & ref0(prefix)).map((v) => FunctionCallNode(IdentifierNode('!'), [v[1] as ScriptNode], {}))
      | ref0(primary);

  ScriptNode _buildBinary(dynamic v) {
    var result = v[0] as ScriptNode;
    final rest = v[1] as List;
    for (final item in rest) {
      final op = item[0] as String;
      final right = item[1] as ScriptNode;
      result = BinaryOpNode(result, op, right);
    }
    return result;
  }

  // Primary Expressions
  Parser primary() => 
      (char('#').trim().optional() & (
        ref0(ifExpression) | 
        ref0(letBinding) | 
        ref0(setContext) |
        ref0(forLoop) | 
        ref0(functionDefinition) | 
        ref0(expressionChain) 
      )).pick(1);

  // --- CONTROL FLOW ---

  //  { } (last value), ( ) (all values), or (. .) (markup)
  Parser ifExpression() {
    final body = ref0(codeBlock) | ref0(parenthesizedList) | ref0(markupBlock);
    
    return (
      string('if').trim() & 
      char('(').trim() & ref0(expression) & char(')').trim() & 
      body & 
      (string('else').trim() & body).optional()
    ).map((v) {
      final condition = v[2] as ScriptNode;
      final thenBlock = v[4] as ScriptNode;
      final elseBlock = v[5] != null ? (v[5] as List)[1] as ScriptNode : null;
      return IfExpressionNode(condition, thenBlock, elseBlock); 
    });
  }

  // --- LOOPS ---

  Parser forLoop() {
    final vars = ref0(identifierToken).starSeparated(char(',').trim()).map((l) {
      return l.elements.map((e) => (e as IdentifierNode).name).toList();
    });

    // Body can be Markup (. .), List ( ), or Code { }
    final body = ref0(markupBlock) | ref0(parenthesizedList) | ref0(codeBlock);

    return (string('for').trim() & vars & string('in').trim() & ref0(expression) & body)
      .map((v) => ForLoopNode(v[1] as List<String>, v[3] as ScriptNode, v[4] as ScriptNode));
  }

  // --- EXPRESSION CHAIN ---

  Parser expressionChain() => (ref0(atomic) & ref0(suffix).star()).map((v) {
    var result = v[0] as ScriptNode;
    final suffixes = v[1] as List;

    for (final suffix in suffixes) {
      if (suffix is String) {
        result = PropertyAccessNode(result, suffix);
      } else if (suffix is Map) {
        if (suffix.containsKey('index')) {
          final indexExpr = suffix['index'] as ScriptNode;
          result = FunctionCallNode(result, [indexExpr], {'__is_index_access': LiteralNode(true)});
        } else {
          final pos = (suffix['pos'] as List).cast<ScriptNode>().toList();
          final named = suffix['named'] as Map<String, ScriptNode>;
          result = FunctionCallNode(result, pos, named);
        }
      }
    }
    return result;
  }).trim(); 

  Parser atomic() => 
      ref0(literal) | 
      ref0(mapLiteral) | 
      ref0(arrayLiteral) |   // [ ... ]
      ref0(codeBlock) |      // { ... }
      ref0(markupBlock) |    // (. ... .)
      ref0(parenthesizedList) | // ( ... )
      ref0(identifierNode); 

    Parser identifierNode() => ref0(strictIdentifier)
      .token()
      .where((t) => !keywords.contains(t.value), message: 'Keyword used as identifier')
      .map((t) {
        final node = IdentifierNode(t.value);
        node.offset = t.start;
        node.length = t.stop - t.start;
        return node;
      });

  Parser suffix() => 
      ref0(dotProperty) | 
      ref0(bracketAccess) |
      ref0(explicitCall) | 
      ref0(sugarCall);

  Parser dotProperty() => (char('.') & ref0(strictIdentifier)).pick(1);

  Parser bracketAccess() => (char('[') & ref0(expression) & char(']')).map((v) {
    return {'index': v[1]};
  });

  Parser explicitCall() => (char('(') & ref0(argumentList) & char(')')).pick(1);

  // #widget(. content .)
  Parser sugarCall() => ref0(strictMarkupBlock).map((block) {
    return {'pos': [block], 'named': <String, ScriptNode>{}};
  });

  // --- ARGUMENTS & COLLECTIONS ---

  Parser argumentList() => ref0(argument).starSeparated(char(',').trim().optional()).map((v) {
    final separated = v as SeparatedList;
    return _splitArgs(separated.elements);
  });

  Map<String, dynamic> _splitArgs(List<dynamic> list) {
    final pos = <ScriptNode>[];
    final named = <String, ScriptNode>{};
    for (var item in list) {
      if (item is MapEntry<String, ScriptNode>) {
        named[item.key] = item.value;
      } else {
        pos.add(item as ScriptNode);
      }
    }
    return {'pos': pos, 'named': named};
  }

  Parser argument() {
    final spread = (string('...') & ref0(expression))
        .map((v) => SpreadArgumentNode(v[1] as ScriptNode));

    final named = (ref0(identifierToken) & (char(':') | char('=')).trim() & ref0(expression))
        .map((v) => MapEntry((v[0] as IdentifierNode).name, v[2] as ScriptNode));
        
    return spread | named | ref0(expression);
  }

  // ( a, b ) OR ( WidgetA WidgetB )
  // Allows optional commas
  Parser parenthesizedList() => (
      char('(').trim() & 
      ref0(expression).starSeparated(char(',').trim().optional()) & 
      char(')').trim()
    ).map((v) {
       final separated = v[1] as SeparatedList;
       // Always return ListNode, it's a container block
       return ListNode(separated.elements.cast<ScriptNode>());
    });

  // Array Literal: [ 1, 2 ] - Requires Commas
  Parser arrayLiteral() => (
    char('[').trim() & 
    ref0(expression).starSeparated(char(',').trim()) & 
    char(']').trim()
  ).map((v) {
     final list = v[1] as SeparatedList;
     return ListNode(list.elements.cast<ScriptNode>());
  });

  // Map literal: { key: value }
  Parser mapLiteral() => (
    char('{').trim() & 
    ref0(mapEntry).starSeparated(char(',').trim()) & 
    char('}').trim()
  ).map((v) {
    final entries = <String, ScriptNode>{};
    final list = v[1] as SeparatedList;
    for (final entry in list.elements) {
      final e = entry as MapEntry<String, ScriptNode>;
      entries[e.key] = e.value;
    }
    return MapNode(entries);
  });

  Parser mapEntry() => (
    (ref0(stringLiteralNode) | ref0(identifierNode)) & 
    char(':').trim() & 
    ref0(expression)
  ).map((v) {
    String key;
    if (v[0] is LiteralNode) key = (v[0] as LiteralNode).value.toString();
    else key = (v[0] as IdentifierNode).name;
    return MapEntry(key, v[2] as ScriptNode);
  });

  // --- DEFINITIONS ---

  Parser letBinding() => (string('let').trim() & ref0(identifierToken) & char('=').trim() & ref0(expression))
      .map((v) => LetBindingNode((v[1] as IdentifierNode).name, v[3] as ScriptNode));

  Parser setContext() => (string('set').trim() & ref0(identifierToken) & char('(').trim() & ref0(argumentList) & char(')'))
      .map((v) {
        final target = (v[1] as IdentifierNode).name;
        final argsRaw = v[3] as Map;
        return SetContextNode(target, argsRaw['named'] as Map<String, ScriptNode>);
      });

  Parser functionDefinition() {
    final paramPrefix = string('**') | char('*');
    final paramName = (paramPrefix.optional() & ref0(identifierToken)).map((v) {
       final prefix = v[0] as String?;
       final name = (v[1] as IdentifierNode).name;
       return prefix != null ? '$prefix$name' : name;
    });

    final paramList = (char('(').trim() & 
        paramName.starSeparated(char(',').trim()) & 
        char(')').trim()).map((v) {
          final separated = v[1] as SeparatedList;
          return separated.elements.cast<String>().toList();
        });
    
    // Body can be { ... } (Logic) or ( ... ) (Layout List)
    final body = ref0(codeBlock) | ref0(parenthesizedList);

    return (paramList & string('=>').trim() & body) 
        .map((v) => FunctionDefinitionNode(v[0] as List<String>, v[2] as ScriptNode));
  }

  // --- HELPERS ---

  Parser identifierToken() => 
    (letter() & word().star())
      .flatten()
      .trim()
      .token()
      .map((t) {
        final node = IdentifierNode(t.value);
        node.offset = t.start;
        node.length = t.stop - t.start;
        return node;
      }
  );

  Parser strictIdentifier() => (letter() & word().star()).flatten();

  // --- BLOCKS & LITERALS ---

  Parser codeBlock() => (char('{').trim() & ref0(expression).star() & char('}').trim())
      .map((v) => CodeBlockNode((v[1] as List).cast<ScriptNode>()));

  // MARKUP BLOCK SYNTAX: (. ... .)
  Parser markupBlock() => (string('(.').trim() & ref0(markupDocument) & string('.)'))
      .map((v) => v[1]); 

  Parser strictMarkupBlock() => (string('(.') & ref0(markupDocument) & string('.)'))
      .map((v) => v[1]); 

  Parser literal() => (ref0(numberLiteral) | ref0(stringLiteralNode));
  Parser numberLiteral() => digit().plus().seq(char('.').seq(digit().plus()).optional()).flatten().map((v) => LiteralNode(num.parse(v)));
  
  Parser stringLiteral() => 
    (char('"') & pattern('^"').star().flatten() & char('"')).map((v) => v[1]) |
    (char("'") & pattern("^'").star().flatten() & char("'")).map((v) => v[1]);

  Parser stringLiteralNode() => stringLiteral().map((v) => LiteralNode(v));
}

// --- TEXT PARSER ---

class _ImplicitTextParser extends Parser<String> {
  @override
  Result<String> parseOn(Context context) {
    final buffer = context.buffer;
    final end = buffer.length;
    var pos = context.position;

    // Check if we are starting on a control sequence
    if (pos < end) {
      if (buffer[pos] == '#') return context.failure('Control character');
      // Check for closing delimiter ".)"
      if (buffer[pos] == '.' && pos + 1 < end && buffer[pos + 1] == ')') {
        return context.failure('End of markup block');
      }
    }

    final start = pos;
    while (pos < end) {
      final c = buffer[pos];
      
      // Stop at interpolation
      if (c == '#') break;
      
      // Stop at end of markup block ".)"
      if (c == '.' && pos + 1 < end && buffer[pos + 1] == ')') break;

      if (c == '\n' && pos + 1 < end && buffer[pos + 1] == '\n') break; 
      pos++;
    }

    if (pos == start) return context.failure('No text consumed');
    return context.success(buffer.substring(start, pos), pos);
  }
  @override
  _ImplicitTextParser copy() => _ImplicitTextParser();
}

// --- EXECUTION CONTEXT ---
class ExecutionContext {
  final Map<String, ScriptObject> _variables = {};
  final ExecutionContext? parent;
  ExecutionContext({this.parent});
  ExecutionContext createChildScope() => ExecutionContext(parent: this);
  
  void setVariable(String name, ScriptObject value) => _variables[name] = value;
  
  bool hasVariable(String name) {
    if (_variables.containsKey(name)) return true;
    if (parent != null) return parent!.hasVariable(name);
    return false;
  }

  ScriptObject? getVariable(String name) {
    if (_variables.containsKey(name)) return _variables[name];
    if (parent != null) return parent!.getVariable(name);
    return null;
  }
}

// --- OBJECT SYSTEM ---
abstract class ScriptObject {
  dynamic get rawValue;
}

class ScriptValue extends ScriptObject {
  final dynamic value;
  ScriptValue(this.value);
  @override
  dynamic get rawValue => value;
  @override
  String toString() => value.toString();
}

typedef ScriptNativeCallback = dynamic Function(List<dynamic> positional, Map<Symbol, dynamic> named, ExecutionContext context);

class ScriptFunction extends ScriptObject {
  final List<String>? parameters;
  final ScriptNode? body;
  final ScriptNativeCallback? nativeHandler;

  ScriptFunction.user(this.parameters, this.body) : nativeHandler = null;
  ScriptFunction.native(this.nativeHandler) : parameters = null, body = null;
  
  @override
  dynamic get rawValue => this;
}

// --- EVALUATOR ---

class Evaluator {
  static double? _toDouble(num? n) => n?.toDouble();

  // --- HELPERS ---

  static Widget _asWidget(dynamic item) {
    if (item == null) return const SizedBox.shrink();
    if (item is Widget) return item;
    if (item is ScriptObject) return _asWidget(item.rawValue);
    if (item is List) {
      final widgets = item.whereType<Widget>().toList();
      if (widgets.isEmpty) return const SizedBox.shrink();
      if (widgets.length == 1) return widgets.first;
      return Flow(children: widgets);
    }
    return Text(item.toString());
  }

  static dynamic _unwrap(dynamic item) {
    if (item is ScriptObject) return item.rawValue;
    return item;
  }

  static List<Widget> _extractChildren(List<dynamic> pos, Map<Symbol, dynamic> named) {
    if (named.containsKey(#children)) {
      return _asList(named[#children]);
    }
    if (pos.length == 1 && _unwrap(pos[0]) is List) {
      return _asList(pos[0]);
    }
    return pos.map((e) => _asWidget(e)).toList();
  }

  static Widget _extractChild(List<dynamic> pos, Map<Symbol, dynamic> named) {
    if (named.containsKey(#child)) {
      return _asWidget(named[#child]);
    }
    if (pos.isNotEmpty) {
      return _asWidget(pos[0]);
    }
    return const SizedBox.shrink();
  }
  
  static List<Widget> _asList(dynamic item) {
    final unwrapped = _unwrap(item);
    if (unwrapped == null) return [];
    if (unwrapped is List) {
      return unwrapped.map((e) => _asWidget(e)).toList();
    }
    if (unwrapped is Widget) return [unwrapped];
    return [Text(unwrapped.toString())];
  }

  static Map<String, dynamic> _mergeSettings(String key, Map<Symbol, dynamic> named, ExecutionContext ctx) {
    final Map<String, dynamic> combined = {};
    final rawSettings = ctx.getVariable(key)?.rawValue;
    if (rawSettings is Map) {
      rawSettings.forEach((k, v) => combined[k.toString()] = v);
    }
    named.forEach((k, v) {
      final strKey = k.toString().substring(8, k.toString().length - 2); 
      combined[strKey] = v;
    });
    return combined;
  }

  static Color? _resolveColor(dynamic value) {
    if (value is Color) return value;
    if (value is String) {
      switch (value) {
        case "Color.red": return const Color(0xFFFF0000);
        case "Color.black": return const Color(0xFF000000);
        case "Color.blue": return const Color(0xFF0000FF);
        case "Color.green": return const Color(0xFF00FF00);
      }
    }
    return null;
  }

  static EdgeInsets _resolvePadding(Map<String, dynamic> args) {
    if (args.containsKey('padding') && args['padding'] is EdgeInsets) {
      return args['padding'];
    }
    if (args.containsKey('all')) {
      final v = _toDouble(args['all']) ?? 0;
      return EdgeInsets.all(v);
    }
    final x = _toDouble(args['x'] ?? args['horizontal']);
    final y = _toDouble(args['y'] ?? args['vertical']);
    return EdgeInsets.only(
      left: _toDouble(args['left']) ?? x ?? 0,
      right: _toDouble(args['right']) ?? x ?? 0,
      top: _toDouble(args['top']) ?? y ?? 0,
      bottom: _toDouble(args['bottom']) ?? y ?? 0,
    );
  }

  static PageFormat _resolvePageFormat(Map<String, dynamic> args) {
    if (args['format'] is PageFormat) return args['format'];
    if (args['format'] is String) {
      switch (args['format'].toString().toLowerCase()) {
        case 'a3': return PageFormat.a3;
        case 'a5': return PageFormat.a5;
        case 'letter': return PageFormat.letter;
        case 'legal': return PageFormat.legal;
        case 'a4': 
        default: return PageFormat.a4;
      }
    }
    if (args.containsKey('width') && args.containsKey('height')) {
      return PageFormat(_toDouble(args['width'])!, _toDouble(args['height'])!);
    }
    return PageFormat.a4;
  }

  static EdgeInsets _resolvePageMargin(Map<String, dynamic> args) {
     if (args.containsKey('margin')) {
       final m = args['margin'];
       if (m is EdgeInsets) return m;
       if (m is num) return EdgeInsets.all(m.toDouble());
     }
     return _resolvePadding(args);
  }

  static TextStyle _resolveTextStyle(Map<String, dynamic> args) {
    FontWeight? resolveWeight(dynamic w) {
      if (w is FontWeight) return w;
      if (w == 'bold') return FontWeight.bold;
      if (w == 'normal') return FontWeight.normal;
      return null;
    }
    return TextStyle(
      fontSize: _toDouble(args['size'] ?? args['fontSize']),
      fontWeight: resolveWeight(args['weight'] ?? args['fontWeight']),
      textColor: _resolveColor(args['textColor']),
    );
  }

  // --- STANDARD LIBRARY ---
  static final Map<String, ScriptObject> standardLibrary = {
    'print': ScriptFunction.native((pos, named, ctx) {
      final message = pos.map((e) => e.toString()).join(' ');
      print(message); 
      return null;
    }),
    'Color.red': ScriptValue("Color.red"),
    'Color.black': ScriptValue("Color.black"),
    'Color.blue': ScriptValue("Color.blue"),
    'Color.green': ScriptValue("Color.green"),
    
    // Page Constants
    'PageFormat.a3': ScriptValue(PageFormat.a3),
    'PageFormat.a4': ScriptValue(PageFormat.a4),
    'PageFormat.a5': ScriptValue(PageFormat.a5),
    'PageFormat.letter': ScriptValue(PageFormat.letter),
    'PageFormat.legal': ScriptValue(PageFormat.legal),

    'Row': ScriptFunction.native((pos, named, ctx) => Row(children: _extractChildren(pos, named))),
    'Column': ScriptFunction.native((pos, named, ctx) => Column(children: _extractChildren(pos, named))),
    'Flow': ScriptFunction.native((pos, named, ctx) => Flow(children: _extractChildren(pos, named))),
    'SizedBox': ScriptFunction.native((pos, named, ctx) {
      return SizedBox(
        width: _toDouble(named[#width]), 
        height: _toDouble(named[#height]), 
        child: _extractChild(pos, named)
      );
    }),
    'Padding': ScriptFunction.native((pos, named, ctx) {
      final effectiveArgs = Evaluator._mergeSettings('__config_padding', named, ctx);
      return Padding(
        padding: Evaluator._resolvePadding(effectiveArgs),
        child: _extractChild(pos, named)
      );
    }),
    'DecoratedBox': ScriptFunction.native((pos, named, ctx) {
      final effectiveArgs = Evaluator._mergeSettings('__config_box', named, ctx);
      BoxDecoration decoration;
      if (effectiveArgs.containsKey('decoration') && effectiveArgs['decoration'] is BoxDecoration) {
        decoration = effectiveArgs['decoration'];
      } else {
         Border? border;
         if (effectiveArgs.containsKey('borderWidth')) {
            border = Border.all(
              width: Evaluator._toDouble(effectiveArgs['borderWidth']) ?? 1.0,
              color: _resolveColor(effectiveArgs['borderColor']) ?? const Color(0xFF000000)
            );
         } else if (effectiveArgs.containsKey('border')) {
             if (effectiveArgs['border'] is Border) border = effectiveArgs['border'];
         }
         decoration = BoxDecoration(border: border);
      }
      return DecoratedBox(decoration: decoration, child: _extractChild(pos, named));
    }),
    'Align': ScriptFunction.native((pos, named, ctx) {
      return Align(
        alignment: named[#alignment] ?? Alignment.center,
        child: _extractChild(pos, named)
      );
    }),
    'Expanded': ScriptFunction.native((pos, named, ctx) {
      return Expanded(
        flex: (named[#flex] ?? 1) as int,
        child: _extractChild(pos, named)
      );
    }),
    'Underline': ScriptFunction.native((pos, named, ctx) {
       return Underline(child: _extractChild(pos, named));
    }),
    'Text': ScriptFunction.native((pos, named, ctx) {
      final effectiveArgs = Evaluator._mergeSettings('__config_text', named, ctx);
      dynamic content = pos.isNotEmpty ? pos.first : '';
      final unwrapped = _unwrap(content);
      String textStr = (unwrapped is List) ? unwrapped.map((e) => e.toString()).join() : unwrapped.toString();
      return Text(textStr, style: Evaluator._resolveTextStyle(effectiveArgs));
    }),
    'EdgeInsets.all': ScriptFunction.native((pos, named, ctx) => EdgeInsets.all(_toDouble(pos[0])!)),
    'EdgeInsets.symmetric': ScriptFunction.native((pos, named, ctx) => EdgeInsets.symmetric(
      horizontal: _toDouble(named[#horizontal]) ?? 0, 
      vertical: _toDouble(named[#vertical]) ?? 0
    )),
    'Border.all': ScriptFunction.native((pos, named, ctx) => Border.all(width: _toDouble(named[#width] ?? 1.0)!)),
    'BoxDecoration': ScriptFunction.native((pos, named, ctx) => BoxDecoration(border: named[#border])),
    'TextStyle': ScriptFunction.native((pos, named, ctx) => TextStyle(
      fontSize: _toDouble(named[#fontSize]), 
      fontWeight: named[#fontWeight], 
      yOffsetFactor: _toDouble(named[#yOffsetFactor])
    )),
    'FontWeight.bold': ScriptValue(FontWeight.bold),
    'FontWeight.normal': ScriptValue(FontWeight.normal),
    'Alignment.center': ScriptValue(Alignment.center),
    'Alignment.topLeft': ScriptValue(Alignment.topLeft),
    'Alignment.topRight': ScriptValue(Alignment.topRight),
  };

  Widget normalizeToWidget(dynamic result) {
    if (result is ScriptObject) return normalizeToWidget(result.rawValue);
    if (result is Widget) return result;
    if (result is List) return Flow(children: result.whereType<Widget>().toList());
    return Text(result?.toString() ?? '');
  }

  List<Widget> processList(List<ScriptNode> nodes, ExecutionContext context) {
    final widgets = <Widget>[];
    for (final child in nodes) {
      final res = visit(child, context);
      if (res == null) continue;
      
      final unwrapped = _unwrap(res);
      
      if (unwrapped is Widget) widgets.add(unwrapped);
      else if (unwrapped is List) widgets.addAll(unwrapped.whereType<Widget>());
      else if (unwrapped is String && unwrapped.isNotEmpty) widgets.add(Text(unwrapped));
    }
    return widgets;
  }

  dynamic visit(ScriptNode node, ExecutionContext context) {
    switch (node) {
      case MarkupBlockNode(): 
        return processList(node.children, context.createChildScope());
      
      // Returns a List containing all evaluated elements.
      case ListNode(): 
        return node.elements
            .map((e) => _unwrap(visit(e, context)))
            .where((e) => e != null)
            .toList();

      // Returns only the last value.
      case CodeBlockNode():
        final scope = context.createChildScope();
        dynamic lastValue;
        for(final stmt in node.statements) {
          lastValue = visit(stmt, scope);
        }
        return lastValue;

      case TextLiteralNode(): 
        if (node.text.trim().isEmpty) return null;
        final effectiveArgs = Evaluator._mergeSettings('__config_text', {}, context);
        if (!effectiveArgs.containsKey('size') && !effectiveArgs.containsKey('fontSize')) {
           final defSize = _unwrap(context.getVariable('defaultFontSize'));
           effectiveArgs['size'] = _toDouble(defSize) ?? 12.0;
        }
        return Text(node.text, style: Evaluator._resolveTextStyle(effectiveArgs));
      
      case LiteralNode(): return ScriptValue(node.value);

      case MapNode():
        final result = <String, dynamic>{};
        for (final entry in node.entries.entries) {
          result[entry.key] = _unwrap(visit(entry.value, context));
        }
        return ScriptValue(result);

      case RangeNode():
        final left = _unwrap(visit(node.left, context));
        final right = _unwrap(visit(node.right, context));
        if (left is num && right is num) {
          return _ScriptRange(left.toInt(), right.toInt(), node.inclusive);
        }
        throw Exception("Range expects numbers");
      
      case IdentifierNode():
        if (context.hasVariable(node.name)) return context.getVariable(node.name);
        throw ScriptException(
          "Undefined variable: ${node.name}", 
          node.offset, 
          node.length
        );

      case BinaryOpNode():
        final left = _unwrap(visit(node.left, context));
        final right = _unwrap(visit(node.right, context));
        switch(node.operator) {
          case '+': return (left is String || right is String) ? '$left$right' : left + right;
          case '-': return left - right;
          case '*': return left * right;
          case '/': return left / right;
          case '%': return left % right;
          case '==': return left == right;
          case '!=': return left != right;
          case '>': return left > right;
          case '<': return left < right;
          case '>=': return left >= right;
          case '<=': return left <= right;
          case '&&': return left && right;
          case '||': return left || right;
          default: throw Exception("Unknown operator ${node.operator}");
        }
      
      case PropertyAccessNode():
        if (node.target is IdentifierNode) {
          final compound = "${(node.target as IdentifierNode).name}.${node.propertyName}";
          if (context.hasVariable(compound)) return context.getVariable(compound);
        }
        final target = _unwrap(visit(node.target, context));
        if (target is Map) return ScriptValue(target[node.propertyName]);
        if (target is List && node.propertyName == 'length') return ScriptValue(target.length);
        if (target is String && node.propertyName == 'length') return ScriptValue(target.length);
        throw Exception("Cannot access property '${node.propertyName}' on target $target");

      case LetBindingNode():
        final val = visit(node.expression, context);
        context.setVariable(node.name, val is ScriptObject ? val : ScriptValue(val));
        return null;

      case SetContextNode():
        final resolvedArgs = <String, dynamic>{};
        for (final entry in node.arguments.entries) {
          resolvedArgs[entry.key] = _unwrap(visit(entry.value, context));
        }
        final configKey = '__config_${node.target}';
        final currentRaw = context.getVariable(configKey)?.rawValue;
        final Map<String, dynamic> current = (currentRaw is Map) ? Map<String, dynamic>.from(currentRaw) : {};
        resolvedArgs.forEach((k, v) => current[k] = v);
        context.setVariable(configKey, ScriptValue(current));
        return null;

      case IfExpressionNode():
        final condition = _unwrap(visit(node.condition, context));
        bool isTrue = false;
        if (condition is bool) isTrue = condition;
        else if (condition is num) isTrue = condition != 0;
        else if (condition is String) isTrue = condition.isNotEmpty;
        else if (condition != null) isTrue = true;

        if (isTrue) {
          return visit(node.thenBlock, context);
        } else if (node.elseBlock != null) {
          return visit(node.elseBlock!, context);
        }
        return null;

      case ForLoopNode():
        var collectionRaw = _unwrap(visit(node.collection, context));
        
        if (collectionRaw is int) {
          collectionRaw = _ScriptRange(0, collectionRaw, false);
        }

        final widgets = <Widget>[];

        void executeBody(dynamic v1, [dynamic v2]) {
           final scope = context.createChildScope();
           scope.setVariable(node.itemNames[0], ScriptValue(v1));
           if (node.itemNames.length > 1) {
             scope.setVariable(node.itemNames[1], ScriptValue(v2));
           }
           final res = visit(node.body, scope);
           final unwrapped = _unwrap(res);
           if (unwrapped is List) widgets.addAll(unwrapped.whereType<Widget>());
           else if (unwrapped is Widget) widgets.add(unwrapped);
        }

        if (collectionRaw is _ScriptRange) {
           final range = collectionRaw;
           final end = range.inclusive ? range.end : range.end - 1;
           for (int i = range.start; i <= end; i++) {
             executeBody(i);
           }
        } else if (collectionRaw is List) {
          if (node.itemNames.length == 2) {
            for (int i = 0; i < collectionRaw.length; i++) {
              executeBody(collectionRaw[i], i);
            }
          } else {
            for (final item in collectionRaw) {
              executeBody(item);
            }
          }
        } else if (collectionRaw is Map) {
          if (node.itemNames.length == 2) {
             collectionRaw.forEach((k, v) {
               executeBody(k, v);
             });
          } else {
             for (final key in collectionRaw.keys) {
               executeBody(key);
             }
          }
        } else {
          throw Exception("Cannot iterate over type ${collectionRaw.runtimeType}");
        }
        return widgets;

      case FunctionDefinitionNode():
        return ScriptFunction.user(node.params, node.body);

      case FunctionCallNode():
        final calleeObj = visit(node.callee, context);
        final unwrappedCallee = _unwrap(calleeObj);

        if (node.namedArgs.containsKey('__is_index_access')) {
             if (node.positionalArgs.isEmpty) throw Exception("Index required for [] access");
             final index = _unwrap(visit(node.positionalArgs[0], context));
             if (unwrappedCallee is List && index is int) return ScriptValue(unwrappedCallee[index]);
             if (unwrappedCallee is Map) return ScriptValue(unwrappedCallee[index]);
             throw Exception("Invalid index access on ${unwrappedCallee.runtimeType}");
        }
        
        if (calleeObj is! ScriptFunction) {
          throw Exception("Target is not a function: ${calleeObj?.rawValue} (Node: ${node.callee.runtimeType})");
        }
        final ScriptFunction callee = calleeObj;

        final posArgs = <dynamic>[];
        
        for (final argNode in node.positionalArgs) {
          if (argNode is SpreadArgumentNode) {
            final val = _unwrap(visit(argNode.expression, context));
            if (val is List) {
              posArgs.addAll(val);
            } else {
              throw Exception("Spread operator '...' expects a List, got $val");
            }
          } else {
            posArgs.add(_unwrap(visit(argNode, context)));
          }
        }
        
        final namedArgs = <Symbol, dynamic>{};
        node.namedArgs.forEach((key, valNode) => namedArgs[Symbol(key)] = _unwrap(visit(valNode, context)));

        if (callee.nativeHandler != null) {
          try {
            final res = callee.nativeHandler!(posArgs, namedArgs, context);
            return res is ScriptObject ? res : ScriptValue(res);
          } catch(e) {
            throw Exception("Error calling native function: $e");
          }
        }
        
        final scope = context.createChildScope();
        final rawParams = callee.parameters!;
        
        for (var rawParam in rawParams) {
          final name = rawParam.replaceAll(RegExp(r'^[\*]+'), '');
          if (namedArgs.containsKey(Symbol(name))) {
            final val = namedArgs[Symbol(name)];
            scope.setVariable(name, val is ScriptObject ? val : ScriptValue(val));
          }
        }

        final unassignedParams = rawParams.where((p) {
          final cleanName = p.replaceAll(RegExp(r'^[\*]+'), '');
          return !scope.hasVariable(cleanName); 
        }).toList();

        int posIndex = 0;
        for (var rawP in unassignedParams) {
          final cleanName = rawP.replaceAll(RegExp(r'^[\*]+'), '');
          
          if (rawP.startsWith('**')) {
             final restList = [];
             while(posIndex < posArgs.length) {
               restList.add(posArgs[posIndex]);
               posIndex++;
             }
             scope.setVariable(cleanName, ScriptValue(restList));
          } else {
             if (posIndex < posArgs.length) {
               final val = posArgs[posIndex];
               scope.setVariable(cleanName, val is ScriptObject ? val : ScriptValue(val));
               posIndex++;
             } else {
               scope.setVariable(cleanName, ScriptValue(null));
             }
          }
        }

        final hasVararg = rawParams.any((p) => p.startsWith('**'));
        if (!hasVararg && posIndex < posArgs.length) {
          throw Exception("Too many positional arguments passed to function.");
        }

        for (var rawP in rawParams) {
          final cleanName = rawP.replaceAll(RegExp(r'^[\*]+'), '');
          if (!scope.hasVariable(cleanName)) scope.setVariable(cleanName, ScriptValue(null));
        }

        return visit(callee.body!, scope);

      default: return null;
    }
  }
}

class _ScriptRange {
  final int start;
  final int end;
  final bool inclusive;
  _ScriptRange(this.start, this.end, this.inclusive);
}

class ScriptException implements Exception {
  final String message;
  final int offset;
  final int length;
  ScriptException(this.message, this.offset, this.length);
  @override 
  String toString() => message;
}