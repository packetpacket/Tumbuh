-- Tumbuh: jalankan pada proyek Supabase khusus aplikasi anak.
begin;
create table if not exists public.tumbuh_staff (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null default 'caregiver' check(role in ('admin','caregiver')),
 created_at timestamptz not null default now()
);
create table if not exists public.tumbuh_children (
 id uuid primary key default gen_random_uuid(),
 full_name text not null check(length(trim(full_name)) between 1 and 150),
 nickname text not null default '', birth_place text not null default '',
 birth_date date not null check(birth_date between date '1900-01-01' and current_date),
 active boolean not null default true,
 created_at timestamptz not null default now(),
 unique(full_name,birth_date)
);
create table if not exists public.tumbuh_assessments (
 id uuid primary key default gen_random_uuid(),
 child_id uuid not null references public.tumbuh_children(id),
 period date not null check(extract(day from period)=1),
 reference_date date not null,
 group_index integer not null check(group_index between -1 and 3),
 indicators jsonb not null check(jsonb_typeof(indicators)='array'),
 answers jsonb not null default '{}'::jsonb check(jsonb_typeof(answers)='object'),
 status text not null default 'draft' check(status in ('draft','final')),
 revision integer not null default 1 check(revision>0),
 created_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now(),
 unique(child_id,period)
);
create index if not exists tumbuh_assessments_period_idx on public.tumbuh_assessments(period);
create or replace function public.tumbuh_update_timestamp()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin new.updated_at=now(); return new; end; $$;
revoke execute on function public.tumbuh_update_timestamp() from public,anon,authenticated;
drop trigger if exists tumbuh_assessments_timestamp on public.tumbuh_assessments;
create trigger tumbuh_assessments_timestamp before update on public.tumbuh_assessments
for each row execute function public.tumbuh_update_timestamp();
alter table public.tumbuh_staff enable row level security;
alter table public.tumbuh_children enable row level security;
alter table public.tumbuh_assessments enable row level security;
revoke all on public.tumbuh_staff,public.tumbuh_children,public.tumbuh_assessments from anon,authenticated;
grant select on public.tumbuh_staff to authenticated;
grant select,insert,update on public.tumbuh_children,public.tumbuh_assessments to authenticated;
drop policy if exists staff_self on public.tumbuh_staff;
create policy staff_self on public.tumbuh_staff for select to authenticated using(user_id=(select auth.uid()));
drop policy if exists children_read on public.tumbuh_children;
create policy children_read on public.tumbuh_children for select to authenticated using(exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid())));
drop policy if exists children_insert on public.tumbuh_children;
create policy children_insert on public.tumbuh_children for insert to authenticated with check(exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid()) and role='admin'));
drop policy if exists children_update on public.tumbuh_children;
create policy children_update on public.tumbuh_children for update to authenticated using(exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid()) and role='admin')) with check(exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid()) and role='admin'));
drop policy if exists assessments_read on public.tumbuh_assessments;
create policy assessments_read on public.tumbuh_assessments for select to authenticated using(exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid())));
drop policy if exists assessments_insert on public.tumbuh_assessments;
create policy assessments_insert on public.tumbuh_assessments for insert to authenticated with check(created_by=(select auth.uid()) and exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid())));
drop policy if exists assessments_update on public.tumbuh_assessments;
create policy assessments_update on public.tumbuh_assessments for update to authenticated using(exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid()))) with check(exists(select 1 from public.tumbuh_staff where user_id=(select auth.uid())));
commit;
-- Setelah membuat akun melalui Authentication > Users, tambahkan UID-nya:
-- insert into public.tumbuh_staff(user_id,role) values ('UID-AKUN-ADMIN','admin');
-- insert into public.tumbuh_staff(user_id,role) values ('UID-AKUN-PENDAMPING','caregiver');
-- Cabut akses dengan: delete from public.tumbuh_staff where user_id='UID-AKUN';
