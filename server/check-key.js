/**
 * Tests the Gemini key and model directly, with none of the app in the way.
 *
 * Run:  npm run check
 *
 * If this fails, the problem is the key, the model name, or the token budget —
 * not the gateway and not Flutter. The key is never printed.
 */
import { config, isGeminiConfigured, redact } from './src/config.js';

const BASE = 'https://generativelanguage.googleapis.com/v1beta';

async function main() {
  console.log('--- MindPal Gemini check ---\n');

  if (!isGeminiConfigured()) {
    console.log('FAIL: GEMINI_API_KEY is empty in .env');
    process.exitCode = 1;
    return;
  }

  const key = config.apiKey.trim();
  // Google issues more than one key format. "AIza" is the classic one, "AQ."
  // keys are also valid. The prefix proves nothing — step 1 is the real test.
  console.log(`Key length : ${key.length}`);
  console.log(`Key prefix : ${key.slice(0, 4)}...`);
  console.log(`Model      : ${config.model}`);
  console.log(
    `Thinking   : ${
      config.thinkingBudget === null
        ? 'left to the model'
        : `budget ${config.thinkingBudget}`
    }\n`,
  );

  // ---- Step 1: does the KEY work at all? ----------------------------------
  console.log('1. Checking the key (GET /models)...');
  const list = await fetch(`${BASE}/models?pageSize=200`, {
    headers: { 'x-goog-api-key': key },
  }).catch((error) => ({ error }));

  if (list.error) {
    console.log(`   NETWORK FAIL: ${list.error.message}`);
    process.exitCode = 1;
    return;
  }

  console.log(`   HTTP ${list.status}`);
  if (!list.ok) {
    console.log(`   ${redact(await list.text().catch(() => '')).slice(0, 400)}`);
    console.log(
      '\nDIAGNOSIS: the KEY is being rejected. Create a new API key at' +
        '\n           https://aistudio.google.com/apikey and put it in' +
        '\n           server/.env as GEMINI_API_KEY.',
    );
    process.exitCode = 1;
    return;
  }

  const payload = await list.json();
  const names = (payload.models ?? [])
    .map((model) => model.name?.replace('models/', ''))
    .filter((name) => name && name.includes('gemini'));

  console.log(`   Key works. ${names.length} Gemini models available.`);

  if (!names.includes(config.model)) {
    console.log(`\n   WARNING: "${config.model}" is NOT in your model list.`);
    console.log(`   Available: ${names.slice(0, 12).join(', ')}`);
    console.log('   Set GEMINI_MODEL in .env to one of those.\n');
  }

  // ---- Step 2: an actual generation, like the app does ---------------------
  console.log('\n2. Sending a real request...');
  const reply = await fetch(
    `${BASE}/models/${encodeURIComponent(config.model)}:generateContent`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
      body: JSON.stringify({
        contents: [
          { role: 'user', parts: [{ text: 'Reply with the word OK.' }] },
        ],
        generationConfig: {
          // Generous on purpose. Newer Gemini models spend tokens THINKING
          // before writing anything, out of this same budget — a tight cap
          // produces a successful response containing no text at all.
          maxOutputTokens: 1024,
          temperature: 0,
          ...(config.thinkingBudget === null
            ? {}
            : { thinkingConfig: { thinkingBudget: config.thinkingBudget } }),
        },
      }),
    },
  ).catch((error) => ({ error }));

  if (reply.error) {
    console.log(`   NETWORK FAIL: ${reply.error.message}`);
    process.exitCode = 1;
    return;
  }

  console.log(`   HTTP ${reply.status}`);
  if (!reply.ok) {
    console.log(`   ${redact(await reply.text().catch(() => '')).slice(0, 500)}`);
    console.log(
      '\nDIAGNOSIS: the key works but this MODEL request failed.' +
        '\n           Pick one from the list above and set GEMINI_MODEL in .env.',
    );
    process.exitCode = 1;
    return;
  }

  const data = await reply.json();
  const candidate = data?.candidates?.[0];
  const text = candidate?.content?.parts?.[0]?.text;

  console.log(`   finishReason : ${candidate?.finishReason ?? '(none)'}`);
  console.log(`   tokens       : ${JSON.stringify(data?.usageMetadata ?? {})}`);

  if (typeof text === 'string' && text.trim().length > 0) {
    console.log(`   Gemini said  : ${text.trim()}\n`);
    console.log('PASS: key and model both work. Start the gateway: npm start');
    return;
  }

  console.log('   Gemini said  : (no text)\n');
  console.log('DIAGNOSIS: the request succeeded but produced no visible text.');
  console.log('  * finishReason MAX_TOKENS means the whole budget went on');
  console.log('    internal reasoning. Add GEMINI_THINKING_BUDGET=0 to .env.');
  console.log('  * Or try a model known to be chatty: GEMINI_MODEL=gemini-2.5-flash');
  console.log('\nFull candidate for reference:');
  console.log(redact(JSON.stringify(candidate, null, 2)).slice(0, 900));
  process.exitCode = 1;
}

main();
