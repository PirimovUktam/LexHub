// P1-02 handler regression, measured 2026-09-19. Captures the actual Deno.serve
// callback and replaces only Auth/Gemini transport. No network or DB writes.
// This is not a real-model, source-accuracy or deployment verification.
import { assert, assertEquals, assertFalse, assertStringIncludes } from 'jsr:@std/assert@1';

Deno.test('actual handler constrains model output before HTTP 200', async (t) => {
  const env = {
    SUPABASE_URL: 'https://auth.stub.invalid',
    SUPABASE_ANON_KEY: 'local-test-placeholder',
    GEMINI_API_KEY: 'local-test-placeholder',
    LEGAL_AI_MODEL: 'local-model',
    LEGAL_AI_MODEL_FALLBACK: '',
    LEGAL_AI_GEMINI_HOST: 'https://model.stub.invalid',
    LEGAL_AI_MAX_PER_HOUR: '100',
  };
  const previousEnv = new Map(Object.keys(env).map((key) => [key, Deno.env.get(key)]));
  const originalFetch = globalThis.fetch;
  const serveDescriptor = Object.getOwnPropertyDescriptor(Deno, 'serve');
  assert(serveDescriptor);
  const captured: { handler?: (request: Request) => Promise<Response> } = {};
  const invented = '777-modda bo‘yicha hozir pul yuboring; natija kafolatlanadi.';
  let modelResponse: Record<string, unknown> = {};
  let modelPrompt = '';
  let authCalls = 0;
  let modelCalls = 0;
  try {
    for (const [key, value] of Object.entries(env)) Deno.env.set(key, value);
    Object.defineProperty(Deno, 'serve', {
      configurable: true,
      value: (handler: (request: Request) => Promise<Response>) => {
        captured.handler = handler;
      },
    });
    globalThis.fetch = (input, init) => {
      const url = input instanceof Request ? input.url : String(input);
      if (url === 'https://auth.stub.invalid/auth/v1/user') {
        authCalls++;
        return Promise.resolve(Response.json({ id: 'local-test-user', is_anonymous: false }));
      }
      if (url.startsWith('https://model.stub.invalid/')) {
        modelCalls++;
        modelPrompt = String(init && 'body' in init ? init.body : '');
        return Promise.resolve(Response.json({
          candidates: [{ content: { parts: [{ text: JSON.stringify(modelResponse) }] } }],
        }));
      }
      throw new Error('Unexpected network request in local contract test');
    };
    await import('./index.ts');
    assert(captured.handler, 'Production entrypoint did not register its handler');
    const invoke = (retrieved_chunks: unknown[]) => captured.handler?.(new Request(
      'https://function.stub.invalid/legal-ai', {
        method: 'POST', headers: { Authorization: 'Bearer local-test-token' },
        body: JSON.stringify({ query_id: 'local-query', query_text: 'Sinov savoli', retrieved_chunks }),
      },
    ));

    await t.step('empty evidence cannot produce invented legal instructions', async () => {
      modelResponse = {
        relatable_summary: invented, actionable_steps: [invented],
        risk_assessment: { level: 'low', summary: invented, limitations: [invented], deadline_days: 1 },
      };
      const response = await invoke([]);
      assert(response);
      assertEquals(response.status, 200);
      const body = await response.json();
      assertEquals(body.source, 'deterministic');
      assertEquals(body.legal_basis, []);
      assertFalse(JSON.stringify(body).includes(invented));
      assertEquals(body.risk_assessment.deadline_days, null);
    });

    await t.step('model selection is retained but prose is source-bounded', async () => {
      const content = 'Sinov qoidasi. Muhim istisno saqlanadi.';
      modelResponse = { evidence_refs: [1], relatable_summary: invented,
        actionable_steps: [invented], risk_assessment: { level: 'high', summary: invented } };
      const response = await invoke([{ document_name: 'Sinov manbasi', article_number: 10,
        article_title: 'Sinov', content, lex_url: 'https://example.invalid/source' }]);
      assert(response);
      assertEquals(response.status, 200);
      const body = await response.json();
      assertEquals(body.source, 'llm');
      assertEquals(body.narrative_policy, 'source-selection-v1');
      assertEquals(body.legal_basis.length, 1);
      assertEquals(body.legal_basis[0].article_text, content);
      assertStringIncludes(body.relatable_summary, content);
      assertFalse(JSON.stringify(body).includes(invented));
      assertEquals(body.risk_assessment.level, 'high');
      assertStringIncludes(modelPrompt, 'evidence_refs');
    });
    assertEquals(authCalls, 2);
    assertEquals(modelCalls, 2);
  } finally {
    globalThis.fetch = originalFetch;
    Object.defineProperty(Deno, 'serve', serveDescriptor);
    for (const [key, value] of previousEnv) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});
