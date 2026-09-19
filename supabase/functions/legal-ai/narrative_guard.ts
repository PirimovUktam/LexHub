// P1-02: model prose is not proof. Only source selection reaches the response.
// Matching supplied context does NOT verify its authority, currency or relevance.
import {
  asString,
  type Chunk,
  findGroundingChunk,
  firstInteger,
  groundLegalBasis,
} from './grounding.ts';

const MAX_SOURCES = 3;
const MAX_SUMMARY_QUOTE_CHARS = 900;

export function constrainNarrative(
  parsed: Record<string, unknown>,
  chunks: Chunk[],
): { fields: Record<string, unknown>; dropped: number; replacedQuotes: number } {
  const selected: Chunk[] = [];
  let dropped = 0;
  let replacedQuotes = 0;
  const add = (chunk: Chunk | null | undefined): void => {
    if (!chunk || !chunk.documentName.trim() || !chunk.content.trim() ||
      firstInteger(chunk.articleNumber) === 0) {
      dropped++;
      return;
    }
    if (selected.includes(chunk) || selected.length >= MAX_SOURCES) return;
    selected.push(chunk);
  };

  if (Object.hasOwn(parsed, 'evidence_refs')) {
    // References are 1-based positions in THIS request, never model-supplied text.
    const refs = Array.isArray(parsed.evidence_refs) ? parsed.evidence_refs : [];
    for (const ref of refs) {
      add(typeof ref === 'number' && Number.isInteger(ref) && ref > 0
        ? chunks[ref - 1]
        : null);
    }
  } else {
    // Compatibility with the existing direct/legacy JSON contract: use only
    // its source selection. None of its summary, steps or risk prose survives.
    const grounded = groundLegalBasis(parsed.legal_basis ?? parsed.legalBasis, chunks);
    dropped = grounded.dropped;
    replacedQuotes = grounded.replacedQuotes;
    for (const article of grounded.kept) {
      add(findGroundingChunk(article.law_name, article.article_number, chunks));
    }
  }

  const hasEvidence = selected.length > 0;
  const label = (c: Chunk): string => `${c.documentName}, ${firstInteger(c.articleNumber)}-modda`;
  const summary = hasEvidence
    ? 'Quyidagi manbalar savolingizga aloqador bo‘lishi mumkin. Bu yakuniy huquqiy xulosa emas.' +
      '\n\n' + selected.map((c, i) => {
        // Never shorten a source mid-sentence or let the model select a quote
        // omitting an exception/negation. Longer content stays in legal_basis.
        const quote = c.content.length <= MAX_SUMMARY_QUOTE_CHARS
          ? `«${c.content}»`
          : 'Manbaning to‘liq matnini huquqiy asoslar bo‘limida tekshiring.';
        return `[${i + 1}] ${label(c)}\n${quote}`;
      }).join('\n\n')
    : 'Ushbu savol uchun yetarli huquqiy manba aniqlanmadi. Huquq, majburiyat yoki muddat bo‘yicha xulosa berish uchun qo‘shimcha tekshiruv kerak.';

  const rawRisk = parsed.risk_assessment ?? parsed.riskAssessment;
  const risk = rawRisk !== null && typeof rawRisk === 'object'
    ? rawRisk as Record<string, unknown>
    : {};
  const level = asString(risk.level).toLowerCase().trim();
  return {
    dropped,
    replacedQuotes,
    fields: {
      relatable_summary: summary,
      actionable_steps: [
        'Vaziyatga oid hujjatlar va yozishmalarni bir joyga jamlang.',
        'Voqealar sanalarini va javobsiz savollaringizni yozib qo‘ying.',
        ...selected.map((c, i) => `[${i + 1}] ${label(c)}: Manbaning to‘liq matnini huquqiy asoslar bo‘limida tekshiring.`),
        'Manbalarning amaldagi tahriri, vaziyatingizga tatbiqi va muddatlarni yurist bilan tekshiring.',
      ],
      legal_basis: selected.map((c) => ({
        law_name: c.documentName,
        article_number: `${firstInteger(c.articleNumber)}-modda`,
        article_title: c.articleTitle,
        article_text: c.content,
        lex_url: c.lexUrl,
      })),
      risk_assessment: {
        // A model warning can raise caution, never certify low risk. No model
        // free text or inferred remaining deadline is presented as evidence.
        level: level === 'critical' || level === 'high' ? level : 'medium',
        summary: 'Xavf darajasi dastlabki baho: holatning barcha faktlari va manbalarning tatbiqi tekshirilmagan.',
        limitations: [
          'Kontekstdagi matnga moslik uning dolzarbligi yoki vaziyatingizga tatbiqini tasdiqlamaydi.',
          'Voqea sanasi va tegishli protsess aniqlanmagani uchun qolgan muddat hisoblanmagan.',
        ],
        requires_lawyer: true,
        deadline_days: null,
      },
      source: hasEvidence ? 'llm' : 'deterministic',
      narrative_policy: 'source-selection-v1',
      evidence_refs: selected.map((c) => chunks.indexOf(c) + 1),
    },
  };
}
