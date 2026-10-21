import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/assessment/reference_practice_json_chunker.dart';

List<int> flatten(Iterable<List<int>> bytes)=>
    [for (final segment in bytes) ...segment];

void main() {
  test('UTF-8 chunks are bounded and reconstruct non-ASCII input',() {
    final fragments=['{"name":"', 'Résumé / 日本語 / 😀', '","steps":[]}' ];
    final chunks=ReferencePracticeJsonChunker.encode(
      fragments,partBytes:7,maxBytes:1024,
    ).toList();
    expect(chunks,everyElement(isA<List<int>>()));
    expect(chunks.every((part)=>part.length<=7),isTrue);
    expect(utf8.decode(flatten(chunks)),fragments.join());
    expect(jsonDecode(utf8.decode(flatten(chunks))),
        {'name':'Résumé / 日本語 / 😀','steps':[]});
  });

  test('Empty or malformed requested buffers do not make a download',() {
    expect(()=>ReferencePracticeJsonChunker.encode([]).toList(),
        throwsFormatException);
    expect(()=>ReferencePracticeJsonChunker.encode(
       ['valid'],partBytes:0).toList(),throwsFormatException);
    expect(()=>ReferencePracticeJsonChunker.encode(
       ['valid'],partBytes:11,maxBytes:10).toList(),throwsFormatException);
  });

  test('Huge generated JSON fails before a caller can create Blob',() {
    // Intentionally tiny ceiling for a fast regression, no 64MB allocations.
    expect(()=>ReferencePracticeJsonChunker.encode(
      ['{"events":["', '1234567890', '1234567890', '"]}'],
      partBytes:8,maxBytes:20,
    ).toList(),throwsStateError);
  });

  test('Exact size boundary succeeds, size +1 fails',() {
    final allowed=ReferencePracticeJsonChunker.encode(
      ['😀'],partBytes:3,maxBytes:4,
    ).toList();
    expect(utf8.decode(flatten(allowed)),'😀');
    expect(()=>ReferencePracticeJsonChunker.encode(
      ['😀!'],partBytes:3,maxBytes:4,
    ).toList(),throwsStateError);
  });
}
