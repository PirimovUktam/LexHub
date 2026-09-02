// LexHub — `legal-ai` uchun FAKE Gemini upstream (faqat lokal test).
//
// MAQSAD: haqiqiy `GEMINI_API_KEY` bo'lmagan holatda ham to'liq zanjirni
// (auth → validatsiya → rate limit → upstream → JSON ajratish → grounding →
// 200 javob) REAL RUNTIME'da tekshirish. Bu Google'ni ALMASHTIRMAYDI va
// deploy'ga KETMAYDI — `index.ts` faqat `LEGAL_AI_GEMINI_HOST` o'rnatilganda
// bu yerga murojaat qiladi.
//
// Ishga tushirish:
//   deno run --allow-net=0.0.0.0:8787 supabase/functions/legal-ai/fake_gemini.ts
//
// DIQQAT: qaytarilgan javob ATAYLAB "yomon" — bitta asoslangan modda, bitta
// TO'QIB CHIQARILGAN modda, ```json fence va noto'g'ri `level` qiymati bilan.
// Shunday qilib server tomonidagi filtrlar ISHLAYOTGANI ko'rinadi.
const PAYLOAD = {
  relatable_summary: "Sizni noqonuniy bo'shatgan bo'lsalar, ishga tiklanish huquqingiz bor.",
  actionable_steps: [
    '1. Buyruq nusxasini talab qiling.',
    '2. Mehnat inspeksiyasiga murojaat qiling.',
    '3. Bir oy ichida sudga ariza bering.',
  ],
  legal_basis: [
    {
      law_name: "O'zbekiston Respublikasi Mehnat kodeksi",
      article_number: '161-modda',
      article_title: 'Ishga tiklash',
      article_text: "Noqonuniy bo'shatilgan xodim ishga tiklanadi.",
      lex_url: 'https://lex.uz/docs/1',
    },
    {
      // TO'QIB CHIQARILGAN: kontekstda bunday modda YO'Q.
      law_name: "O'zbekiston Respublikasi Jinoyat kodeksi",
      article_number: '4242-modda',
      article_title: 'Mavjud emas',
      article_text: 'Bu modda kontekstda berilmagan.',
      lex_url: '',
    },
  ],
  risk_assessment: {
    level: 'juda-yuqori', // yaroqsiz enum → server `medium` ga normallashtiradi
    summary: "Muddat o'tib ketsa da'vo qilish huquqi yo'qoladi.",
    limitations: ['Mehnat shartnomasi yozma bo'
      + 'lmasa dalil to\'plash qiyin.'],
    requires_lawyer: true,
    deadline_days: 30.7, // butun songa keltirilishi kerak
  },
  // Server bu maydonni E'TIBORSIZ qoldirishi kerak (emergency client tomonda
  // deterministik hisoblanadi).
  emergency_protocol: { is_emergency: true, title: 'SOXTA' },
};

Deno.serve({ port: 8787 }, (req: Request): Response => {
  const text = '```json\n' + JSON.stringify(PAYLOAD) + '\n```';
  console.log(`[fake-gemini] ${req.method} ${new URL(req.url).pathname} ` +
    `key_header=${req.headers.get('x-goog-api-key') !== null}`);
  return new Response(
    JSON.stringify({ candidates: [{ content: { parts: [{ text }] } }] }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
