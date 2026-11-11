


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."create_message_notification"("p_conversation_id" "uuid", "p_message_preview" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_sender_id uuid := auth.uid();
  v_buyer_id uuid;
  v_agent_id uuid;
  v_property_id uuid;
  v_subject text;
  v_recipient_id uuid;
  v_sender_name text;
  v_preview text;
begin
  if v_sender_id is null then
    raise exception 'Not authenticated';
  end if;

  select buyer_id, agent_id, property_id, subject
  into v_buyer_id, v_agent_id, v_property_id, v_subject
  from public.conversations
  where id = p_conversation_id;

  if v_buyer_id is null or v_agent_id is null then
    raise exception 'Conversation not found';
  end if;

  if v_sender_id = v_buyer_id then
    v_recipient_id := v_agent_id;
  elsif v_sender_id = v_agent_id then
    v_recipient_id := v_buyer_id;
  else
    raise exception 'User is not part of this conversation';
  end if;

  select coalesce(nullif(full_name, ''), email, 'Someone')
  into v_sender_name
  from public.profiles
  where id = v_sender_id;

  v_preview := coalesce(nullif(trim(p_message_preview), ''), 'Sent a message.');

  insert into public.notifications (
    user_id,
    title,
    message,
    type,
    related_property_id,
    related_conversation_id,
    is_read
  )
  values (
    v_recipient_id,
    case
      when coalesce(nullif(trim(v_subject), ''), '') <> ''
        then 'New message about ' || v_subject
      else 'New inquiry reply'
    end,
    coalesce(v_sender_name, 'Someone') || ': ' || v_preview,
    'inquiry_reply',
    v_property_id,
    p_conversation_id,
    false
  );
end;
$$;


ALTER FUNCTION "public"."create_message_notification"("p_conversation_id" "uuid", "p_message_preview" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_property_view_count"("property_id" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  update public.properties
  set view_count = coalesce(view_count, 0) + 1
  where id = property_id;
$$;


ALTER FUNCTION "public"."increment_property_view_count"("property_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select lower(
    coalesce(
      auth.jwt() -> 'app_metadata' ->> 'role',
      auth.jwt() -> 'user_metadata' ->> 'role',
      ''
    )
  ) = 'admin';
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_profile_role"("input_role" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select case lower(coalesce(input_role, 'user'))
    when 'admin' then 'admin'
    when 'agent' then 'agent'
    else 'user'
  end;
$$;


ALTER FUNCTION "public"."normalize_profile_role"("input_role" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."protect_profile_role"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.role := public.normalize_profile_role(
      coalesce(
        auth.jwt() -> 'app_metadata' ->> 'role',
        auth.jwt() -> 'user_metadata' ->> 'role',
        'user'
      )
    );
  else
    new.role := public.normalize_profile_role(new.role);
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."protect_profile_role"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_properties_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_properties_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_profile_from_auth_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.profiles (
    id,
    email,
    phone,
    full_name,
    role,
    avatar_url
  )
  values (
    new.id,
    new.email,
    new.phone,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    ),
    case lower(
      coalesce(
        new.raw_app_meta_data ->> 'role',
        new.raw_user_meta_data ->> 'role',
        'user'
      )
    )
      when 'admin' then 'admin'
      when 'agent' then 'agent'
      else 'user'
    end,
    coalesce(
      new.raw_user_meta_data ->> 'avatar_url',
      new.raw_user_meta_data ->> 'picture'
    )
  )
  on conflict (id) do update
  set
    email = excluded.email,
    phone = excluded.phone,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    role = excluded.role,
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    updated_at = now();

  return new;
end;
$$;


ALTER FUNCTION "public"."sync_profile_from_auth_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."touch_conversation_from_message"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  target_conversation_id uuid;
  latest_message record;
begin
  target_conversation_id := coalesce(new.conversation_id, old.conversation_id);

  select body, created_at
  into latest_message
  from public.messages
  where conversation_id = target_conversation_id
  order by created_at desc, id desc
  limit 1;

  update public.conversations
  set
    last_message_preview = coalesce(left(latest_message.body, 120), ''),
    last_message_at = latest_message.created_at,
    updated_at = now()
  where id = target_conversation_id;

  return coalesce(new, old);
end;
$$;


ALTER FUNCTION "public"."touch_conversation_from_message"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."agent_teams" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text" DEFAULT ''::"text",
    "logo_url" "text",
    "specialization" "text" DEFAULT ''::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."agent_teams" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "buyer_id" "uuid" NOT NULL,
    "agent_id" "uuid" NOT NULL,
    "property_id" "uuid",
    "subject" "text" DEFAULT ''::"text" NOT NULL,
    "last_message_preview" "text" DEFAULT ''::"text" NOT NULL,
    "last_message_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "conversations_check" CHECK (("buyer_id" <> "agent_id"))
);


ALTER TABLE "public"."conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "body" "text" NOT NULL,
    "message_type" "text" DEFAULT 'text'::"text" NOT NULL,
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "attachment_url" "text",
    "attachment_path" "text",
    "attachment_name" "text",
    "attachment_mime_type" "text",
    "attachment_size_bytes" bigint,
    CONSTRAINT "messages_body_check" CHECK (("length"("btrim"("body")) > 0)),
    CONSTRAINT "messages_message_type_check" CHECK (("message_type" = 'text'::"text"))
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."negros_places" (
    "id" bigint NOT NULL,
    "place_name" "text" NOT NULL,
    "province" "text" NOT NULL,
    "location" "text" NOT NULL
);


ALTER TABLE "public"."negros_places" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."negros_places_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."negros_places_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."negros_places_id_seq" OWNED BY "public"."negros_places"."id";



CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "title" "text" NOT NULL,
    "message" "text" NOT NULL,
    "type" "text" DEFAULT 'system_notice'::"text" NOT NULL,
    "related_property_id" "uuid",
    "is_read" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "related_conversation_id" "uuid"
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "phone" "text",
    "full_name" "text",
    "role" "text" DEFAULT 'user'::"text" NOT NULL,
    "avatar_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "fcm_token" "text",
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['user'::"text", 'agent'::"text", 'admin'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."properties" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text" NOT NULL,
    "location" "text" NOT NULL,
    "price" "text" NOT NULL,
    "price_value" integer DEFAULT 0 NOT NULL,
    "size" "text" NOT NULL,
    "size_value" integer DEFAULT 0 NOT NULL,
    "tag" "text" DEFAULT ''::"text" NOT NULL,
    "image_color" integer DEFAULT '-6501275'::integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "image_url" "text",
    "reference_code" "text" DEFAULT ''::"text" NOT NULL,
    "description" "text" DEFAULT ''::"text" NOT NULL,
    "title_status" "text" DEFAULT ''::"text" NOT NULL,
    "thumbnail_url" "text",
    "boundary_coordinates" "text",
    "agent_id" "uuid",
    "agent_team_id" "uuid",
    "view_count" integer DEFAULT 0 NOT NULL,
    "image_urls" "text"[] DEFAULT '{}'::"text"[] NOT NULL
);


ALTER TABLE "public"."properties" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."team_join_requests" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "team_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "message" "text" DEFAULT ''::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "team_join_requests_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."team_join_requests" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."team_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "team_id" "uuid",
    "name" "text" NOT NULL,
    "role" "text" DEFAULT ''::"text",
    "avatar_url" "text",
    "phone" "text",
    "email" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid"
);


ALTER TABLE "public"."team_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."team_message_reads" (
    "message_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "read_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."team_message_reads" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."team_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "team_id" "uuid" NOT NULL,
    "sender_id" "uuid" NOT NULL,
    "sender_name" "text" DEFAULT 'Agent'::"text" NOT NULL,
    "body" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "attachment_url" "text",
    "attachment_path" "text",
    "attachment_name" "text",
    "attachment_mime_type" "text",
    "attachment_size_bytes" bigint,
    CONSTRAINT "team_messages_body_check" CHECK (("char_length"(TRIM(BOTH FROM "body")) > 0)),
    CONSTRAINT "team_messages_body_max_length" CHECK (("char_length"("body") <= 1000)),
    CONSTRAINT "team_messages_body_not_empty" CHECK (("length"(TRIM(BOTH FROM "body")) > 0))
);


ALTER TABLE "public"."team_messages" OWNER TO "postgres";


ALTER TABLE ONLY "public"."negros_places" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."negros_places_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."agent_teams"
    ADD CONSTRAINT "agent_teams_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."negros_places"
    ADD CONSTRAINT "negros_places_location_key" UNIQUE ("location");



ALTER TABLE ONLY "public"."negros_places"
    ADD CONSTRAINT "negros_places_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."properties"
    ADD CONSTRAINT "properties_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_join_requests"
    ADD CONSTRAINT "team_join_requests_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_join_requests"
    ADD CONSTRAINT "team_join_requests_team_id_user_id_key" UNIQUE ("team_id", "user_id");



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_message_reads"
    ADD CONSTRAINT "team_message_reads_pkey" PRIMARY KEY ("message_id", "user_id");



ALTER TABLE ONLY "public"."team_messages"
    ADD CONSTRAINT "team_messages_pkey" PRIMARY KEY ("id");



CREATE INDEX "conversations_agent_id_idx" ON "public"."conversations" USING "btree" ("agent_id");



CREATE INDEX "conversations_buyer_id_idx" ON "public"."conversations" USING "btree" ("buyer_id");



CREATE INDEX "conversations_last_message_at_idx" ON "public"."conversations" USING "btree" ("last_message_at" DESC NULLS LAST);



CREATE INDEX "conversations_property_id_idx" ON "public"."conversations" USING "btree" ("property_id");



CREATE INDEX "messages_conversation_id_created_at_idx" ON "public"."messages" USING "btree" ("conversation_id", "created_at" DESC);



CREATE INDEX "messages_sender_id_idx" ON "public"."messages" USING "btree" ("sender_id");



CREATE INDEX "negros_places_province_place_name_idx" ON "public"."negros_places" USING "btree" ("province", "place_name");



CREATE INDEX "notifications_related_conversation_id_idx" ON "public"."notifications" USING "btree" ("related_conversation_id");



CREATE INDEX "notifications_user_id_created_at_idx" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "notifications_user_id_is_read_idx" ON "public"."notifications" USING "btree" ("user_id", "is_read");



CREATE INDEX "profiles_role_created_at_idx" ON "public"."profiles" USING "btree" ("role", "created_at" DESC);



CREATE INDEX "properties_created_at_idx" ON "public"."properties" USING "btree" ("created_at" DESC);



CREATE INDEX "team_join_requests_status_created_at_idx" ON "public"."team_join_requests" USING "btree" ("status", "created_at" DESC);



CREATE UNIQUE INDEX "team_members_team_id_user_id_idx" ON "public"."team_members" USING "btree" ("team_id", "user_id") WHERE ("user_id" IS NOT NULL);



CREATE INDEX "team_message_reads_user_id_idx" ON "public"."team_message_reads" USING "btree" ("user_id");



CREATE INDEX "team_messages_team_created_at_idx" ON "public"."team_messages" USING "btree" ("team_id", "created_at" DESC);



CREATE OR REPLACE TRIGGER "conversations_set_updated_at" BEFORE UPDATE ON "public"."conversations" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at_timestamp"();



CREATE OR REPLACE TRIGGER "messages_touch_conversation" AFTER INSERT OR DELETE OR UPDATE ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "public"."touch_conversation_from_message"();



CREATE OR REPLACE TRIGGER "profiles_protect_role" BEFORE INSERT OR UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."protect_profile_role"();



CREATE OR REPLACE TRIGGER "profiles_set_updated_at" BEFORE UPDATE ON "public"."profiles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at_timestamp"();



CREATE OR REPLACE TRIGGER "properties_set_updated_at" BEFORE UPDATE ON "public"."properties" FOR EACH ROW EXECUTE FUNCTION "public"."set_properties_updated_at"();



CREATE OR REPLACE TRIGGER "send_notification_on_new_message" AFTER INSERT ON "public"."messages" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://vludvvjkrrqzjahxjdjl.supabase.co/functions/v1/send-push-notification', 'POST', '{"Content-type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZsdWR2dmprcnJxemphaHhqZGpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUyNjEyMjUsImV4cCI6MjA5MDgzNzIyNX0.Lm4Fmi_1-7VhV9vVpZF2NZNo3oQuGFpsDo2jNMczB9I"}', '{}', '5000');



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_buyer_id_fkey" FOREIGN KEY ("buyer_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."conversations"
    ADD CONSTRAINT "conversations_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."properties"
    ADD CONSTRAINT "properties_agent_id_fkey" FOREIGN KEY ("agent_id") REFERENCES "public"."profiles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."properties"
    ADD CONSTRAINT "properties_agent_team_id_fkey" FOREIGN KEY ("agent_team_id") REFERENCES "public"."agent_teams"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."team_join_requests"
    ADD CONSTRAINT "team_join_requests_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."agent_teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_join_requests"
    ADD CONSTRAINT "team_join_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."agent_teams"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."team_message_reads"
    ADD CONSTRAINT "team_message_reads_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "public"."team_messages"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_message_reads"
    ADD CONSTRAINT "team_message_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_messages"
    ADD CONSTRAINT "team_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_messages"
    ADD CONSTRAINT "team_messages_team_id_fkey" FOREIGN KEY ("team_id") REFERENCES "public"."agent_teams"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can add team members" ON "public"."team_members" FOR INSERT TO "authenticated" WITH CHECK (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can create agent teams" ON "public"."agent_teams" FOR INSERT TO "authenticated" WITH CHECK (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can delete agent teams" ON "public"."agent_teams" FOR DELETE TO "authenticated" USING (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can delete properties" ON "public"."properties" FOR DELETE TO "authenticated" USING ((( SELECT (("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can delete team members" ON "public"."team_members" FOR DELETE TO "authenticated" USING (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can delete team messages" ON "public"."team_messages" FOR DELETE TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("lower"(COALESCE("p"."role", ''::"text")) = 'admin'::"text")))));



CREATE POLICY "Admins can insert properties" ON "public"."properties" FOR INSERT TO "authenticated" WITH CHECK ((( SELECT (("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can read team messages" ON "public"."team_messages" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("lower"(COALESCE("p"."role", ''::"text")) = 'admin'::"text")))));



CREATE POLICY "Admins can send team messages" ON "public"."team_messages" FOR INSERT TO "authenticated" WITH CHECK ((("sender_id" = "auth"."uid"()) AND (EXISTS ( SELECT 1
   FROM "public"."profiles" "p"
  WHERE (("p"."id" = "auth"."uid"()) AND ("lower"(COALESCE("p"."role", ''::"text")) = 'admin'::"text"))))));



CREATE POLICY "Admins can update agent teams" ON "public"."agent_teams" FOR UPDATE TO "authenticated" USING (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text")) WITH CHECK (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can update properties" ON "public"."properties" FOR UPDATE TO "authenticated" USING ((( SELECT (("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text")) = 'admin'::"text")) WITH CHECK ((( SELECT (("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can update team join requests" ON "public"."team_join_requests" FOR UPDATE TO "authenticated" USING (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text")) WITH CHECK (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can update team members" ON "public"."team_members" FOR UPDATE TO "authenticated" USING (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text")) WITH CHECK (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text"));



CREATE POLICY "Admins can view all team join requests" ON "public"."team_join_requests" FOR SELECT TO "authenticated" USING (("lower"(COALESCE((("auth"."jwt"() -> 'app_metadata'::"text") ->> 'role'::"text"), (("auth"."jwt"() -> 'user_metadata'::"text") ->> 'role'::"text"), ''::"text")) = 'admin'::"text"));



CREATE POLICY "Authenticated users can view negros places" ON "public"."negros_places" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Authenticated users can view properties" ON "public"."properties" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "Participants can create conversations" ON "public"."conversations" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_admin"() OR ("auth"."uid"() = "buyer_id") OR ("auth"."uid"() = "agent_id")));



CREATE POLICY "Participants can delete conversations" ON "public"."conversations" FOR DELETE TO "authenticated" USING (("public"."is_admin"() OR ("auth"."uid"() = "buyer_id") OR ("auth"."uid"() = "agent_id")));



CREATE POLICY "Participants can send messages" ON "public"."messages" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_admin"() OR (("auth"."uid"() = "sender_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations"
  WHERE (("conversations"."id" = "messages"."conversation_id") AND (("conversations"."buyer_id" = "auth"."uid"()) OR ("conversations"."agent_id" = "auth"."uid"()))))))));



CREATE POLICY "Participants can update conversations" ON "public"."conversations" FOR UPDATE TO "authenticated" USING (("public"."is_admin"() OR ("auth"."uid"() = "buyer_id") OR ("auth"."uid"() = "agent_id"))) WITH CHECK (("public"."is_admin"() OR ("auth"."uid"() = "buyer_id") OR ("auth"."uid"() = "agent_id")));



CREATE POLICY "Participants can view conversations" ON "public"."conversations" FOR SELECT TO "authenticated" USING (("public"."is_admin"() OR ("auth"."uid"() = "buyer_id") OR ("auth"."uid"() = "agent_id")));



CREATE POLICY "Participants can view messages" ON "public"."messages" FOR SELECT TO "authenticated" USING (("public"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "public"."conversations"
  WHERE (("conversations"."id" = "messages"."conversation_id") AND (("conversations"."buyer_id" = "auth"."uid"()) OR ("conversations"."agent_id" = "auth"."uid"())))))));



CREATE POLICY "Public read" ON "public"."agent_teams" FOR SELECT USING (true);



CREATE POLICY "Public read" ON "public"."team_members" FOR SELECT USING (true);



CREATE POLICY "Senders can delete own messages" ON "public"."messages" FOR DELETE TO "authenticated" USING (("public"."is_admin"() OR (("auth"."uid"() = "sender_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations"
  WHERE (("conversations"."id" = "messages"."conversation_id") AND (("conversations"."buyer_id" = "auth"."uid"()) OR ("conversations"."agent_id" = "auth"."uid"()))))))));



CREATE POLICY "Senders can update own messages" ON "public"."messages" FOR UPDATE TO "authenticated" USING (("public"."is_admin"() OR (("auth"."uid"() = "sender_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations"
  WHERE (("conversations"."id" = "messages"."conversation_id") AND (("conversations"."buyer_id" = "auth"."uid"()) OR ("conversations"."agent_id" = "auth"."uid"())))))))) WITH CHECK (("public"."is_admin"() OR (("auth"."uid"() = "sender_id") AND (EXISTS ( SELECT 1
   FROM "public"."conversations"
  WHERE (("conversations"."id" = "messages"."conversation_id") AND (("conversations"."buyer_id" = "auth"."uid"()) OR ("conversations"."agent_id" = "auth"."uid"()))))))));



CREATE POLICY "Team members can delete their own team messages" ON "public"."team_messages" FOR DELETE TO "authenticated" USING (("public"."is_admin"() OR ("sender_id" = "auth"."uid"())));



CREATE POLICY "Team members can send team messages" ON "public"."team_messages" FOR INSERT TO "authenticated" WITH CHECK ((("sender_id" = "auth"."uid"()) AND ("length"(TRIM(BOTH FROM "body")) > 0) AND ("char_length"("body") <= 1000) AND ("public"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "public"."team_members" "tm"
  WHERE (("tm"."team_id" = "team_messages"."team_id") AND ("tm"."user_id" = "auth"."uid"())))))));



CREATE POLICY "Team members can update their own team messages" ON "public"."team_messages" FOR UPDATE TO "authenticated" USING (("public"."is_admin"() OR ("sender_id" = "auth"."uid"()))) WITH CHECK ((("public"."is_admin"() OR ("sender_id" = "auth"."uid"())) AND ("length"(TRIM(BOTH FROM "body")) > 0) AND ("char_length"("body") <= 1000)));



CREATE POLICY "Team members can view team messages" ON "public"."team_messages" FOR SELECT TO "authenticated" USING (("public"."is_admin"() OR (EXISTS ( SELECT 1
   FROM "public"."team_members" "tm"
  WHERE (("tm"."team_id" = "team_messages"."team_id") AND ("tm"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Team readers can view team message reads" ON "public"."team_message_reads" FOR SELECT TO "authenticated" USING (("public"."is_admin"() OR (EXISTS ( SELECT 1
   FROM ("public"."team_messages" "message"
     JOIN "public"."team_members" "member" ON (("member"."team_id" = "message"."team_id")))
  WHERE (("message"."id" = "team_message_reads"."message_id") AND ("member"."user_id" = "auth"."uid"()))))));



CREATE POLICY "Users can create own team join requests" ON "public"."team_join_requests" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can delete their own notifications" ON "public"."notifications" FOR DELETE TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."profiles" FOR INSERT TO "authenticated" WITH CHECK (("public"."is_admin"() OR ("auth"."uid"() = "id")));



CREATE POLICY "Users can insert their own notifications" ON "public"."notifications" FOR INSERT TO "authenticated" WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can mark own team messages as read" ON "public"."team_message_reads" FOR INSERT TO "authenticated" WITH CHECK ((("user_id" = "auth"."uid"()) AND ("public"."is_admin"() OR (EXISTS ( SELECT 1
   FROM ("public"."team_messages" "message"
     JOIN "public"."team_members" "member" ON (("member"."team_id" = "message"."team_id")))
  WHERE (("message"."id" = "team_message_reads"."message_id") AND ("member"."user_id" = "auth"."uid"())))))));



CREATE POLICY "Users can refresh own team message reads" ON "public"."team_message_reads" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE TO "authenticated" USING (("public"."is_admin"() OR ("auth"."uid"() = "id"))) WITH CHECK (("public"."is_admin"() OR ("auth"."uid"() = "id")));



CREATE POLICY "Users can update their own notifications" ON "public"."notifications" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own team join requests" ON "public"."team_join_requests" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view related profiles" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("public"."is_admin"() OR ("auth"."uid"() = "id") OR ("role" = ANY (ARRAY['agent'::"text", 'admin'::"text"])) OR (EXISTS ( SELECT 1
   FROM "public"."conversations"
  WHERE ((("conversations"."buyer_id" = "auth"."uid"()) OR ("conversations"."agent_id" = "auth"."uid"())) AND (("profiles"."id" = "conversations"."buyer_id") OR ("profiles"."id" = "conversations"."agent_id")))))));



CREATE POLICY "Users can view their own notifications" ON "public"."notifications" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."agent_teams" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."conversations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."negros_places" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."properties" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."team_join_requests" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."team_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."team_message_reads" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."team_messages" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."create_message_notification"("p_conversation_id" "uuid", "p_message_preview" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_message_notification"("p_conversation_id" "uuid", "p_message_preview" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_message_notification"("p_conversation_id" "uuid", "p_message_preview" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_property_view_count"("property_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."increment_property_view_count"("property_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_property_view_count"("property_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



GRANT ALL ON FUNCTION "public"."normalize_profile_role"("input_role" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."normalize_profile_role"("input_role" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."normalize_profile_role"("input_role" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."protect_profile_role"() TO "anon";
GRANT ALL ON FUNCTION "public"."protect_profile_role"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."protect_profile_role"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_properties_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_properties_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_properties_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."sync_profile_from_auth_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."sync_profile_from_auth_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."sync_profile_from_auth_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."touch_conversation_from_message"() TO "anon";
GRANT ALL ON FUNCTION "public"."touch_conversation_from_message"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."touch_conversation_from_message"() TO "service_role";



GRANT ALL ON TABLE "public"."agent_teams" TO "anon";
GRANT ALL ON TABLE "public"."agent_teams" TO "authenticated";
GRANT ALL ON TABLE "public"."agent_teams" TO "service_role";



GRANT ALL ON TABLE "public"."conversations" TO "anon";
GRANT ALL ON TABLE "public"."conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."conversations" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."negros_places" TO "anon";
GRANT ALL ON TABLE "public"."negros_places" TO "authenticated";
GRANT ALL ON TABLE "public"."negros_places" TO "service_role";



GRANT ALL ON SEQUENCE "public"."negros_places_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."negros_places_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."negros_places_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."properties" TO "anon";
GRANT ALL ON TABLE "public"."properties" TO "authenticated";
GRANT ALL ON TABLE "public"."properties" TO "service_role";



GRANT ALL ON TABLE "public"."team_join_requests" TO "anon";
GRANT ALL ON TABLE "public"."team_join_requests" TO "authenticated";
GRANT ALL ON TABLE "public"."team_join_requests" TO "service_role";



GRANT ALL ON TABLE "public"."team_members" TO "anon";
GRANT ALL ON TABLE "public"."team_members" TO "authenticated";
GRANT ALL ON TABLE "public"."team_members" TO "service_role";



GRANT ALL ON TABLE "public"."team_message_reads" TO "anon";
GRANT ALL ON TABLE "public"."team_message_reads" TO "authenticated";
GRANT ALL ON TABLE "public"."team_message_reads" TO "service_role";



GRANT ALL ON TABLE "public"."team_messages" TO "anon";
GRANT ALL ON TABLE "public"."team_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."team_messages" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







