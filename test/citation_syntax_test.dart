import 'package:chronicle/features/references/citation_syntax.dart';
import 'package:chronicle/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final jaffe = CitationSource(
    id: 'source-1',
    citationKey: 'Jaffe2005',
    title: 'Multistate proteins',
    authors: const ['Jaffe, Eileen'],
    year: 2005,
    containerTitle: 'Trends in Biochemical Sciences',
    doi: '10.1016/j.tibs.2005.07.003',
  );
  final smith = CitationSource(
    id: 'source-2',
    citationKey: 'Smith2023',
    title: 'Protein dynamics',
    authors: const ['Anna Smith', 'John Doe'],
    year: 2023,
  );

  test('extracts unique citation keys and ignores fenced code', () {
    const markdown = '''Text [@Jaffe2005; @Smith2023].

```
[@Ignored2024]
```

Again [@Jaffe2005].''';

    expect(
      CitationSyntax.extractKeys(markdown),
      ['Jaffe2005', 'Smith2023'],
    );
    expect(CitationSyntax.countKey(markdown, 'Jaffe2005'), 2);
    expect(CitationSyntax.countKey(markdown, 'Ignored2024'), 0);
  });

  test('renders citations and bibliography in first-use order', () {
    const markdown = '''Result [@Smith2023; @Jaffe2005].

:::bibliography''';
    final bibliography = CitationSyntax.bibliographyFor(
      markdown,
      [jaffe, smith],
    );
    final rendered = CitationSyntax.renderMarkdownChunk(
      markdown,
      [jaffe, smith],
      bibliography: bibliography,
    );

    expect(rendered, contains('(Smith и Doe, 2023; Jaffe, 2005)'));
    expect(rendered, contains('## Литература'));
    expect(rendered.indexOf('Protein dynamics'), lessThan(rendered.indexOf('Multistate proteins')));
    expect(rendered, contains('https://doi.org/10.1016/j.tibs.2005.07.003'));
  });

  test('builds compact markdown for multiple selected sources', () {
    expect(
      CitationSyntax.markdownFor([jaffe, smith, jaffe]),
      '[@Jaffe2005; @Smith2023]',
    );
  });
}
