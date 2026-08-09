-- Yemeğin öğündeki rolü (0020).
alter table public.foods add column if not exists role text not null default 'keyfi';
create index if not exists foods_role_idx on public.foods (role);
comment on column public.foods.role is
  'corba | ana | garnitur | yan | ekmek | kahvalti_protein | kahvalti_yan | meyve | sut | kuruyemis | keyfi | icecek';
