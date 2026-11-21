import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const client = createClient(
  supabaseUrl,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
);
const authClient = createClient(
  supabaseUrl,
  Deno.env.get("SUPABASE_ANON_KEY") ?? "",
);

serve(async (request) => {
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }
  const { data: auth, error: authError } = await authClient.auth.getUser(
    authorization.slice(7),
  );
  if (authError || !auth.user) {
    return Response.json({ error: "Unauthorized" }, { status: 401 });
  }
  const { data, error } = await client.rpc("get_billing_availability");
  if (error) return Response.json({ error: "Unavailable" }, { status: 503 });
  return Response.json(data);
});
