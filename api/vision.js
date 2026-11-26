// Vercel Serverless Proxy for NagarNex Vision AI
// Keeps GEMINI_API_KEY / OPENROUTER_API_KEY 100% secure on the server.
// Set GEMINI_API_KEY (or OPENROUTER_API_KEY) in Vercel Project -> Settings -> Environment Variables.

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { mode = 'classify', imageBase64 } = req.body || {};
  if (!imageBase64) {
    return res.status(400).json({ error: 'Missing imageBase64' });
  }

  const geminiKey = process.env.GEMINI_API_KEY;
  const openRouterKey = process.env.OPENROUTER_API_KEY;

  const prompt =
    mode === 'verify'
      ? 'Evaluate this "After" clearance photo for a street waste report. Return ONLY valid JSON: {"cleared": boolean, "match_score": integer 0-100, "summary": string}.'
      : 'Analyze this Bengaluru street waste photo. Return ONLY valid JSON with keys: "waste_type" ("Plastic"|"Wet/Food"|"Glass"|"E-Waste"|"Mixed/Debris"), "severity" ("High"|"Medium"|"Low"), "confidence" (0.0 to 1.0), "contains_faces_or_plates" (boolean).';

  try {
    if (geminiKey) {
      const r = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${geminiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  { text: prompt },
                  { inline_data: { mime_type: 'image/png', data: imageBase64 } },
                ],
              },
            ],
            generationConfig: { responseMimeType: 'application/json' },
          }),
        }
      );
      const data = await r.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (text) return res.status(200).json(JSON.parse(text));
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
