Demo: https://jacksonrl.github.io/typesetting_prototype/

Typsetting program written in dart, with the following features:

- Multi column text with balancing

- Create page headers based on headers in body text (ie. dynamic headers/footers)

- Table of Contents

- Footnotes

Not yet supported:

- MathML/Latex formulas

typesetting_prototype's architecture is based mainly on Flutter (but does not itself use the flutter framework). You can run it directly on the web or natively. In the native version you can create custom rendernodes (same as flutter renderobjects) for advanced features.

The program is currently geared towards books, although as of yet nothing has been typeset in it.

Thanks to https://github.com/DavBfr/dart_pdf for the high quality PDF backend.
