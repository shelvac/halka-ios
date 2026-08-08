-- Menüden kaldırılan öğünler (US-024 devamı).
--
-- Plan menüsü sabit dört öğünden oluşuyor ve kullanıcı beğenmediği bir
-- öğünü kaldıramıyordu; tek seçenek katalogdan başkasıyla değiştirmekti.
-- Kaldırılan öğün gün toplamına ve beslenme halkasına da girmemeli.
--
-- `eaten` ile aynı biçim: "gün-öğün" anahtarları ("0-1"). Haftalık kayıt
-- olduğu için `week_start` eskiyse istemci zaten yok sayıyor.

alter table public.meal_state
  add column if not exists removed jsonb not null default '[]'::jsonb;

comment on column public.meal_state.removed is
  'Kullanıcının menüden kaldırdığı plan öğünleri ("gün-öğün" anahtarları).';
