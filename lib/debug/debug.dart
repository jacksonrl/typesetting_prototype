import 'package:typesetting_prototype/knuth/knuth_plass_span_multi_font_size.dart';
import 'package:typesetting_prototype/typesetting_prototype.dart';


String _getTextContent(RenderNode node) {
    String text = '';
    
    if (node is RenderRichText) {
      text = node.spans.map((s) => s.text).join();
    } else if (node is RenderRichTextLine) {
      text = node.spans.map((s) => s.text).join();
    } else if (node is RenderFormattedText) {
      text = node.text;
    } else if (node is RenderRepeater) {
      text = node.text;
    } else if (node is RenderKnuthPlassTextLine) {
      text = node.line
          .whereType<Box>()
          .map((b) => b.value)
          .join();
    } else if (node is RenderMetadataMarker) {
        return ' key="${node.key}"'; 
    }

    text = text.replaceAll('\n', ' ').trim();
    if (text.isEmpty) return '';
    
    if (text.length > 30) {
      return ' "${text.substring(0, 30)}..."';
    }
    return ' "$text"';
  }

class DebugTreeBuilder {
  final Map<RenderNode, _DebugNode> _nodeMap = {};
  final Map<RenderNode, List<_DebugNode>> _orphanChildren = {};
  
  late final _DebugNode _virtualRoot = _DebugNode(
    _VirtualDocumentNode(), 
    const LayoutResult(size: Size.zero),
  );

  //Since we attach by object identity, sometimes children may be placed
  //on an earlier page within a speculative layout and will stay there
  //in the debug print even though they get moved in a second pass.
  void onLayout(RenderNode node, LayoutResult result, int depth) {
    final debugNode = _DebugNode(node, result);
    _nodeMap[node] = debugNode;

    // Adopt waiting children
    if (_orphanChildren.containsKey(node)) {
      debugNode.children.addAll(_orphanChildren[node]!);
      _orphanChildren.remove(node);
    }

    // Attach to Parent
    if (node.parent != null) {
      if (_nodeMap.containsKey(node.parent!)) {
        // Parent already finished, attach directly
        _nodeMap[node.parent!]!.children.add(debugNode);
      } else {
        // Wait for parent
        _orphanChildren.putIfAbsent(node.parent!, () => []).add(debugNode);
      }
    } else {
      // No Parent? Attach to Virtual Root
      _virtualRoot.children.add(debugNode);
    }
  }

  void printTree() {
    print('\nDocument Generation Trace:');
    for (var i = 0; i < _virtualRoot.children.length; i++) {
      _printRecursive(
        _virtualRoot.children[i], 
        "", 
        i == _virtualRoot.children.length - 1
      );
    }
    print('');
  }

  

  void _printRecursive(_DebugNode node, String prefix, bool isLast) {
    final connector = isLast ? '└───' : '├───';
    
    final type = node.renderNode.runtimeType.toString();
    final w = node.result.size.width.toStringAsFixed(1);
    final h = node.result.size.height.toStringAsFixed(1);
    
    String metaString = '';
    if (node.result.metadata.isNotEmpty) {
      final keys = node.result.metadata.map((m) => m.key).toSet().join(', ');
      metaString = ' [Meta: $keys]';
    }

    final textContent = _getTextContent(node.renderNode);

    print('$prefix$connector$type (w:$w h:$h)$textContent$metaString');

    final childPrefix = prefix + (isLast ? '    ' : '│   ');

    for (var i = 0; i < node.children.length; i++) {
      _printRecursive(
        node.children[i], 
        childPrefix, 
        i == node.children.length - 1
      );
    }
  }
}

class _DebugNode {
  final RenderNode renderNode;
  final LayoutResult result;
  final List<_DebugNode> children = [];

  _DebugNode(this.renderNode, this.result);
}

// Dummy node to act as the top-level anchor
class _VirtualDocumentNode extends RenderNode {
  @override
  LayoutResult performLayout(LayoutContext context) => throw UnimplementedError();
  @override
  void paint(PaintingContext context, Offset offset) {}
}



class StaticHierarchyPrinter {
  /// Dumps the static parent/child structure stored in memory.
  /// This does not show slice results or ephemeral nodes, only 
  /// persistent relationships defined by widgets/mixins.
  static void dump(RenderNode root) {
    print('=== Static Object Hierarchy ===');
    _printRecursive(root, "", true);
    print('===============================');
  }

  static void _printRecursive(RenderNode node, String prefix, bool isLast) {
    final connector = isLast ? '└───' : '├───';
    final type = node.runtimeType.toString();
    
    final textContent = _getTextContent(node);

    print('$prefix$connector$type$textContent');

    final childPrefix = prefix + (isLast ? '    ' : '│   ');

    for (var i = 0; i < node.children.length; i++) {
      _printRecursive(node.children[i], childPrefix, i == node.children.length - 1);
    }
  }
}
