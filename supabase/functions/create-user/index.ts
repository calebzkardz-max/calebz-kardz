// Supabase Edge Function: create-user
// Only the authenticated Owner may create Manager or Scanner accounts.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const authHeader = req.headers.get("Authorization") || "";
  const token = authHeader.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Authentication required" }, 401);

  const callerClient = createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authData, error: authError } = await callerClient.auth.getUser(token);
  if (authError || !authData.user) return json({ error: "Invalid session" }, 401);

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: owner, error: ownerError } = await admin
    .from("profiles").select("id,is_owner,role").eq("id", authData.user.id).maybeSingle();
  if (ownerError || !owner?.is_owner || owner.role !== "admin") {
    return json({ error: "Owner permission required" }, 403);
  }

  let body: any;
  try { body = await req.json(); } catch { return json({ error: "Invalid JSON" }, 400); }
  const first = String(body.first_name || "").trim();
  const last = String(body.last_name || "").trim();
  const email = String(body.email || "").trim().toLowerCase();
  const password = String(body.password || "");
  const role = String(body.role || "").toLowerCase();

  if (!first || !email || !password) return json({ error: "Jaza jina, email na password" }, 400);
  if (password.length < 8) return json({ error: "Password iwe na angalau herufi 8" }, 400);
  if (!["manager", "scanner"].includes(role)) return json({ error: "Owner anaweza kuunda Manager au Scanner tu" }, 400);

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email, password, email_confirm: true, user_metadata: { first_name: first, last_name: last },
  });
  if (createError || !created.user) return json({ error: createError?.message || "Imeshindwa kuunda akaunti" }, 400);

  const { error: profileError } = await admin.from("profiles").upsert({
    id: created.user.id, first_name: first, last_name: last, email, role, is_owner: false,
  }, { onConflict: "id" });

  if (profileError) {
    // Roll back the Auth account if its profile could not be safely provisioned.
    await admin.auth.admin.deleteUser(created.user.id);
    return json({ error: "Akaunti haikukamilika: " + profileError.message }, 500);
  }

  return json({ success: true, user_id: created.user.id });
});
