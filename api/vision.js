// Vercel Serverless Proxy for NagarNex Vision AI
// Keeps GEMINI_API_KEY / OPENROUTER_API_KEY 100% secure on the server.
// Set GEMINI_API_KEY (or OPENROUTER_API_KEY) in Vercel Project -> Settings -> Environment Variables.

// In-memory rate & daily quota guard to protect Gemini free-tier limits
const RATE_WINDOW_MS = 60_000;
const MAX_PER_MIN = 12;
const MAX_PER_DAY = 200;
const ipHits = new Map();
let dayKey = new Date().toISOString().slice(0, 10);
let dailyCount = 0;

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const today = new Date().toISOString().slice(0, 10);
  if (today !== dayKey) {
    dayKey = today;
    dailyCount = 0;
  }
  if (dailyCount >= MAX_PER_DAY) {
    return res.status(429).json({ error: 'Daily AI quota cap reached (saving free tier).' });
  }

  const ip = req.headers['x-forwarded-for']?.toString().split(',')[0]?.trim() || 'local';
  const now = Date.now();
  if (ipHits.size > 500) {
    for (const [k, ts] of ipHits.entries()) {
      const fresh = ts.filter((t) => now - t < RATE_WINDOW_MS);
      if (fresh.length === 0) ipHits.delete(k);
      else ipHits.set(k, fresh);
    }
  }
  const hits = (ipHits.get(ip) || []).filter((t) => now - t < RATE_WINDOW_MS);
  if (hits.length >= MAX_PER_MIN) {
    return res.status(429).json({ error: 'Rate limit exceeded. Please wait a few seconds.' });
  }
  hits.push(now);
  ipHits.set(ip, hits);

  const { mode = 'classify', imageBase64, beforeImageBase64 } = req.body || {};
  if (!imageBase64 || typeof imageBase64 !== 'string') {
    return res.status(400).json({ error: 'Missing or invalid imageBase64' });
  }
  if (imageBase64.length > 2_000_000) {
    return res.status(413).json({ error: 'Image too large; compress below 1.5MB.' });
  }

  const safeJsonParse = (raw) => {
    try {
      const cleaned = String(raw || '').replace(/```json|```/g, '').trim();
      return JSON.parse(cleaned);
    } catch {
      return null;
    }
  };

  const geminiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
  const openRouterKey = process.env.OPENROUTER_API_KEY;

  const prompt =
    mode === 'verify'
      ? 'Compare the street waste Before and After photo(s). Return ONLY valid JSON: {"cleared": boolean, "match_score": integer 0-100, "summary": string}.'
      : 'Analyze this image for a Bengaluru civic waste reporting app. First check if it actually shows street garbage, litter, overflowing bins, plastic/food/e-waste, or debris. If it is unrelated (e.g. landscape, poster, meme, screenshot, selfie, clean road), set "is_waste": false and give a short "rejection_reason". Always include a crisp 1-line "summary" describing what is actually visible in the image. Return ONLY valid JSON with keys: "is_waste" (boolean), "rejection_reason" (string), "summary" (string, max 18 words describing the image), "waste_type" ("Plastic"|"Wet/Food"|"Glass"|"E-Waste"|"Mixed/Debris"), "severity" ("High"|"Medium"|"Low"), "confidence" (0.0 to 1.0), "contains_faces_or_plates" (boolean).';

  const geminiParts = [
    { text: prompt },
    ...(beforeImageBase64
      ? [{ inline_data: { mime_type: 'image/png', data: beforeImageBase64 } }]
      : []),
    { inline_data: { mime_type: 'image/png', data: imageBase64 } },
  ];

  try {
    if (geminiKey) {
      const models = ['gemini-3.8-flash', 'gemini-2.5-flash'];
      let lastStatus = 500;
      let lastErr = 'Gemini API error';
      for (const model of models) {
        const r = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ parts: geminiParts }],
              generationConfig: {
                responseMimeType: 'application/json',
                maxOutputTokens: 256,
                temperature: 0.1,
              },
            }),
          }
        );
        dailyCount += 1;
        const data = await r.json();
        if (r.ok) {
          const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
          const parsed = safeJsonParse(text);
          if (parsed) return res.status(200).json(parsed);
        }
        lastStatus = r.status;
        lastErr = data?.error?.message || `Gemini API error (${r.status})`;
        if (r.status !== 404) break;
      }
      return res.status(lastStatus).json({ error: lastErr });
    }

    if (openRouterKey) {
      const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${openRouterKey}`,
        },
        body: JSON.stringify({
          model: 'openrouter/free',
          messages: [
            {
              role: 'user',
              content: [
                { type: 'text', text: prompt },
                {
                  type: 'image_url',
                  image_url: { url: `data:image/png;base64,${imageBase64}` },
                },
              ],
            },
          ],
        }),
      });
      const data = await r.json();
      const raw = data?.choices?.[0]?.message?.content || '{}';
      const cleaned = raw.replace(/```json|```/g, '').trim();
      return res.status(200).json(JSON.parse(cleaned));
    }

    return res.status(503).json({ error: 'No backend AI key configured' });
  } catch (err) {
    return res.status(500).json({ error: String(err) });
  }
}
