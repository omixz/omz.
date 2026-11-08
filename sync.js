// Accounts + cloud sync via Supabase (optional; see config.js).
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

export const enabled = !!(SUPABASE_URL && SUPABASE_ANON_KEY);
const SDK = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
let sb = null, user = null, ready = null;
const listeners = new Set();

export function init() {
  if (!enabled) return Promise.resolve(null);
  return (ready ??= (async () => {
    const { createClient } = await import(SDK);
    sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { auth: { persistSession: true, autoRefreshToken: true } });
    const { data } = await sb.auth.getSession();
    user = data.session?.user || null;
    sb.auth.onAuthStateChange((_evt, session) => {
      const next = session?.user || null;
      if (next?.id === user?.id) { user = next; return; }
      user = next;
      listeners.forEach((f) => f(user));
    });
    return user;
  })());
}
export const currentUser = () => user;
export const onAuthChange = (f) => listeners.add(f);

export async function signIn(email, password) {
  await init();
  const { error } = await sb.auth.signInWithPassword({ email, password });
  if (error) throw error;
}
// Returns true when the person must confirm their email before signing in.
export async function signUp(email, password) {
  await init();
  const { data, error } = await sb.auth.signUp({ email, password });
  if (error) throw error;
  return !data.session;
}
export async function resetPassword(email) {
  await init();
  const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: location.origin + location.pathname });
  if (error) throw error;
}
export async function signOut() {
  await init();
  await sb.auth.signOut();
}
export async function pull() {
  await init();
  if (!user) return null;
  const { data, error } = await sb.from('libraries').select('data').eq('user_id', user.id).maybeSingle();
  if (error) throw error;
  return data?.data || null;
}
export async function push(snapshot) {
  await init();
  if (!user) return;
  const { error } = await sb.from('libraries').upsert({ user_id: user.id, data: snapshot, updated_at: new Date().toISOString() });
  if (error) throw error;
}
