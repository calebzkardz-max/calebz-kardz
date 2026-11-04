// Supabase Edge Function: owner-password-reset
// Recovery email is sent only when the submitted address belongs to the Owner.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
  const email = String(body.email || "").trim().toLowerCase();
  if (!email) return json({ error: "Email is required" }, 400);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: owner, error } = await admin.from("profiles").select("id").ilike("email", email).eq("is_owner", true).maybeSingle();
  // Keep the response generic so callers cannot enumerate registered emails.
  if (error || !owner) return json({ success: true });
  const publicClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const redirectTo = "https://ezekielmeshack136-max.github.io/meshez-kadi-app/";
  const { error: resetError } = await publicClient.auth.resetPasswordForEmail(email, { redirectTo });
  if (resetError) return json({ error: resetError.message }, 400);
  return json({ success: true });
});
