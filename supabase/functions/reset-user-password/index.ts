// Supabase Edge Function: reset-user-password
// Only the Owner may set a new password for a non-owner Manager or Scanner.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const token = (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Authentication required" }, 401);
  const caller = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await caller.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Invalid session" }, 401);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: owner, error: ownerError } = await admin.from("profiles").select("id,is_owner,role").eq("id", authData.user.id).maybeSingle();
  if (ownerError || !owner?.is_owner || owner.role !== "admin") return json({ error: "Owner permission required" }, 403);
  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
  const userId = String(body.user_id || "");
  const newPassword = String(body.new_password || "");
  if (!userId) return json({ error: "User ID is required" }, 400);
  if (newPassword.length < 8) return json({ error: "Password iwe na angalau herufi 8" }, 400);
  const { data: target, error: targetError } = await admin.from("profiles").select("id,is_owner,role").eq("id", userId).maybeSingle();
  if (targetError || !target) return json({ error: "Mtumiaji hakupatikana" }, 404);
  if (target.is_owner || !["manager", "scanner"].includes(target.role)) return json({ error: "Owner anaweza kubadilisha password ya Manager au Scanner tu" }, 403);
  const { error: updateError } = await admin.auth.admin.updateUserById(userId, { password: newPassword });
  if (updateError) return json({ error: updateError.message }, 400);
  return json({ success: true });
});
