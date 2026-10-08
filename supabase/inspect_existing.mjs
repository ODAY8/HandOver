// supabase/inspect_existing.mjs
// Safely inspects the Supabase project to determine existing tables and schema without making destructive changes

import fs from 'node:fs';
import path from 'node:path';

function loadEnv() {
  const envPath = path.resolve(process.cwd(), '.env');
  if (!fs.existsSync(envPath)) {
    console.error('Error: .env file not found at', envPath);
    console.error('Please create a .env file with SUPABASE_URL, SUPABASE_ANON_KEY, and SUPABASE_SERVICE_ROLE_KEY');
    process.exit(1);
  }
  const content = fs.readFileSync(envPath, 'utf8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx !== -1) {
      const key = trimmed.slice(0, eqIdx).trim();
      let val = trimmed.slice(eqIdx + 1).trim();
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      process.env[key] = val;
    }
  }
}

loadEnv();

const SUPABASE_URL = process.env.SUPABASE_URL?.replace(/\/$/, '');
const ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || ANON_KEY;

if (!SUPABASE_URL || !ANON_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env');
  process.exit(1);
}

console.log('Inspecting Supabase Project at:', SUPABASE_URL);

async function checkEndpoint(path) {
  const res = await fetch(`${SUPABASE_URL}${path}`, {
    method: 'GET',
    headers: {
      'apikey': SERVICE_KEY,
      'Authorization': `Bearer ${SERVICE_KEY}`,
    },
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch(e) { json = text; }
  return { status: res.status, ok: res.ok, data: json };
}

async function inspect() {
  console.log('\n--- Checking Root / OpenApi Specs ---');
  const openApi = await checkEndpoint('/rest/v1/');
  if (openApi.ok && openApi.data?.definitions) {
    const tableNames = Object.keys(openApi.data.definitions);
    console.log(`Found ${tableNames.length} tables in PostgREST schema:`);
    tableNames.forEach(t => console.log(`  - ${t}`));
  } else {
    console.log('PostgREST response status:', openApi.status);
  }

  console.log('\n--- Checking Specific HandOver Tables ---');
  for (const table of ['profiles', 'handovers', 'handover_events']) {
    const tableCheck = await checkEndpoint(`/rest/v1/${table}?select=*&limit=1`);
    if (tableCheck.ok) {
      console.log(`  ✅ Table '${table}' exists. Status: 200 OK.`);
    } else {
      console.log(`  ℹ️ Table '${table}' check status: ${tableCheck.status} (${JSON.stringify(tableCheck.data?.message || tableCheck.data)})`);
    }
  }

  console.log('\n--- Checking Storage Buckets ---');
  const bucketsCheck = await checkEndpoint('/storage/v1/bucket');
  if (bucketsCheck.ok && Array.isArray(bucketsCheck.data)) {
    console.log(`Found ${bucketsCheck.data.length} storage buckets:`);
    bucketsCheck.data.forEach(b => console.log(`  - ${b.id} (public: ${b.public})`));
  } else {
    console.log('Buckets check status:', bucketsCheck.status, bucketsCheck.data);
  }

  console.log('\nInspection finished safely without modifying any tables or data.');
}

inspect();
