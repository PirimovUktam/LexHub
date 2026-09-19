// P1-02 regression, measured 2026-09-19: source IDs cannot validate free prose.
// Local tests do not prove source accuracy, model relevance or deployment.
import { assertEquals, assertFalse, assertStringIncludes } from 'jsr:@std/assert@1';
import { type Chunk } from './grounding.ts';
import { constrainNarrative } from './narrative_guard.ts';

// Synthetic source fixture: no assertion about actual law.
const source: Chunk = {
  documentName: 'Sinov manbasi',
  articleNumber: '10',
  articleTitle: 'Sinov sharti',
  content: 'Qoida faqat ko‘rsatilgan shart bajarilganda qo‘llanadi. Istisno saqlanadi.',
  lexUrl: 'https://example.invalid/source',
};
const invented = '777-modda bo‘yicha bugun pul to‘lash shart; g‘alaba kafolatlanadi.';

Deno.test('no evidence strips claims from summary, steps, risk and limitations', () => {
  const { fields } = constrainNarrative({
    relatable_summary: invented,
    actionable_steps: [invented],
    risk_assessment: {
      level: 'low', summary: invented, limitations: [invented],
      requires_lawyer: false, deadline_days: 1,
    },
  }, []);
  assertFalse(JSON.stringify(fields).includes(invented));
  assertEquals(fields.legal_basis, []);
  assertEquals(fields.source, 'deterministic');
  assertStringIncludes(String(fields.relatable_summary), 'yetarli huquqiy manba aniqlanmadi');
  const risk = fields.risk_assessment as Record<string, unknown>;
  assertEquals(risk.level, 'medium');
  assertEquals(risk.deadline_days, null);
  assertEquals(risk.requires_lawyer, true);
});

Deno.test('valid selection preserves entire source and binds summary and steps to it', () => {
  const { fields } = constrainNarrative({
    evidence_refs: [1], relatable_summary: invented, actionable_steps: [invented],
  }, [source]);
  assertEquals(fields.source, 'llm');
  assertEquals(fields.evidence_refs, [1]);
  assertEquals(fields.legal_basis, [{
    law_name: source.documentName, article_number: '10-modda',
    article_title: source.articleTitle, article_text: source.content,
    lex_url: source.lexUrl,
  }]);
  assertStringIncludes(String(fields.relatable_summary), source.content);
  assertStringIncludes(String(fields.relatable_summary), '[1] Sinov manbasi, 10-modda');
  assertStringIncludes(JSON.stringify(fields.actionable_steps), '[1] Sinov manbasi, 10-modda');
  assertFalse(JSON.stringify(fields).includes(invented));
});

Deno.test('legacy source selection works without preserving cherry-picked model quotes', () => {
  const { fields, replacedQuotes } = constrainNarrative({
    legalBasis: [{ lawName: source.documentName, articleNumber: 10,
      articleText: invented, lexUrl: 'https://example.invalid/invented' }],
    relatableSummary: invented, actionableSteps: [invented],
  }, [source]);
  assertEquals(fields.evidence_refs, [1]);
  assertEquals(replacedQuotes, 1);
  assertStringIncludes(String(fields.relatable_summary), 'Istisno saqlanadi.');
  assertFalse(JSON.stringify(fields).includes(invented));
  assertFalse(JSON.stringify(fields).includes('/invented'));
});

Deno.test('invalid explicit references fail closed without reviving legacy selections', () => {
  for (const refs of [null, '1', [0, -1, 0.5, 2, '1', {}, null]]) {
    const { fields } = constrainNarrative({ evidence_refs: refs,
      legal_basis: [{ law_name: source.documentName, article_number: 10 }],
    }, [source]);
    assertEquals(fields.legal_basis, []);
    assertEquals(fields.source, 'deterministic');
  }
});

Deno.test('empty and unknown sources cannot establish evidence', () => {
  const { fields } = constrainNarrative({ evidence_refs: [1, 2] }, [
    { ...source, content: ' ' }, { ...source, articleNumber: 'unknown' },
  ]);
  assertEquals(fields.legal_basis, []);
  assertEquals(fields.source, 'deterministic');
});

Deno.test('long source is not truncated into a potentially misleading partial quote', () => {
  const content = 'Sinov matni. '.repeat(100) + 'Muhim istisno oxirida saqlanadi.';
  const { fields } = constrainNarrative({ evidence_refs: [1] }, [{ ...source, content }]);
  assertFalse(String(fields.relatable_summary).includes('Sinov matni.'));
  assertStringIncludes(String(fields.relatable_summary), 'to‘liq matnini');
  const articles = fields.legal_basis as Record<string, string>[];
  assertEquals(articles[0].article_text, content);
});

Deno.test('duplicate references and excessive selections remain bounded', () => {
  const chunks = [1, 2, 3, 4].map((n) => ({ ...source, articleNumber: String(n) }));
  const { fields } = constrainNarrative({ evidence_refs: [1, 1, 2, 3, 4] }, chunks);
  assertEquals(fields.evidence_refs, [1, 2, 3]);
  assertEquals((fields.legal_basis as unknown[]).length, 3);
});

Deno.test('high warnings survive but free risk text and inferred deadlines do not', () => {
  for (const level of ['high', 'critical']) {
    const { fields } = constrainNarrative({ evidence_refs: [1],
      risk_assessment: { level, summary: invented, deadline_days: 30 },
    }, [source]);
    const risk = fields.risk_assessment as Record<string, unknown>;
    assertEquals(risk.level, level);
    assertEquals(risk.deadline_days, null);
    assertFalse(JSON.stringify(risk).includes(invented));
  }
});
