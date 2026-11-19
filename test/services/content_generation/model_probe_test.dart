import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_pwa/services/content_generation/manual_job.dart';
import 'package:learning_pwa/services/content_generation/manual_prompt_builder.dart';
import 'package:learning_pwa/services/content_generation/model_capability_profile.dart';
import 'package:learning_pwa/services/content_generation/model_probe.dart';

const exact =
    '{"schema":"la-probe/1","items":[{"n":1,"v":"ok"},{"n":2,"v":"ok"}],'
    '"end":"END-PROBE"}';

void main() {
  group('ModelProbe.check', () {
    test('the exact reply passes, with or without a code fence', () {
      expect(ModelProbe.check(exact), ProbeOutcome.passed);
      expect(ModelProbe.check('```json\n$exact\n```'), ProbeOutcome.passed);
      expect(ModelProbe.check('  $exact\n'), ProbeOutcome.passed);
    });

    test('the probe prompt contains its own pass example', () {
      final example = ModelProbe.prompt.split('\n').last;
      expect(ModelProbe.check(example), ProbeOutcome.passed);
      expect(ModelProbe.prompt, isNot(contains('lesson')));
    });

    test('anything else fails with a reason', () {
      final m = jsonDecode(exact) as Map<String, dynamic>;
      String edit(void Function(Map<String, dynamic>) f) {
        final c = jsonDecode(exact) as Map<String, dynamic>;
        f(c);
        return jsonEncode(c);
      }

      expect(ModelProbe.check(''), ProbeOutcome.unreadable);
      expect(
        ModelProbe.check('Sure! Here it is: $exact'),
        ProbeOutcome.unreadable,
      );
      expect(
        ModelProbe.check(exact.substring(0, exact.length - 20)),
        ProbeOutcome.missingEnd,
        reason: 'a cut-off reply',
      );
      expect(
        ModelProbe.check(edit((c) => c.remove('end'))),
        ProbeOutcome.missingEnd,
      );
      expect(
        ModelProbe.check(edit((c) => c['schema'] = 'la-gen/1.1')),
        ProbeOutcome.wrongShape,
      );
      expect(
        ModelProbe.check(edit((c) => (c['items'] as List).add(m['items'][0]))),
        ProbeOutcome.wrongShape,
      );
      expect(
        ModelProbe.check(
          edit((c) => ((c['items'] as List)[1] as Map)['n'] = 3),
        ),
        ProbeOutcome.wrongShape,
      );
      expect(
        ModelProbe.check(edit((c) => c['extra'] = 1)),
        ProbeOutcome.wrongShape,
      );
      expect(ModelProbe.check('[1,2]'), ProbeOutcome.wrongShape);
      expect(ModelProbe.check('x' * 3000), ProbeOutcome.unreadable);
    });
  });

  group('probe in the capability profile', () {
    const base = ModelCapabilityProfile(label: AiChatLabel.gemini);
    const clean = ReplyObservation(
      mode: ManualOutputMode.package,
      requested: 3,
      filled: 3,
      itemProblems: 0,
      unreadable: false,
      endMarker: true,
    );
    const cut = ReplyObservation(
      mode: ManualOutputMode.package,
      requested: 3,
      filled: 1,
      itemProblems: 0,
      unreadable: false,
      endMarker: false,
    );

    test('a pass starts one step up; a fail suggests one item per line', () {
      expect(base.withProbe(true).suggestedTier, ModelSizeTier.standard);
      expect(base.withProbe(true).suggestedMode, isNull);
      expect(base.withProbe(false).suggestedTier, ModelSizeTier.compact);
      expect(base.withProbe(false).suggestedMode, ManualOutputMode.lines);
      expect(base.withProbe(true).explanation, contains('quick test worked'));
    });

    test('real replies override the probe once there are enough', () {
      final p = base.withProbe(true).record(cut).record(cut).record(cut);
      expect(p.suggestedTier, ModelSizeTier.compact);
      final q = base.withProbe(false).record(clean).record(clean).record(clean);
      expect(q.suggestedTier, ModelSizeTier.standard);
      expect(q.suggestedMode, isNull);
    });

    test('the probe result survives saving; a bad value is rejected', () {
      final p = base.withProbe(true).record(clean);
      final back = ModelCapabilityProfile.fromJson(
        jsonDecode(jsonEncode(p.toJson())),
      )!;
      expect(back.probePassed, isTrue);
      expect(back.replies, 1);
      expect(
        ModelCapabilityProfile.fromJson({...p.toJson(), 'probe_passed': 'yes'}),
        isNull,
      );
      expect(base.toJson().containsKey('probe_passed'), isFalse);
    });
  });
}
