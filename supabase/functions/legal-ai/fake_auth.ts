// LOKAL TEST DOUBLE — Supabase Auth `/auth/v1/user` o'rniga.
//
// NIMA UCHUN: `index.ts` haqiqiy foydalanuvchini FAQAT
// `GET {SUPABASE_URL}/auth/v1/user` orqali aniqlaydi (platformaning
// `verify_jwt` tekshiruvi YETARLI EMAS — anon/publishable kalit ham
// "haqiqiy" JWT hisoblanadi). Shu sababli 200 yo'lini offline tekshirish
// uchun shu endpoint'ning ishonchli dublyori kerak.
//
// PRODUCTION'GA HECH QANDAY ALOQASI YO'Q: faqat `SUPABASE_URL` ataylab
// `http://localhost:8788` ga o'rnatilganda chaqiriladi. Deploy paytida
// Supabase o'z `SUPABASE_URL`ini beradi.
//
// ISHGA TUSHIRISH:
//   deno run --allow-net --allow-env fake_auth.ts
//
// SHARTLAR:
//   Authorization: Bearer test-user-token   -> 200 {id, is_anonymous:false}
//   Authorization: Bearer anon-...          -> 200 {id, is_anonymous:true}
//   boshqa har qanday holat                 -> 401
const PORT = Number(Deno.env.get('FAKE_AUTH_PORT') ?? '8788');

const VALID_USER_TOKEN = 'test-user-token';
const ANON_TOKEN_PREFIX = 'anon-';

Deno.serve({ port: PORT }, (req: Request) => {
  const url = new URL(req.url);
  const auth = req.headers.get('Authorization') ?? '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  console.log(`[fake_auth] ${req.method} ${url.pathname} token=${token || '(none)'}`);

  if (url.pathname !== '/auth/v1/user') {
    return new Response('not found', { status: 404 });
  }

  if (token === VALID_USER_TOKEN) {
    return Response.json({
      id: '00000000-0000-4000-8000-00000000beef',
      email: 'local_probe@example.test',
      is_anonymous: false,
    });
  }

  if (token.startsWith(ANON_TOKEN_PREFIX)) {
    // Anonim (yoki anon kalit) — funksiya buni RAD ETISHI shart.
    return Response.json({
      id: '00000000-0000-4000-8000-0000000a0a0a',
      is_anonymous: true,
    });
  }

  return new Response(JSON.stringify({ message: 'invalid token' }), {
    status: 401,
    headers: { 'Content-Type': 'application/json' },
  });
});

console.log(`[fake_auth] listening on http://localhost:${PORT}`);
