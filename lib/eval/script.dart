import 'script_stdlib.dart';

//experimental interpreted script used with dart_eval

ScriptDocument main() {
  return ScriptDocument(
    body: ScriptPageLayout(
      header: ScriptPageSection.fixed(height: 20, builder: (context) => ScriptText('Header From Script!')),
      footer: ScriptPageSection.fixed(height: 20, builder: (context) => ScriptText('Footer From Script!')),
      body: [
        ScriptFlow(
          children: [
            ScriptText(
              'Hello from a clean, decoupled architecture!',
              font: ScriptTtfFont("fonts/NotoSansSC-Regular.ttf"),
            ),
            for (int i = 0; i < 5; i++) ScriptText('Item number $i'),
          ],
        ),
      ],
    ),
    tocBuilder: (registry) {
      return ScriptPageLayout(
        body: [
          ScriptFlow(
            children: [
              ScriptText("ToC here!"), //
            ],
          ),
        ],
      );
    },
  );
}
