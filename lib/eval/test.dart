import 'package:dart_eval/dart_eval.dart';

void main2() async {
  const scriptContent = '''

  void main() {
    A(1);
  }

  class A {
    const A(this.a);

    static const A c = A(2 * b);

    static const double b = 1.0;

    final double a;
  }

  ''';

  Compiler().compile({
    'my_app': {'main.dart': scriptContent},
  });
}

class A {
  const A(this.a);

  static const A c = A(2 * b);

  static const double b = 1.0;

  final double a;
}

final class NameHolder {
  final String name;
  const NameHolder({required this.name});
}
