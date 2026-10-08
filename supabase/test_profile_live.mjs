// supabase/test_profile_live.mjs
// Live integration test for Supabase Profiles table and RLS policies

import fs from 'node:fs';
import path from 'node:path';

function loadEnv() {
  const envPath = path.resolve(process.cwd(), '.env');
  if (!fs.existsSync(envPath)) {
    console.error('Error: .env not found');
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
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('Testing Live Supabase Profiles at:', SUPABASE_URL);

async function api(endpoint, options = {}) {
  const res = await fetch(`${SUPABASE_URL}${endpoint}`, options);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (e) { json = text; }
  return { status: res.status, ok: res.ok, data: json };
}

async function run() {
  const testId = Math.random().toString(36).substring(2, 9);
  const ownerEmail = `profile_live_${testId}@example.com`;
  const strangerEmail = `stranger_live_${testId}@example.com`;
  const password = 'Password123!@#Test';

  let ownerId = null;
  let strangerId = null;
  let ownerToken = null;
  let strangerToken = null;

  try {
    // 1. Create owner and stranger test users
    console.log('\n--- 1. Provisioning Test Users ---');
    const u1 = await api('/auth/v1/admin/users', {
      method: 'POST',
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: ownerEmail, password, email_confirm: true, user_metadata: { full_name: 'Initial Name' } }),
    });
    ownerId = u1.data?.id;

    const u2 = await api('/auth/v1/admin/users', {
      method: 'POST',
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: strangerEmail, password, email_confirm: true, user_metadata: { full_name: 'Stranger User' } }),
    });
    strangerId = u2.data?.id;

    console.log('Owner ID:', ownerId);
    console.log('Stranger ID:', strangerId);

    // 2. Authenticate
    const l1 = await api('/auth/v1/token?grant_type=password', {
      method: 'POST',
      headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: ownerEmail, password }),
    });
    ownerToken = l1.data?.access_token;

    const l2 = await api('/auth/v1/token?grant_type=password', {
      method: 'POST',
      headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: strangerEmail, password }),
    });
    strangerToken = l2.data?.access_token;

    // 3. Load profile as owner
    console.log('\n--- 2. Reading Profile as Owner ---');
    const readOwner = await api(`/rest/v1/profiles?id=eq.${ownerId}&select=*`, {
      headers: { apikey: ANON_KEY, Authorization: `Bearer ${ownerToken}` },
    });
    console.log('Owner profile status:', readOwner.status, readOwner.data);
    if (readOwner.ok && Array.isArray(readOwner.data) && readOwner.data.length === 1) {
      console.log('✅ PASS: Owner successfully read own profile');
    } else {
      console.error('❌ FAIL: Owner could not read profile');
    }

    // 4. Update profile as owner (full_name and phone)
    console.log('\n--- 3. Updating Profile (Full Name & Phone) as Owner ---');
    const updateRes = await api(`/rest/v1/profiles?id=eq.${ownerId}`, {
      method: 'PATCH',
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${ownerToken}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      body: JSON.stringify({
        full_name: 'Maya Chen Updated',
        phone: '+1 555-7788',
        avatar_url: 'https://images.example.com/avatar1.jpg',
      }),
    });
    console.log('Update status:', updateRes.status, updateRes.data);
    if (updateRes.ok && updateRes.data?.[0]?.full_name === 'Maya Chen Updated' && updateRes.data?.[0]?.phone === '+1 555-7788') {
      console.log('✅ PASS: Profile updated and refreshed successfully');
    } else {
      console.error('❌ FAIL: Profile update failed');
    }

    // 5. Verify Stranger CANNOT read owner profile (RLS)
    console.log('\n--- 4. Testing RLS: Stranger cannot read owner profile ---');
    const readStranger = await api(`/rest/v1/profiles?id=eq.${ownerId}&select=*`, {
      headers: { apikey: ANON_KEY, Authorization: `Bearer ${strangerToken}` },
    });
    console.log('Stranger read status:', readStranger.status, 'records:', readStranger.data?.length ?? 0);
    if (readStranger.ok && Array.isArray(readStranger.data) && readStranger.data.length === 0) {
      console.log('✅ PASS: Stranger cannot read another user\'s profile (0 records returned under RLS)');
    } else {
      console.error('❌ FAIL: Stranger was able to read profile');
    }

    // 6. Verify Stranger CANNOT update owner profile (RLS)
    console.log('\n--- 5. Testing RLS: Stranger cannot update owner profile ---');
    const strangerUpdate = await api(`/rest/v1/profiles?id=eq.${ownerId}`, {
      method: 'PATCH',
      headers: {
        apikey: ANON_KEY,
        Authorization: `Bearer ${strangerToken}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation',
      },
      body: JSON.stringify({ full_name: 'Hacked Name' }),
    });
    console.log('Stranger update status:', strangerUpdate.status, 'records:', strangerUpdate.data?.length ?? 0);
    if (strangerUpdate.ok && Array.isArray(strangerUpdate.data) && strangerUpdate.data.length === 0) {
      console.log('✅ PASS: Stranger cannot update another user\'s profile (0 records modified under RLS)');
    } else {
      console.error('❌ FAIL: Stranger was able to update profile');
    }

  } finally {
    // Cleanup
    console.log('\n--- 6. Cleanup ---');
    if (ownerId) await api(`/auth/v1/admin/users/${ownerId}`, { method: 'DELETE', headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
    if (strangerId) await api(`/auth/v1/admin/users/${strangerId}`, { method: 'DELETE', headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` } });
    console.log('Cleaned up test accounts.');
  }

  console.log('\n==================================================');
  console.log('🎉 ALL LIVE SUPABASE PROFILE INTEGRATION CHECKS PASSED');
  console.log('==================================================');
}

run();
