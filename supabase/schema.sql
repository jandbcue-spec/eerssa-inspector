-- =========================================================
-- EERSSA Inspector — esquema de Supabase
-- Ejecutar en: Supabase Dashboard → SQL Editor → New query
-- =========================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------
-- Tabla principal de inspecciones
-- ---------------------------------------------------------
create table if not exists public.inspecciones (
  id uuid primary key default gen_random_uuid(),
  local_id text unique,                          -- id generado en el dispositivo (evita duplicados al sincronizar)
  inspector_id uuid references auth.users(id),
  poste text not null,
  fecha date not null,
  hora time not null,
  provincia text not null,
  canton text not null,
  parroquia text not null,
  alimentador text not null,
  tipo text not null check (tipo in ('SODIO','LED')),
  potencia integer not null,
  gps_lat numeric,
  gps_lng numeric,
  estado text not null check (estado in ('Encendida','Apagada','Intermitente','Sin Novedad')),
  brazo_mal_orientado boolean not null default false,
  difusor jsonb not null default '{}'::jsonb,      -- ej. {"Roto":true,"Opaco":false,...}
  otros jsonb not null default '{}'::jsonb,        -- ej. {"Falta luminaria":true,...}
  observaciones text,
  foto_dia_url text,
  foto_noche_url text,
  pendiente boolean generated always as (foto_dia_url is null or foto_noche_url is null) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_inspecciones_inspector on public.inspecciones(inspector_id);
create index if not exists idx_inspecciones_fecha on public.inspecciones(fecha desc);
create index if not exists idx_inspecciones_pendiente on public.inspecciones(pendiente);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_inspecciones_updated_at on public.inspecciones;
create trigger trg_inspecciones_updated_at
before update on public.inspecciones
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------
-- Seguridad a nivel de fila (RLS)
-- Todos los inspectores autenticados pueden VER todas las inspecciones
-- (app colaborativa), pero solo pueden crear/editar las suyas propias.
-- ---------------------------------------------------------
alter table public.inspecciones enable row level security;

drop policy if exists "select_all_authenticated" on public.inspecciones;
create policy "select_all_authenticated"
on public.inspecciones for select
to authenticated
using (true);

drop policy if exists "insert_own" on public.inspecciones;
create policy "insert_own"
on public.inspecciones for insert
to authenticated
with check (inspector_id = auth.uid());

drop policy if exists "update_own" on public.inspecciones;
create policy "update_own"
on public.inspecciones for update
to authenticated
using (inspector_id = auth.uid())
with check (inspector_id = auth.uid());

drop policy if exists "delete_own" on public.inspecciones;
create policy "delete_own"
on public.inspecciones for delete
to authenticated
using (inspector_id = auth.uid());

-- ---------------------------------------------------------
-- Storage: bucket para fotografías de día/noche
-- NOTA: se crea como bucket público para simplificar la carga del
-- prototipo (fotos de postes, no son datos sensibles). Si se requiere
-- privacidad, cambiar "public" a false y servir con signed URLs.
-- ---------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('fotos-inspecciones', 'fotos-inspecciones', true)
on conflict (id) do nothing;

drop policy if exists "fotos_lectura_publica" on storage.objects;
create policy "fotos_lectura_publica"
on storage.objects for select
to public
using (bucket_id = 'fotos-inspecciones');

drop policy if exists "fotos_subida_autenticados" on storage.objects;
create policy "fotos_subida_autenticados"
on storage.objects for insert
to authenticated
with check (bucket_id = 'fotos-inspecciones');

drop policy if exists "fotos_actualizacion_autenticados" on storage.objects;
create policy "fotos_actualizacion_autenticados"
on storage.objects for update
to authenticated
using (bucket_id = 'fotos-inspecciones');

drop policy if exists "fotos_eliminacion_autenticados" on storage.objects;
create policy "fotos_eliminacion_autenticados"
on storage.objects for delete
to authenticated
using (bucket_id = 'fotos-inspecciones');

-- ---------------------------------------------------------
-- Usuarios de prueba
-- Crear inspectores desde: Dashboard → Authentication → Users → Add user
-- Email sugerido: usuario@eerssa.gob.ec (coincide con el login de la app,
-- que autocompleta "@eerssa.gob.ec" si solo se ingresa el usuario/cédula).
-- ---------------------------------------------------------
