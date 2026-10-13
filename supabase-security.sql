-- Tambahan keamanan akun. Jalankan setelah supabase-schema.sql; aman dijalankan ulang.
begin;
create schema if not exists tumbuh_private;
revoke all on schema tumbuh_private from public,anon,authenticated;
grant usage on schema tumbuh_private to authenticated;
create extension if not exists pgcrypto with schema extensions;
create table if not exists tumbuh_private.pins (
 user_id uuid primary key references auth.users(id) on delete cascade,
 pin_hash text not null, attempts integer not null default 0,
 locked_until timestamptz, updated_at timestamptz not null default now()
);
create table if not exists tumbuh_private.unlocks (
 session_id text primary key, user_id uuid not null references auth.users(id) on delete cascade,
 expires_at timestamptz not null
);
create index if not exists tumbuh_unlocks_user_idx on tumbuh_private.unlocks(user_id);
alter table tumbuh_private.pins enable row level security;
alter table tumbuh_private.unlocks enable row level security;
revoke all on tumbuh_private.pins,tumbuh_private.unlocks from public,anon,authenticated;
create or replace function tumbuh_private.is_unlocked()
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from tumbuh_private.unlocks u
 where u.user_id=(select auth.uid()) and u.session_id=(select auth.jwt()->>'session_id')
 and u.expires_at>now())
 and exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid()));
$$;
revoke all on function tumbuh_private.is_unlocked() from public,anon,authenticated;
grant execute on function tumbuh_private.is_unlocked() to authenticated;
create or replace function tumbuh_private.security_action(p_action text,p_pin text,p_old_pin text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 uid uuid:=auth.uid(); sid text:=auth.jwt()->>'session_id'; p tumbuh_private.pins%rowtype;
 fresh_oauth boolean; fresh_passkey boolean; expiry timestamptz; valid boolean;
begin
 if uid is null or sid is null or not exists(select 1 from public.tumbuh_staff where user_id=uid)
 or not exists(select 1 from auth.identities where user_id=uid and provider='google') then
 return jsonb_build_object('ok',false,'error','Akun Google belum diberi akses oleh admin.'); end if;
 -- Serialize per account, including first-time PIN creation.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text,0));
 select * into p from tumbuh_private.pins where user_id=uid for update;
 select exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a
 where a->>'method'='oauth' and (a->>'timestamp')::numeric>extract(epoch from now())-300
 and (a->>'timestamp')::numeric<=extract(epoch from now())+30) into fresh_oauth;
 select exists(select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr','[]'::jsonb)) a
 where a->>'method'='passkey' and (a->>'timestamp')::numeric>extract(epoch from now())-120
 and (a->>'timestamp')::numeric<=extract(epoch from now())+30) into fresh_passkey;
 if p_action='status' then
 select expires_at into expiry from tumbuh_private.unlocks where session_id=sid and user_id=uid;
 return jsonb_build_object('ok',true,'has_pin',p.user_id is not null,'unlocked',coalesce(expiry>now(),false),'expires_at',expiry,'locked_until',p.locked_until);
 elsif p_action='lock' then
 delete from tumbuh_private.unlocks where session_id=sid and user_id=uid;
 return jsonb_build_object('ok',true);
 elsif p_action='passkey' then
 if p.user_id is null or not fresh_passkey then return jsonb_build_object('ok',false,'error','Verifikasi passkey baru diperlukan.'); end if;
 elsif p_action in ('verify','set','reset') then
 if p_action in ('set','reset') and (p_pin is null or p_pin !~ '^[0-9]{6}$') then
 return jsonb_build_object('ok',false,'error','PIN harus terdiri dari 6 angka.'); end if;
 if p_action='reset' or (p_action='set' and p.user_id is null) then
 if not fresh_oauth then return jsonb_build_object('ok',false,'error','Masuk ulang dengan Google sebelum membuat atau mereset PIN.'); end if;
 else
 if p.user_id is null then return jsonb_build_object('ok',false,'error','Buat PIN terlebih dahulu.'); end if;
 if p.locked_until>now() then return jsonb_build_object('ok',false,'error','Terlalu banyak percobaan. Coba lagi setelah 15 menit.','locked_until',p.locked_until); end if;
 valid:=extensions.crypt(coalesce(case when p_action='verify' then p_pin else p_old_pin end,''),p.pin_hash)=p.pin_hash;
 if not valid then
 update tumbuh_private.pins set attempts=case when locked_until is not null and locked_until<=now() then 1 else attempts+1 end,
 locked_until=case when (case when locked_until is not null and locked_until<=now() then 1 else attempts+1 end)>=5 then now()+interval '15 minutes' else null end where user_id=uid returning * into p;
 return jsonb_build_object('ok',false,'error',case when p.locked_until>now() then 'PIN salah 5 kali. Coba lagi setelah 15 menit.' else 'PIN salah. Silakan coba lagi.' end,'locked_until',p.locked_until);
 end if;
 end if;
 if p_action in ('set','reset') then
 insert into tumbuh_private.pins(user_id,pin_hash) values(uid,extensions.crypt(p_pin,extensions.gen_salt('bf',10)))
 on conflict(user_id) do update set pin_hash=excluded.pin_hash,attempts=0,locked_until=null,updated_at=now();
 delete from tumbuh_private.unlocks where user_id=uid;
 else update tumbuh_private.pins set attempts=0,locked_until=null where user_id=uid; end if;
 else return jsonb_build_object('ok',false,'error','Permintaan tidak dikenal.'); end if;
 expiry:=now()+interval '30 minutes';
 delete from tumbuh_private.unlocks where expires_at<=now();
 insert into tumbuh_private.unlocks(session_id,user_id,expires_at) values(sid,uid,expiry)
 on conflict(session_id) do update set expires_at=excluded.expires_at,user_id=excluded.user_id;
 return jsonb_build_object('ok',true,'has_pin',true,'unlocked',true,'expires_at',expiry);
end; $$;
revoke all on function tumbuh_private.security_action(text,text,text) from public,anon,authenticated;
grant execute on function tumbuh_private.security_action(text,text,text) to authenticated;
create or replace function public.tumbuh_security(p_action text,p_pin text default null,p_old_pin text default null)
returns jsonb language sql security invoker set search_path='' as $$
 select tumbuh_private.security_action(p_action,p_pin,p_old_pin);
$$;
revoke all on function public.tumbuh_security(text,text,text) from public,anon,authenticated;
grant execute on function public.tumbuh_security(text,text,text) to authenticated;
-- Restrictive policies also apply to pre-existing permissive staff policies.
drop policy if exists children_require_unlock on public.tumbuh_children;
create policy children_require_unlock on public.tumbuh_children as restrictive for all to authenticated
 using((select tumbuh_private.is_unlocked())) with check((select tumbuh_private.is_unlocked()));
drop policy if exists assessments_require_unlock on public.tumbuh_assessments;
create policy assessments_require_unlock on public.tumbuh_assessments as restrictive for all to authenticated
 using((select tumbuh_private.is_unlocked())) with check((select tumbuh_private.is_unlocked()));
commit;
