import 'package:flutter_test/flutter_test.dart';
import 'package:chronicle/features/intelligence/local_intelligence.dart';
import 'package:chronicle/models/app_models.dart';

void main() {
  test('local intelligence finds semantic overlap and sourced answers', () {
    final project = Project(id: 'p', title: 'ORF9b', emoji: '🧬');
    final notes = <Note>[
      Note(
        id: 'a',
        title: 'RMSD transition',
        projectId: 'p',
        body:
            '# Results\nThe RMSD trajectory shows a metastable transition near frame 1200.',
      ),
      Note(
        id: 'b',
        title: 'Structural states',
        projectId: 'p',
        body:
            '# Discussion\nA metastable state appears after the structural transition.',
      ),
    ];
    final engine = LocalIntelligenceEngine();
    final index = engine.build(project, notes);
    final hits = engine.search(index, 'metastable structural transition');
    expect(hits, isNotEmpty);
    expect(hits.first.shared, contains('metastable'));
    final answer = engine.answer(index, 'Where is the metastable transition?');
    expect(answer.sources, isNotEmpty);
    expect(answer.text.toLowerCase(), contains('transition'));
  });

  test('contradiction candidates remain suggestions', () {
    final project = Project(id: 'p', title: 'Test', emoji: '🧪');
    final notes = <Note>[
      Note(
        id: 'a',
        title: 'A',
        projectId: 'p',
        body: 'Protein binding increases at 20 degrees.',
      ),
      Note(
        id: 'b',
        title: 'B',
        projectId: 'p',
        body: 'Protein binding does not increase at 20 degrees.',
      ),
    ];
    final conflicts = LocalIntelligenceEngine().conflicts(
      LocalIntelligenceEngine().build(project, notes),
    );
    expect(conflicts, isNotEmpty);
    expect(conflicts.first.reason, contains('отрицание'));
  });
}
