import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../models/app_models.dart';
import '../notes/note_document.dart';

class IntelligenceDoc {
  const IntelligenceDoc(this.id, this.title, this.updatedAt, this.text, this.terms, this.entities);
  final String id, title, text;
  final DateTime updatedAt;
  final Map<String, int> terms;
  final List<String> entities;
  Map<String, Object?> toJson() => {'id': id, 'title': title, 'updatedAt': updatedAt.toIso8601String(), 'text': text, 'terms': terms, 'entities': entities};
  factory IntelligenceDoc.fromJson(Map<String, Object?> j) => IntelligenceDoc(
    j['id']?.toString() ?? '', j['title']?.toString() ?? '', DateTime.tryParse(j['updatedAt']?.toString() ?? '') ?? DateTime(1970), j['text']?.toString() ?? '',
    {for (final e in (j['terms'] as Map? ?? const {}).entries) e.key.toString(): int.tryParse(e.value.toString()) ?? 0},
    (j['entities'] as List? ?? const []).map((e) => e.toString()).toList(),
  );
}

class IntelligenceIndex {
  const IntelligenceIndex(this.projectId, this.generatedAt, this.digest, this.docs);
  final String projectId, digest;
  final DateTime generatedAt;
  final List<IntelligenceDoc> docs;
  Map<String, Object?> toJson() => {'schema': 1, 'projectId': projectId, 'generatedAt': generatedAt.toIso8601String(), 'digest': digest, 'docs': docs.map((e) => e.toJson()).toList()};
  factory IntelligenceIndex.fromJson(Map<String, Object?> j) => IntelligenceIndex(j['projectId']?.toString() ?? '', DateTime.tryParse(j['generatedAt']?.toString() ?? '') ?? DateTime(1970), j['digest']?.toString() ?? '', [for (final e in j['docs'] as List? ?? const []) if (e is Map) IntelligenceDoc.fromJson(e.map((k,v)=>MapEntry(k.toString(),v)))]);
}

class IntelligenceHit {
  const IntelligenceHit(this.doc, this.score, this.shared, this.snippet);
  final IntelligenceDoc doc;
  final double score;
  final List<String> shared;
  final String snippet;
}

class IntelligenceLink {
  const IntelligenceLink(this.left, this.right, this.score, this.shared);
  final IntelligenceDoc left, right;
  final double score;
  final List<String> shared;
}

class IntelligenceConflict {
  const IntelligenceConflict(this.left, this.right, this.a, this.b, this.reason);
  final IntelligenceDoc left, right;
  final String a, b, reason;
}

class IntelligenceAnswer {
  const IntelligenceAnswer(this.text, this.sources);
  final String text;
  final List<IntelligenceHit> sources;
}

class LocalIntelligenceEngine {
  static final _words = RegExp(r'[A-Za-zА-Яа-яЁё0-9][A-Za-zА-Яа-яЁё0-9_-]{1,}', unicode: true);
  static const _stop = {'and','the','that','this','with','from','were','was','are','for','или','это','как','что','при','для','также','была','были','есть','без','после','между','который','которые'};
  static const _neg = {'не','нет','отсутствует','отсутствуют','снижается','уменьшается','not','no','absent','decreases','lower','without'};

  String digest(List<Note> notes) {
    final copy = List<Note>.from(notes)..sort((a,b)=>a.id.compareTo(b.id));
    return sha256.convert(utf8.encode(copy.map((n)=>'${n.id}|${n.updatedAt.toIso8601String()}|${n.body.length}|${n.title}').join('\n'))).toString();
  }

  IntelligenceIndex build(Project project, List<Note> notes) {
    final docs = <IntelligenceDoc>[];
    for (final n in notes.where((n)=>n.projectId == project.id)) {
      final text = _plain('${n.title}\n${NoteDocument.parse(n.body).content}');
      docs.add(IntelligenceDoc(n.id, n.title, n.updatedAt, text, _tf(text), _entities(text)));
    }
    return IntelligenceIndex(project.id, DateTime.now(), digest(notes.where((n)=>n.projectId == project.id).toList()), docs);
  }

  List<IntelligenceHit> search(IntelligenceIndex index, String query, {int limit = 20}) {
    final q = _tf(query); if (q.isEmpty) return const [];
    final idf = _idf(index.docs), out = <IntelligenceHit>[];
    for (final d in index.docs) {
      final score = _cos(q,d.terms,idf); if (score <= 0) continue;
      final shared = q.keys.where(d.terms.containsKey).toList()..sort((a,b)=>(idf[b]??0).compareTo(idf[a]??0));
      out.add(IntelligenceHit(d,score,shared.take(6).toList(),_snippet(d.text,q.keys.toSet())));
    }
    out.sort((a,b)=>b.score.compareTo(a.score)); return out.take(limit).toList();
  }

  List<IntelligenceHit> similar(IntelligenceIndex index, String id) {
    final source = index.docs.where((d)=>d.id==id).firstOrNull; if (source==null) return const [];
    final idf=_idf(index.docs), out=<IntelligenceHit>[];
    for(final d in index.docs){ if(d.id==id)continue; final s=_cos(source.terms,d.terms,idf); if(s<.08)continue; final sh=source.terms.keys.where(d.terms.containsKey).toList()..sort((a,b)=>(idf[b]??0).compareTo(idf[a]??0)); out.add(IntelligenceHit(d,s,sh.take(6).toList(),_snippet(d.text,sh.take(4).toSet()))); }
    out.sort((a,b)=>b.score.compareTo(a.score)); return out.take(8).toList();
  }

  List<IntelligenceLink> links(IntelligenceIndex index) {
    final idf=_idf(index.docs), out=<IntelligenceLink>[];
    for(var i=0;i<index.docs.length;i++) {
      for(var j=i+1;j<index.docs.length;j++) {
        final a=index.docs[i],b=index.docs[j],s=_cos(a.terms,b.terms,idf);
        if(s<.16)continue;
        final sh=a.terms.keys.where(b.terms.containsKey).toList()..sort((x,y)=>(idf[y]??0).compareTo(idf[x]??0));
        out.add(IntelligenceLink(a,b,s,sh.take(7).toList()));
      }
    }
    out.sort((a,b)=>b.score.compareTo(a.score));return out.take(20).toList();
  }

  List<IntelligenceConflict> conflicts(IntelligenceIndex index) {
    final out=<IntelligenceConflict>[];
    for(var i=0;i<index.docs.length;i++) {
      for(var j=i+1;j<index.docs.length;j++) {
        final a=index.docs[i],b=index.docs[j];
        for(final sa in _sentences(a.text)) {
          final ta=_tf(sa).keys.toSet();
          if(ta.length<3)continue;
          for(final sb in _sentences(b.text)) {
            final tb=_tf(sb).keys.toSet();
            if(ta.intersection(tb).length<3)continue;
            String? reason;
            final na=_negative(sa),nb=_negative(sb);
            final xa=_numbers(sa),xb=_numbers(sb);
            if(na!=nb) {
              reason='Похожие утверждения используют противоположное отрицание.';
            } else if(xa.isNotEmpty&&xb.isNotEmpty&&xa.intersection(xb).isEmpty) {
              reason='Для похожего утверждения указаны разные числа.';
            }
            if(reason!=null) {
              out.add(IntelligenceConflict(a,b,sa.trim(),sb.trim(),reason));
              break;
            }
          }
        }
      }
    }
    return out.take(20).toList();
  }

  IntelligenceAnswer answer(IntelligenceIndex index,String question){final hits=search(index,question,limit:5);if(hits.isEmpty)return const IntelligenceAnswer('В локальном индексе не найдено достаточно близких фрагментов.',[]);final q=_tf(question).keys.toSet(),parts=<String>[];for(final h in hits){final ss=_sentences(h.doc.text).toList()..sort((a,b)=>_score(b,q).compareTo(_score(a,q)));if(ss.isNotEmpty&&_score(ss.first,q)>0)parts.add(ss.first.trim());if(parts.length==3)break;}return IntelligenceAnswer(parts.isEmpty?'Найдены близкие заметки, но точный ответ не извлечён.':parts.join(' '),hits.take(3).toList());}

  String history(IntelligenceIndex index){final docs=List<IntelligenceDoc>.from(index.docs)..sort((a,b)=>a.updatedAt.compareTo(b.updatedAt));return docs.map((d){final s=_sentences(d.text).where((x)=>x.length>30).firstOrNull??d.text;final c=s.length>220?'${s.substring(0,217)}…':s;return '• ${d.updatedAt.day.toString().padLeft(2,'0')}.${d.updatedAt.month.toString().padLeft(2,'0')}.${d.updatedAt.year} — ${d.title}: $c';}).join('\n');}
  Map<String,int> terms(IntelligenceIndex index){final m=<String,int>{};for(final d in index.docs){for(final e in d.terms.entries){m[e.key]=(m[e.key]??0)+e.value;}for(final e in d.entities){m[e]=(m[e]??0)+2;}}final es=m.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));return {for(final e in es.take(40))e.key:e.value};}

  Map<String,double> _idf(List<IntelligenceDoc> docs){final f=<String,int>{};for(final d in docs){for(final t in d.terms.keys){f[t]=(f[t]??0)+1;}}return {for(final e in f.entries)e.key:math.log((docs.length+1)/(e.value+1))+1};}
  double _cos(Map<String,int>a,Map<String,int>b,Map<String,double>idf){var dot=0.0,an=0.0,bn=0.0;for(final e in a.entries){final w=e.value*(idf[e.key]??1);an+=w*w;if(b[e.key]!=null)dot+=w*b[e.key]!*(idf[e.key]??1);}for(final e in b.entries){final w=e.value*(idf[e.key]??1);bn+=w*w;}return an==0||bn==0?0:dot/(math.sqrt(an)*math.sqrt(bn));}
  Map<String,int> _tf(String text){final m=<String,int>{};for(final x in _words.allMatches(text.toLowerCase())){var t=x.group(0)!.replaceAll('ё','е');if(t.length<2||_stop.contains(t))continue;m[t]=(m[t]??0)+1;}return m;}
  String _plain(String s)=>s.replaceAll(RegExp(r'```[\s\S]*?```'),' ').replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'),' ').replaceAll(RegExp(r'\[([^\]]+)\]\([^)]*\)'),r'$1').replaceAll(RegExp(r'[#>*_`|~-]+'),' ').replaceAll(RegExp(r'\s+'),' ').trim();
  List<String> _entities(String s){final x=<String>{};for(final m in RegExp(r'\b[A-ZА-ЯЁ][A-ZА-ЯЁ0-9-]{1,12}\b',unicode:true).allMatches(s)){x.add(m.group(0)!);}return x.take(30).toList();}
  Iterable<String> _sentences(String s)=>RegExp(r'[^.!?\n]+[.!?]?',multiLine:true).allMatches(s).map((m)=>m.group(0)!.trim()).where((x)=>x.length>12);
  int _score(String s,Set<String>q)=>_tf(s).keys.toSet().intersection(q).length;
  String _snippet(String s,Set<String>q){var best='',score=-1;for(final x in _sentences(s)){final n=_score(x,q);if(n>score){score=n;best=x;}}return best.length>260?'${best.substring(0,257)}…':best;}
  bool _negative(String s)=>_words.allMatches(s.toLowerCase()).map((m)=>m.group(0)!).any(_neg.contains);
  Set<String> _numbers(String s)=>RegExp(r'\b\d+(?:[.,]\d+)?\b').allMatches(s).map((m)=>m.group(0)!.replaceAll(',','.')).toSet();
}

class IntelligenceIndexStore {
  const IntelligenceIndexStore();
  Future<File> _file(String id) async {final d=await getApplicationSupportDirectory();final dir=Directory(path.join(d.path,'local_intelligence'));await dir.create(recursive:true);return File(path.join(dir.path,'${id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'),'_')}.json'));}
  Future<IntelligenceIndex?> read(String id) async {final f=await _file(id);if(!await f.exists())return null;try{final j=jsonDecode(await f.readAsString());return j is Map?IntelligenceIndex.fromJson(j.map((k,v)=>MapEntry(k.toString(),v))):null;}catch(_){return null;}}
  Future<void> write(IntelligenceIndex i) async { await (await _file(i.projectId)).writeAsString(const JsonEncoder.withIndent('  ').convert(i.toJson()), flush: true); }
  Future<void> delete(String id) async {final f=await _file(id);if(await f.exists())await f.delete();}
}
