-- ===================================================
-- PERBAIKAN KEAMANAN DATABASE PremiumHub
-- Jalankan di: Supabase -> SQL Editor -> New query -> Run
-- Aman dijalankan di atas schema.sql yang sudah ada.
-- ===================================================

-- 1. Hapus policy lama yang terlalu longgar (siapa saja bisa baca/ubah semua data)
drop policy if exists "Allow public select profiles" on public.profiles;
drop policy if exists "Allow insert profiles" on public.profiles;
drop policy if exists "Allow update profiles" on public.profiles;
drop policy if exists "Allow insert orders" on public.orders;
drop policy if exists "Allow read orders" on public.orders;
drop policy if exists "Allow update orders" on public.orders;

-- 2. Kaitkan pesanan dengan pemilik akunnya
alter table public.orders
  add column if not exists user_id uuid references auth.users(id) default auth.uid();

-- 3. Profiles: hanya pemilik yang boleh lihat dan ubah datanya sendiri
create policy "profiles: baca milik sendiri" on public.profiles
  for select using (auth.uid() = id);
create policy "profiles: ubah milik sendiri" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- 4. Orders: pembeli hanya boleh membuat pesanan baru berstatus pending
--    dan melihat pesanannya sendiri. Tidak ada UPDATE dari browser
--    (status lunas hanya boleh diubah server/webhook nanti).
create policy "orders: buat pesanan sendiri" on public.orders
  for insert to authenticated
  with check (auth.uid() = user_id and status = 'pending_payment');
create policy "orders: baca milik sendiri" on public.orders
  for select to authenticated using (auth.uid() = user_id);

-- 5. Profil dibuat otomatis oleh database saat ada pendaftaran baru
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name, phone)
  values (new.id, new.email,
          new.raw_user_meta_data->>'full_name',
          new.raw_user_meta_data->>'phone')
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
