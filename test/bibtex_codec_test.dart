import 'package:chronicle/features/references/bibtex_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('imports nested BibTeX fields and exports them again', () {
    const raw = r'''
@article{Jaffe2005,
  title = {Multistate {Protein} Dynamics},
  author = {Jaffe, Eileen and Smith, John},
  year = {2005},
  journal = {Trends in Biochemical Sciences},
  doi = {https://doi.org/10.1016/j.tibs.2005.07.003},
  keywords = {allostery, metastability}
}
''';

    final parsed = BibTexCodec.decode(raw);

    expect(parsed.errors, isEmpty);
    expect(parsed.sources, hasLength(1));
    final source = parsed.sources.single;
    expect(source.citationKey, 'Jaffe2005');
    expect(source.title, 'Multistate Protein Dynamics');
    expect(source.authors, ['Jaffe, Eileen', 'Smith, John']);
    expect(source.year, 2005);
    expect(source.normalizedDoi, '10.1016/j.tibs.2005.07.003');
    expect(source.tags, ['allostery', 'metastability']);

    final exported = BibTexCodec.encode([source]);
    expect(exported, contains('@article{Jaffe2005,'));
    expect(exported, contains('doi = {10.1016/j.tibs.2005.07.003}'));
  });

  test('reports records without required title', () {
    final parsed = BibTexCodec.decode('@article{Broken, year = {2024}}');

    expect(parsed.sources, isEmpty);
    expect(parsed.errors, isNotEmpty);
  });
}
