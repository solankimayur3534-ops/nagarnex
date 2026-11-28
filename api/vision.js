// Vercel Serverless Proxy for NagarNex Vision AI
// Priority: 1. NVIDIA NIM (nemotron-3.5-super-vl-120b-a12b) -> 2. Gemini -> 3. OpenRouter
// Set NVIDIA_NIM_API_KEY (and optionally GEMINI_API_KEY / OPENROUTER_API_KEY) in Vercel Env Vars.

const RATE_WINDOW_MS = 60_000;
const MAX_PER_MIN = 40;
const MAX_PER_DAY = 2000;
const ipHits = new Map();
let dayKey = new Date().toISOString().slice(0, 10);
let dailyCount = 0;

const ALLOWED_MIMES = new Set(['image/jpeg', 'image/png', 'image/webp']);

function normalizeMime(mime) {
  const m = String(mime || '').toLowerCase().trim();
  return ALLOWED_MIMES.has(m) ? m : 'image/png';
}

function safeJsonParse(raw) {
  try {
    const cleaned = String(raw || '').replace(/```json|```/gi, '').trim();
    try {
      return JSON.parse(cleaned);
    } catch {
      const start = cleaned.indexOf('{');
      const end = cleaned.lastIndexOf('}');
      if (start !== -1 && end > start) {
        let slice = cleaned.slice(start, end + 1);
        try {
          return JSON.parse(slice);
        } catch {
          slice = slice
            .replace(/,\s*([}\]])/g, '$1')
            .replace(/:\s*([A-Za-z][^"\n{}]*)"/g, ': "$1"');
          return JSON.parse(slice);
        }
      }
      return null;
    }
  } catch {
    return null;
  }
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const today = new Date().toISOString().slice(0, 10);
  if (today !== dayKey) {
    dayKey = today;
    dailyCount = 0;
  }
  if (dailyCount >= MAX_PER_DAY) {
    return res.status(429).json({
      error: 'AI service is busy today. Please try again later or select details manually.',
    });
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
    return res.status(429).json({
      error: 'Too many requests. Please wait a few seconds and try again.',
    });
  }
  hits.push(now);
  ipHits.set(ip, hits);

  const {
    mode = 'classify',
    imageBase64,
    beforeImageBase64,
    mimeType,
    beforeMimeType,
  } = req.body || {};

  if (!imageBase64 || typeof imageBase64 !== 'string') {
    return res.status(400).json({ error: 'Missing or invalid photo data.' });
  }
  if (imageBase64.length > 2_500_000) {
    return res.status(413).json({
      error: 'Photo is too large. Please retake or upload a smaller image.',
    });
  }

  const mainMime = normalizeMime(mimeType);
  const priorMime = normalizeMime(beforeMimeType || mimeType);

  const nimKey = process.env.NVIDIA_NIM_API_KEY || process.env.NVIDIA_API_KEY;
  const geminiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
  const openRouterKey = process.env.OPENROUTER_API_KEY;

  if (!nimKey && !geminiKey && !openRouterKey) {
    return res.status(503).json({
      error: 'AI service is currently unavailable. Please select details manually.',
    });
  }

  const prompt =
    mode === 'verify'
      ? 'Compare the street waste Before and After photo(s). Return ONLY valid JSON: {"cleared": boolean, "match_score": integer 0-100, "summary": string}.'
      : 'Analyze this image for a Bengaluru civic waste reporting app. First check if it actually shows street garbage, litter, overflowing bins, plastic/food/e-waste, or debris. If it is clean or unrelated (e.g. clean road, landscape, poster, meme, screenshot, selfie), set "is_waste": false, "waste_type": "No Waste / Clean", and give a short "rejection_reason". Always include a crisp 1-line "summary" describing what is actually visible in the image. Return ONLY valid JSON with keys: "is_waste" (boolean), "rejection_reason" (string), "summary" (string, max 18 words describing the image), "waste_type" ("Plastic"|"Wet/Food"|"Glass"|"E-Waste"|"Mixed/Debris"|"No Waste / Clean"), "severity" ("High"|"Medium"|"Low"), "confidence" (0.0 to 1.0), "contains_faces_or_plates" (boolean).';

  let lastStatus = 502;

  try {
    // 1. Priority: NVIDIA NIM Vision (nvidia/nemotron-3.5-super-vl-120b-a12b)
    if (nimKey) {
      try {
        const nimContent = [
          { type: 'text', text: prompt },
          ...(beforeImageBase64
            ? [{ type: 'image_url', image_url: { url: `data:${priorMime};base64,${beforeImageBase64}` } }]
            : []),
          { type: 'image_url', image_url: { url: `data:${mainMime};base64,${imageBase64}` } },
        ];
        const nimRes = await fetch('https://integrate.api.nvidia.com/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${nimKey}`,
          },
          body: JSON.stringify({
            model: 'nvidia/nemotron-3.5-super-vl-120b-a12b',
            messages: [{ role: 'user', content: nimContent }],
            max_tokens: 1024,
            temperature: 0.1,
            stream: false,
          }),
          signal: AbortSignal.timeout(22000),
        });
        dailyCount += 1;
        const nimData = await nimRes.json();
        if (nimRes.ok) {
          const msg = nimData?.choices?.[0]?.message;
          const parsed = safeJsonParse(msg?.content) || safeJsonParse(msg?.reasoning_content);
          if (parsed) {
            return res.status(200).json({ ...parsed, provider: 'AI Vision' });
          }
          console.error('[vision] NIM unparseable payload');
        } else {
          lastStatus = nimRes.status;
          console.error('[vision] NIM error:', nimRes.status, nimData?.error?.message || nimData?.detail);
        }
      } catch (e) {
        console.error('[vision] NIM exception:', String(e));
      }
    }

    // 2. Fallback: Gemini
    if (geminiKey) {
      const geminiParts = [
        { text: prompt },
        ...(beforeImageBase64
          ? [{ inline_data: { mime_type: priorMime, data: beforeImageBase64 } }]
          : []),
        { inline_data: { mime_type: mainMime, data: imageBase64 } },
      ];
      const models = ['gemini-2.5-flash', 'gemini-2.5-flash-lite', 'gemini-3.8-flash'];
      for (const model of models) {
        try {
          const r = await fetch(
            `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`,
            {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                contents: [{ parts: geminiParts }],
                generationConfig: {
                  responseMimeType: 'application/json',
                  maxOutputTokens: 1024,
                  temperature: 0.1,
                },
              }),
              signal: AbortSignal.timeout(20000),
            }
          );
          dailyCount += 1;
          const data = await r.json();
          if (r.ok) {
            const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
            const parsed = safeJsonParse(text);
            if (parsed) {
              return res.status(200).json({ ...parsed, provider: 'AI Vision' });
            }
            lastStatus = 502;
            console.error('[vision] Gemini unparseable payload for', model);
          } else {
            lastStatus = r.status;
            console.error('[vision] Gemini error:', model, r.status, data?.error?.message);
            if (r.status !== 404 && r.status !== 429) break;
          }
        } catch (e) {
          console.error('[vision] Gemini exception:', model, String(e));
        }
      }
    }

    // 3. Fallback: OpenRouter
    if (openRouterKey) {
      try {
        const orContent = [
          { type: 'text', text: prompt },
          ...(beforeImageBase64
            ? [{ type: 'image_url', image_url: { url: `data:${priorMime};base64,${beforeImageBase64}` } }]
            : []),
          { type: 'image_url', image_url: { url: `data:${mainMime};base64,${imageBase64}` } },
        ];
        const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${openRouterKey}`,
          },
          body: JSON.stringify({
            model: 'openrouter/free',
            messages: [{ role: 'user', content: orContent }],
          }),
          signal: AbortSignal.timeout(20000),
        });
        dailyCount += 1;
        const data = await r.json();
        if (r.ok) {
          const parsed = safeJsonParse(data?.choices?.[0]?.message?.content);
          if (parsed) {
            return res.status(200).json({ ...parsed, provider: 'AI Vision' });
          }
          lastStatus = 502;
          console.error('[vision] OpenRouter unparseable payload');
        } else {
          lastStatus = r.status;
          console.error('[vision] OpenRouter error:', r.status, data?.error?.message);
        }
      } catch (e) {
        console.error('[vision] OpenRouter exception:', String(e));
      }
    }

    const safeStatus = lastStatus === 429 ? 429 : 503;
    return res.status(safeStatus).json({
      error:
        safeStatus === 429
          ? 'AI service is busy right now. Please try again shortly.'
          : 'Could not detect waste with AI right now. Please retry or choose details manually.',
    });
  } catch (err) {
    console.error('[vision] Unhandled exception:', String(err));
    return res.status(500).json({
      error: 'Could not detect waste with AI right now. Please retry.',
    });
  }
}
