// supabase/test_handover_live.mjs
// Live integration test for Supabase Handovers and Handover Events tables and RLS

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

console.log('Testing Live Supabase Handovers CRUD at:', SUPABASE_URL);

async function api(endpoint, options = {}) {
  const res = await fetch(`${SUPABASE_URL}${endpoint}`, options);
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch (e) { json = text; }
  return { status: res.status, ok: res.ok, data: json };
}

async function run() {
  const testId = Math.random().toString(36).substring(2, 9);
  const senderEmail = `sender_${testId}@example.com`;
  const receiverEmail = `receiver_${testId}@example.com`;
  const strangerEmail = `stranger_${testId}@example.com`;
  const password = 'Password123!@#Test';

  let senderId = null;
  let receiverId = null;
  let strangerId = null;
  let senderToken = null;
  let receiverToken = null;
  let strangerToken = null;
  let handoverId = null;

  try {
    // 1. Provision test users
    console.log('\n--- 1. Provisioning Test Users ---');
    const u1 = await api('/auth/v1/admin/users', {
      method: 'POST',
      headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: senderEmail, password, email_confirm: true, user_metadata: { full_name: 'Test Sender' } }),
    });
    senderId = u1.data?.id;

    const u2 = await api('/auth/v1/admin/users', {
      method: 'POST',
      headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: receiverEmail, password, email_confirm: true, user_metadata: { full_name: 'Test Receiver' } }),
    });
    receiverId = u2.data?.id;

    const u3 = await api('/auth/v1/admin/users', {
      method: 'POST',
      headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: strangerEmail, password, email_confirm: true, user_metadata: { full_name: 'Stranger User' } }),
    });
    strangerId = u3.data?.id;

    // Login users to get session JWTs
    const loginSender = await api('/auth/v1/token?grant_type=password', {
      method: 'POST',
      headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: senderEmail, password }),
    });
    senderToken = loginSender.data?.access_token;

    const loginReceiver = await api('/auth/v1/token?grant_type=password', {
      method: 'POST',
      headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: receiverEmail, password }),
    });
    receiverToken = loginReceiver.data?.access_token;

    const loginStranger = await api('/auth/v1/token?grant_type=password', {
      method: 'POST',
      headers: { 'apikey': ANON_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: strangerEmail, password }),
    });
    strangerToken = loginStranger.data?.access_token;

    console.log('Sender ID:', senderId, 'Receiver ID:', receiverId, 'Stranger ID:', strangerId);

    // 2. Sender creates a handover record
    console.log('\n--- 2. Create Handover by Sender ---');
    const createRes = await api('/rest/v1/handovers', {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${senderToken}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        owner_id: senderId,
        recipient_name: 'Test Receiver',
        recipient_email: receiverEmail,
        recipient_phone: '+15551234567',
        item_type: 'Electronics',
        item_name: 'MacBook Pro 14"',
        description: 'Space Gray, 14-inch, with charger',
        purpose: '{"identifier":"NL-MBP-014","notes":"For workshop"}',
        status: 'PENDING',
        expected_return_at: new Date(Date.now() + 86400000 * 3).toISOString(),
      }),
    });
    console.log('Create status:', createRes.status, 'Created ID:', createRes.data?.[0]?.id);
    if (!createRes.ok || !createRes.data?.[0]?.id) {
      throw new Error(`Failed to create handover: ${JSON.stringify(createRes.data)}`);
    }
    handoverId = createRes.data[0].id;

    // 3. Sender creates initial CREATED event
    console.log('\n--- 3. Create Handover Event (CREATED) ---');
    const event1Res = await api('/rest/v1/handover_events', {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${senderToken}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        handover_id: handoverId,
        event_type: 'CREATED',
        performed_by: senderId,
        metadata: {
          title: 'Record created by Test Sender',
          performer_name: 'Test Sender',
        },
      }),
    });
    console.log('Event 1 status:', event1Res.status, 'Event ID:', event1Res.data?.[0]?.id);
    if (!event1Res.ok) {
      throw new Error(`Failed to insert CREATED event: ${JSON.stringify(event1Res.data)}`);
    }

    // 4. Sender queries handover with joined handover_events
    console.log('\n--- 4. Sender Queries Handover with Joined Events ---');
    const querySender = await api(`/rest/v1/handovers?id=eq.${handoverId}&select=*,handover_events(*)`, {
      method: 'GET',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${senderToken}`,
      },
    });
    console.log('Query status:', querySender.status, 'Events count:', querySender.data?.[0]?.handover_events?.length);
    if (!querySender.ok || querySender.data?.[0]?.handover_events?.length !== 1) {
      throw new Error(`Sender query with events failed: ${JSON.stringify(querySender.data)}`);
    }

    // 5. Receiver queries handovers (authorized via recipient_email RLS)
    console.log('\n--- 5. Receiver Queries Handover (via recipient_email) ---');
    const queryReceiver = await api(`/rest/v1/handovers?id=eq.${handoverId}&select=*,handover_events(*)`, {
      method: 'GET',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${receiverToken}`,
      },
    });
    console.log('Receiver query status:', queryReceiver.status, 'Found:', queryReceiver.data?.length);
    if (!queryReceiver.ok || queryReceiver.data?.length !== 1) {
      throw new Error(`Receiver failed to query handover: ${JSON.stringify(queryReceiver.data)}`);
    }

    // 6. Stranger queries handovers (should be BLOCKED by RLS - 0 records)
    console.log('\n--- 6. Stranger Access Blocked by RLS ---');
    const queryStranger = await api(`/rest/v1/handovers?id=eq.${handoverId}&select=*,handover_events(*)`, {
      method: 'GET',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${strangerToken}`,
      },
    });
    console.log('Stranger query records returned:', queryStranger.data?.length);
    if (queryStranger.data?.length !== 0) {
      throw new Error(`RLS leak! Stranger was able to read records: ${JSON.stringify(queryStranger.data)}`);
    }

    // 7. Receiver confirms physical receipt (status -> RECEIVED + event)
    console.log('\n--- 7. Receiver Confirms Physical Receipt ---');
    const updateReceived = await api(`/rest/v1/handovers?id=eq.${handoverId}`, {
      method: 'PATCH',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${receiverToken}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        status: 'RECEIVED',
        received_at: new Date().toISOString(),
      }),
    });
    console.log('Update RECEIVED status:', updateReceived.status, 'New status:', updateReceived.data?.[0]?.status);
    if (!updateReceived.ok || updateReceived.data?.[0]?.status !== 'RECEIVED') {
      throw new Error(`Failed to update status to RECEIVED: ${JSON.stringify(updateReceived.data)}`);
    }

    const event2Res = await api('/rest/v1/handover_events', {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${receiverToken}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        handover_id: handoverId,
        event_type: 'RECEIVED',
        performed_by: receiverId,
        metadata: {
          title: 'Test Receiver confirmed physical receipt',
          performer_name: 'Test Receiver',
        },
      }),
    });
    console.log('Event RECEIVED status:', event2Res.status);
    if (!event2Res.ok) {
      throw new Error(`Failed to insert RECEIVED event: ${JSON.stringify(event2Res.data)}`);
    }

    // 8. Sender records an issue (status -> DISPUTED)
    console.log('\n--- 8. Sender Records Issue (DISPUTED) ---');
    const updateDisputed = await api(`/rest/v1/handovers?id=eq.${handoverId}`, {
      method: 'PATCH',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${senderToken}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        status: 'DISPUTED',
      }),
    });
    console.log('Update DISPUTED status:', updateDisputed.status, 'New status:', updateDisputed.data?.[0]?.status);

    const event3Res = await api('/rest/v1/handover_events', {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${senderToken}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        handover_id: handoverId,
        event_type: 'ISSUE_RECORDED',
        performed_by: senderId,
        metadata: {
          title: 'Test Sender recorded a condition issue',
          description: 'Small scratch on top surface',
          performer_name: 'Test Sender',
        },
      }),
    });
    console.log('Event ISSUE_RECORDED status:', event3Res.status);

    // 9. Sender confirms physical return (status -> RETURNED)
    console.log('\n--- 9. Sender Confirms Physical Return (RETURNED) ---');
    const updateReturned = await api(`/rest/v1/handovers?id=eq.${handoverId}`, {
      method: 'PATCH',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${senderToken}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        status: 'RETURNED',
        returned_at: new Date().toISOString(),
      }),
    });
    console.log('Update RETURNED status:', updateReturned.status, 'New status:', updateReturned.data?.[0]?.status);

    const event4Res = await api('/rest/v1/handover_events', {
      method: 'POST',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${senderToken}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        handover_id: handoverId,
        event_type: 'RETURNED',
        performed_by: senderId,
        metadata: {
          title: 'Test Sender confirmed physical return',
          performer_name: 'Test Sender',
        },
      }),
    });
    console.log('Event RETURNED status:', event4Res.status);

    // 10. Verify final query with all 4 events
    console.log('\n--- 10. Verify Final State and 4 Events ---');
    const finalQuery = await api(`/rest/v1/handovers?id=eq.${handoverId}&select=*,handover_events(*)`, {
      method: 'GET',
      headers: {
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${senderToken}`,
      },
    });
    const finalHandover = finalQuery.data?.[0];
    console.log('Final status:', finalHandover?.status, 'Total events:', finalHandover?.handover_events?.length);
    if (finalHandover?.status !== 'RETURNED' || finalHandover?.handover_events?.length !== 4) {
      throw new Error(`Final state mismatch: status=${finalHandover?.status}, events=${finalHandover?.handover_events?.length}`);
    }

    console.log('\n🎉 ALL 10 HANDOVER CRUD AND RLS CHECKS PASSED SUCCESSFULLY!\n');
  } finally {
    // Cleanup created test records
    console.log('--- Cleaning Up Test Data ---');
    if (handoverId) {
      await api(`/rest/v1/handovers?id=eq.${handoverId}`, {
        method: 'DELETE',
        headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}` },
      });
    }
    if (senderId) {
      await api(`/auth/v1/admin/users/${senderId}`, {
        method: 'DELETE',
        headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}` },
      });
    }
    if (receiverId) {
      await api(`/auth/v1/admin/users/${receiverId}`, {
        method: 'DELETE',
        headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}` },
      });
    }
    if (strangerId) {
      await api(`/auth/v1/admin/users/${strangerId}`, {
        method: 'DELETE',
        headers: { 'apikey': SERVICE_KEY, 'Authorization': `Bearer ${SERVICE_KEY}` },
      });
    }
    console.log('Cleanup complete.');
  }
}

run().catch((err) => {
  console.error('Test failed with error:', err);
  process.exit(1);
});
