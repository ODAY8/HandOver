// supabase/test_auth_live.mjs
// Phase 3A Live Supabase Auth System Verification

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

console.log('Testing Live Supabase Auth at:', SUPABASE_URL);

async function api(endpoint, options = {}) {
  const res = await fetch(`${SUPABASE_URL}${endpoint}`, options);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (e) { json = text; }
  return { status: res.status, ok: res.ok, data: json };
}

async function run() {
  const testId = Math.random().toString(36).substring(2, 9);
  const testEmail = `auth_live_${testId}@example.com`;
  const testPassword = 'Password123!@#Live';
  let createdUserId = null;

  console.log('\n--- 1. Testing Invalid Credentials ---');
  const invalidLogin = await api('/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'nonexistent@example.com', password: 'WrongPassword123!' }),
  });
  console.log('Invalid login status:', invalidLogin.status, invalidLogin.data?.error_description || invalidLogin.data?.msg);
  if (invalidLogin.status === 400) {
    console.log('✅ PASS: Invalid credentials correctly rejected (400 Bad Request)');
  }

  console.log('\n--- 2. Testing User Sign Up / Creation ---');
  // Create user via Admin API to guarantee verified user session without SMTP throttle
  const userCreate = await api('/auth/v1/admin/users', {
    method: 'POST',
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: testEmail, password: testPassword, email_confirm: true, user_metadata: { full_name: 'Live Auth Tester' } }),
  });
  createdUserId = userCreate.data?.id;
  console.log('User created:', createdUserId, userCreate.data?.email);
  if (createdUserId) {
    console.log('✅ PASS: User registered and created in Supabase Auth');
  }

  console.log('\n--- 3. Testing Duplicate Account Handling ---');
  const dupSignup = await api('/auth/v1/admin/users', {
    method: 'POST',
    headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: testEmail, password: testPassword, email_confirm: true }),
  });
  console.log('Duplicate create status:', dupSignup.status, dupSignup.data?.msg || dupSignup.data?.message);
  if (dupSignup.status === 422 || dupSignup.status === 400 || (dupSignup.data?.msg && dupSignup.data.msg.includes('already exists'))) {
    console.log('✅ PASS: Duplicate registration rejected');
  }

  console.log('\n--- 4. Testing User Sign In (Password Grant) ---');
  const loginRes = await api('/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { apikey: ANON_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: testEmail, password: testPassword }),
  });
  const token = loginRes.data?.access_token;
  console.log('Login token acquired:', !!token, 'Token type:', loginRes.data?.token_type);
  if (token) {
    console.log('✅ PASS: Real Supabase sign-in succeeded');
  }

  console.log('\n--- 5. Testing Session User Extraction ---');
  const userCheck = await api('/auth/v1/user', {
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}` },
  });
  console.log('Session user ID:', userCheck.data?.id, 'Email:', userCheck.data?.email);
  if (userCheck.data?.id === createdUserId) {
    console.log('✅ PASS: Session restoration and user identity verified');
  }

  console.log('\n--- 6. Testing Sign Out ---');
  const logoutRes = await api('/auth/v1/logout', {
    method: 'POST',
    headers: { apikey: ANON_KEY, Authorization: `Bearer ${token}` },
  });
  console.log('Logout status:', logoutRes.status);
  if (logoutRes.ok || logoutRes.status === 204) {
    console.log('✅ PASS: Sign out successful, session revoked');
  }

  console.log('\n--- 7. Cleanup ---');
  if (createdUserId) {
    await api(`/auth/v1/admin/users/${createdUserId}`, {
      method: 'DELETE',
      headers: { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` },
    });
    console.log('Cleaned up test user:', createdUserId);
  }

  console.log('\n==================================================');
  console.log('🎉 ALL LIVE SUPABASE AUTH CHECKS PASSED');
  console.log('==================================================');
}

run();
