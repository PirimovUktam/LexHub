// P1-02 and AI configuration regression, updated 2026-09-20. Captures Deno.serve
// callback and replaces Auth/quota/Gemini transport. No network or DB writes.
// This is not a real-model, source-accuracy or deployment verification.
import { assert, assertEquals, assertFalse, assertStringIncludes } from 'jsr:@std/assert@1';

Deno.test('actual handler constrains model output before HTTP 200', async (t) => {
  const env = {
    SUPABASE_URL: 'https://auth.stub.invalid',
    SUPABASE_ANON_KEY: 'local-test-placeholder',
    GEMINI_API_KEY: 'local-test-placeholder',
    LEGAL_AI_MODEL: 'local-model',
    LEGAL_AI_MODEL_FALLBACK: '',
    LEGAL_AI_GEMINI_HOST: 'https://generativelanguage.googleapis.com',
    LEGAL_AI_TIMEOUT_MS: '20',
    LEGAL_AI_DEBUG_UPSTREAM: '1',
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
  let modelStatus = 200;
  let waitForAbort = false;
  let authStatus = 200;
  let anonymous = false;
  let authThrows = false;
  let quotaStatus = 200;
  let quotaCalls = 0;
  let quotaResponse: unknown = { allowed: true, retry_after_seconds: 0, remaining: 9 };
  let upstreamHuge = false;
  let evidenceStatus = 200;
  let evidenceRows: unknown[] = [{ document_name: 'Sinov manbasi', article_number: 10,
    article_title: 'Sinov', content: 'Sinov qoidasi. Muhim istisno saqlanadi.',
    lex_url: 'https://example.invalid/source', status: 'active' }];
  const unsafeDetail = 'synthetic-sensitive-detail-must-never-be-logged';
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
        assertEquals((init && 'redirect' in init ? init.redirect : undefined), 'error');
        assert((init && 'signal' in init ? init.signal : undefined));
        if (authThrows) throw new Error(unsafeDetail);
        return Promise.resolve(Response.json({ id: 'local-test-user', is_anonymous: anonymous }, { status: authStatus }));
      }
      if (url === 'https://auth.stub.invalid/rest/v1/rpc/consume_legal_ai_quota') {
        quotaCalls++;
        assertEquals((init && 'redirect' in init ? init.redirect : undefined), 'error');
        assert((init && 'signal' in init ? init.signal : undefined));
        assertEquals((init && 'body' in init ? init.body : undefined), '{}');
        assertEquals(new Headers((init && 'headers' in init ? init.headers : undefined)).get('Authorization'), 'Bearer local-test-token');
        return Promise.resolve(Response.json(quotaResponse, { status: quotaStatus }));
      }
      if (url.startsWith('https://auth.stub.invalid/rest/v1/law_article_chunks?')) {
        assertEquals(new URL(url).searchParams.get('status'), 'eq.active');
        assertEquals(new URL(url).searchParams.get('article_number'), 'in.(10)');
        assertEquals((init && 'redirect' in init ? init.redirect : undefined), 'error');
        assert((init && 'signal' in init ? init.signal : undefined));
        assertEquals(new Headers((init && 'headers' in init ? init.headers : undefined)).get('Authorization'), 'Bearer local-test-token');
        return Promise.resolve(Response.json(evidenceRows, { status: evidenceStatus }));
      }
      if (url.startsWith('https://generativelanguage.googleapis.com/')) {
        modelCalls++;
        assertEquals((init && 'redirect' in init ? init.redirect : undefined), 'error');
        assertFalse(url.includes(env.GEMINI_API_KEY));
        assertEquals(new Headers(init && 'headers' in init ? init.headers : undefined)
          .get('x-goog-api-key'), env.GEMINI_API_KEY);
        if (waitForAbort) {
          const signal = init && 'signal' in init ? init.signal : undefined;
          assert(signal);
          return new Promise<Response>((_, reject) => {
            const abort = () => reject(new DOMException('Synthetic timeout', 'AbortError'));
            if (signal.aborted) abort();
            else signal.addEventListener('abort', abort, { once: true });
          });
        }
        if (modelStatus !== 200) {
          return Promise.resolve(Response.json({ error: unsafeDetail }, {
            status: modelStatus,
          }));
        }
        if (upstreamHuge) return Promise.resolve(new Response('x'.repeat(256 * 1024 + 1)));
        modelPrompt = String(init && 'body' in init ? init.body : '');
        return Promise.resolve(Response.json({
          candidates: [{ content: { parts: [{ text: JSON.stringify(modelResponse) }] } }],
        }));
      }
      throw new Error('Unexpected network request in local contract test');
    };
    await import('./index.ts');
    assert(captured.handler, 'Production entrypoint did not register its handler');
    const invoke = (retrieved_chunks: unknown[], category: unknown = undefined) => captured.handler?.(new Request(
      'https://function.stub.invalid/legal-ai', {
        method: 'POST', headers: { Authorization: 'Bearer local-test-token', 'Content-Type': 'application/json' },
        body: JSON.stringify({ query_id: 'local-query', query_text: 'Sinov savoli', category, retrieved_chunks }),
      },
    ));

    await t.step('unsupported methods and missing/anonymous/invalid auth cannot spend quota', async () => {
      const handler = captured.handler;
      assert(handler);
      const method = await handler(new Request('https://function.stub.invalid/legal-ai'));
      assertEquals(method.status, 405);
      assertEquals(method.headers.get('Allow'), 'POST, OPTIONS');
      const unauthenticated = await handler(new Request('https://function.stub.invalid/legal-ai', { method: 'POST' }));
      assertEquals(unauthenticated.status, 401);
      assertEquals(authCalls, 0);
      anonymous = true;
      assertEquals((await invoke([]))?.status, 401);
      anonymous = false;
      authStatus = 401;
      assertEquals((await invoke([]))?.status, 401);
      authStatus = 200;
      assertEquals(quotaCalls, 0);
      assertEquals(modelCalls, 0);
    });

    await t.step('missing key fails closed without calling Gemini', async () => {
      Deno.env.delete('GEMINI_API_KEY');
      try {
        const response = await invoke([]);
        assert(response);
        assertEquals(response.status, 503);
        assertEquals((await response.json()).error.code, 'ai_not_configured');
        assertEquals(modelCalls, 0);
      } finally {
        Deno.env.set('GEMINI_API_KEY', env.GEMINI_API_KEY);
      }
    });

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
    await t.step('nullable category from the Flutter client remains supported', async () => {
      assertEquals((await invoke([], null))?.status, 200);
      assertEquals((await invoke([], {}))?.status, 400);
    });
    await t.step('forged client source text/title/URL never reaches the model', async () => {
      modelResponse = { evidence_refs: [1] };
      const response = await invoke([{ document_name: 'Sinov manbasi', article_number: 10,
        article_title: 'FORGED_TITLE', content: 'FORGED_CONTENT', lex_url: 'https://forged.invalid' }]);
      assertEquals(response?.status, 200);
      assertFalse(modelPrompt.includes('FORGED_'));
      assertFalse(modelPrompt.includes('forged.invalid'));
      assertStringIncludes(modelPrompt, 'Muhim istisno saqlanadi.');
    });
    await t.step('unknown and ambiguous canonical sources cannot ground claims', async () => {
      const response = await invoke([{ document_name: 'Forged document', article_number: 10,
        content: 'FORGED_CONTENT' }]);
      assertEquals((await response?.json()).legal_basis, []);
      const saved = evidenceRows;
      evidenceRows = [...saved, ...saved];
      try {
        const ambiguous = await invoke([{ document_name: 'Sinov manbasi', article_number: 10 }]);
        assertEquals((await ambiguous?.json()).legal_basis, []);
      } finally { evidenceRows = saved; }
    });
    await t.step('source lookup failure is closed and does not call the model', async () => {
      evidenceStatus = 503;
      const before = modelCalls;
      try {
        const response = await invoke([{ document_name: 'Sinov manbasi', article_number: 10 }]);
        assertEquals(response?.status, 503);
        assertEquals((await response?.json()).error.code, 'evidence_unavailable');
        assertEquals(modelCalls, before);
      } finally { evidenceStatus = 200; }
    });
    await t.step('quota failure is distinct from missing configuration', async () => {
      modelStatus = 429;
      const response = await invoke([]);
      assert(response);
      assertEquals(response.status, 502);
      const body = await response.json();
      assertEquals(body.error.code, 'ai_quota');
      assertEquals(Object.keys(body.error).sort(), ['code', 'message']);
    });

    await t.step('upstream request is aborted and reported as a timeout', async () => {
      waitForAbort = true;
      const response = await invoke([]);
      assert(response);
      assertEquals(response.status, 502);
      const body = await response.json();
      assertEquals(body.error.code, 'ai_timeout');
      assertEquals(Object.keys(body.error).sort(), ['code', 'message']);
      waitForAbort = false;
    });

    await t.step('durable rejection returns 429 and Retry-After without provider work', async () => {
      const before = modelCalls;
      quotaResponse = { allowed: false, retry_after_seconds: 121, remaining: 0 };
      const response = await invoke([]);
      assert(response);
      assertEquals(response.status, 429);
      assertEquals(response.headers.get('Retry-After'), '121');
      assertEquals(response.headers.get('Cache-Control'), 'no-store');
      assertEquals(response.headers.get('Access-Control-Expose-Headers'), 'Retry-After');
      assertEquals((await response.json()).error.code, 'rate_limited');
      assertEquals(modelCalls, before);
      quotaResponse = { allowed: true, retry_after_seconds: 0, remaining: 9 };
    });

    await t.step('quota backend failure or malformed decision fails closed', async () => {
      const before = modelCalls;
      quotaStatus = 500;
      let response = await invoke([]);
      assert(response);
      assertEquals(response.status, 503);
      assertEquals((await response.json()).error.code, 'rate_limit_unavailable');
      quotaStatus = 200;
      for (const invalid of [{ allowed: 'true' }, { allowed: true, retry_after_seconds: -1 },
        { allowed: false, retry_after_seconds: 0 }]) {
        quotaResponse = invalid;
        response = await invoke([]);
        assertEquals(response?.status, 503);
      }
      quotaResponse = { allowed: true, retry_after_seconds: 0, remaining: 9 };
      assertEquals(modelCalls, before);
    });

    await t.step('malformed schema, unsafe URL, oversized fields and controls fail before quota', async () => {
      const handler = captured.handler;
      assert(handler);
      const before = quotaCalls;
      for (const body of [[], null, { query_text: '' }, { query_text: 'x'.repeat(4001) },
        { query_text: 'q\u0000x' }, { query_text: 'q', category: [] },
        { query_text: 'q', query_id: 'x'.repeat(121) },
        { query_text: 'q', retrieved_chunks: {} },
        { query_text: 'q', retrieved_chunks: [null] },
        { query_text: 'q', retrieved_chunks: [{ content: 'x'.repeat(6001) }] },
        { query_text: 'q', retrieved_chunks: [{ lex_url: 'javascript:alert(1)' }] },
        { query_text: 'q', retrieved_chunks: [{ lex_url: 'https://name@example.invalid' }] },
        { query_text: 'q', retrieved_chunks: Array(9).fill({ content: 'x' }) }]) {
        const response = await handler(new Request('https://function.stub.invalid/legal-ai', {
          method: 'POST', headers: { Authorization: 'Bearer local-test-token', 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        }));
        assertEquals(response.status, 400);
        assertEquals((await response.json()).error.code, 'invalid_request');
      }
      for (const [type, body, status] of [['text/plain', '{}', 415], ['application/json', '{', 400]] as const) {
        const response = await handler(new Request('https://function.stub.invalid/legal-ai', {
          method: 'POST', headers: { Authorization: 'Bearer local-test-token', 'Content-Type': type }, body,
        }));
        assertEquals(response.status, status);
      }
      assertEquals(quotaCalls, before);
    });

    await t.step('actual streamed size is bounded even with forged Content-Length', async () => {
      const handler = captured.handler;
      assert(handler);
      const before = quotaCalls;
      for (const declared of ['1', '262145']) {
        let cancelled = false;
        let emitted = 0;
        const stream = new ReadableStream<Uint8Array>({
          pull(controller) {
            if (emitted++ < 10) controller.enqueue(new Uint8Array(65536).fill(120));
            else controller.close();
          },
          cancel() { cancelled = true; },
        });
        const response = await handler(new Request('https://function.stub.invalid/legal-ai', {
          method: 'POST', headers: { Authorization: 'Bearer local-test-token',
            'Content-Type': 'application/json', 'Content-Length': declared }, body: stream,
        }));
        assertEquals(response.status, 413);
        assertEquals((await response.json()).error.code, 'payload_too_large');
        assert(cancelled);
      }
      assertEquals(quotaCalls, before);
    });

    await t.step('slow request body times out and cancels before provider/quota work', async () => {
      const handler = captured.handler;
      assert(handler);
      const before = quotaCalls;
      let cancelled = false;
      const stream = new ReadableStream<Uint8Array>({ cancel() { cancelled = true; } });
      const started = Date.now();
      const response = await handler(new Request('https://function.stub.invalid/legal-ai', {
        method: 'POST', headers: { Authorization: 'Bearer local-test-token',
          'Content-Type': 'application/json' }, body: stream,
      }));
      assertEquals(response.status, 408);
      assertEquals((await response.json()).error.code, 'request_timeout');
      assert(Date.now() - started < 7000);
      assert(cancelled);
      assertEquals(quotaCalls, before);
    });

    await t.step('client instruction/config fields cannot replace server prompt or upstream', async () => {
      const handler = captured.handler;
      assert(handler);
      modelStatus = 200;
      const response = await handler(new Request('https://function.stub.invalid/legal-ai', {
        method: 'POST', headers: { Authorization: 'Bearer local-test-token', 'Content-Type': 'application/json' },
        body: JSON.stringify({ query_text: "Unicode: O‘zbek; <script>x</script>; '; SELECT 1; --",
          system_instruction: 'INJECTED_SYSTEM_OVERRIDE',
          gemini_host: 'https://untrusted.example.invalid', model: 'INJECTED_MODEL', retrieved_chunks: [] }),
      }));
      assert(response);
      assertEquals(response.status, 200);
      assertStringIncludes(modelPrompt, 'systemInstruction');
      assertFalse(modelPrompt.includes('INJECTED_SYSTEM_OVERRIDE'));
      assertFalse(modelPrompt.includes('INJECTED_MODEL'));
      assertFalse(modelPrompt.includes('untrusted.example.invalid'));
    });

    await t.step('provider and auth diagnostics never reach responses/logs, even with debug enabled', async () => {
      const originalLog = console.log;
      const lines: string[] = [];
      console.log = (...args: unknown[]) => lines.push(args.join(' '));
      try {
        modelStatus = 403;
        let response = await invoke([]);
        assert(response);
        assertEquals(response.status, 502);
        const body = await response.json();
        assertEquals(body.error.code, 'ai_key_rejected');
        assertEquals(Object.keys(body.error).sort(), ['code', 'message']);
        assertFalse(JSON.stringify(body).includes(unsafeDetail));
        authThrows = true;
        response = await invoke([]);
        assert(response);
        assertEquals(response.status, 503);
        assertFalse((await response.text()).includes(unsafeDetail));
        assertFalse(lines.join('\n').includes(unsafeDetail));
      } finally { console.log = originalLog; authThrows = false; modelStatus = 200; }
    });

    await t.step('oversized provider body is rejected without echoing data', async () => {
      upstreamHuge = true;
      const response = await invoke([]);
      assert(response);
      assertEquals(response.status, 502);
      assertEquals((await response.json()).error.code, 'ai_unavailable');
      upstreamHuge = false;
    });

    await t.step('untrusted upstream host cannot receive provider key', async () => {
      const before = modelCalls;
      Deno.env.set('LEGAL_AI_GEMINI_HOST', 'https://untrusted.example.invalid');
      await import('./index.ts?untrusted-host');
      const response = await invoke([]);
      assert(response);
      assertEquals(response.status, 503);
      assertEquals((await response.json()).error.code, 'ai_not_configured');
      assertEquals(modelCalls, before);
    });
    assert(authCalls >= 30, 'Handler security paths must execute real auth transport');
    assert(quotaCalls >= 10, 'Quota decisions must not be vacuous');
    assert(modelCalls >= 6, 'Successful and failing provider paths must execute');
  } finally {
    globalThis.fetch = originalFetch;
    Object.defineProperty(Deno, 'serve', serveDescriptor);
    for (const [key, value] of previousEnv) {
      if (value === undefined) Deno.env.delete(key);
      else Deno.env.set(key, value);
    }
  }
});
