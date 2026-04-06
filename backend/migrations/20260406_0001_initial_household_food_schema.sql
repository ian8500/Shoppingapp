-- Initial relational schema for shared household food management.
-- Postgres/Supabase compatible.

begin;

create extension if not exists pgcrypto;

-- Generic updated_at trigger function.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'admin', 'member')),
  status text not null default 'active' check (status in ('active', 'invited', 'removed')),
  joined_at timestamptz,
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, user_id)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  canonical_name text not null,
  canonical_name_normalized text not null,
  brand text,
  category text,
  default_unit text,
  created_by uuid references auth.users(id) on delete set null,
  owning_household_id uuid references public.households(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owning_household_id, canonical_name_normalized)
);

create table if not exists public.product_aliases (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  alias text not null,
  alias_normalized text not null,
  household_id uuid references public.households(id) on delete cascade,
  source text not null default 'manual' check (source in ('manual', 'import', 'barcode', 'system')),
  confidence numeric(4,3) check (confidence is null or (confidence >= 0 and confidence <= 1)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- unique global alias (household_id is null)
create unique index if not exists ux_product_aliases_global
  on public.product_aliases (alias_normalized)
  where household_id is null;

-- unique alias per household
create unique index if not exists ux_product_aliases_household
  on public.product_aliases (household_id, alias_normalized)
  where household_id is not null;

create table if not exists public.barcode_mappings (
  id uuid primary key default gen_random_uuid(),
  barcode text not null,
  product_id uuid not null references public.products(id) on delete cascade,
  household_id uuid references public.households(id) on delete cascade,
  source text not null default 'manual' check (source in ('manual', 'openfoodfacts', 'receipt_ocr', 'system')),
  confidence numeric(4,3) not null default 1 check (confidence >= 0 and confidence <= 1),
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(trim(barcode)) > 0)
);

create unique index if not exists ux_barcode_mappings_global
  on public.barcode_mappings (barcode)
  where household_id is null;

create unique index if not exists ux_barcode_mappings_household
  on public.barcode_mappings (household_id, barcode)
  where household_id is not null;

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity numeric(12,3) not null default 0 check (quantity >= 0),
  unit text not null,
  location text,
  low_stock_threshold numeric(12,3) check (low_stock_threshold is null or low_stock_threshold >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists ux_inventory_items_identity
  on public.inventory_items (household_id, product_id, unit, coalesce(location, ''));

create table if not exists public.inventory_transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  inventory_item_id uuid references public.inventory_items(id) on delete set null,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity_delta numeric(12,3) not null check (quantity_delta <> 0),
  unit text not null,
  reason text not null check (reason in ('manual_adjustment', 'purchase', 'consume', 'waste', 'recipe_use', 'transfer', 'correction')),
  note text,
  actor_user_id uuid references auth.users(id) on delete set null,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create table if not exists public.shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  item_name text,
  quantity numeric(12,3) check (quantity is null or quantity >= 0),
  unit text,
  notes text,
  category text,
  status text not null default 'pending' check (status in ('pending', 'in_progress', 'purchased', 'archived')),
  added_by uuid references auth.users(id) on delete set null,
  bought_by uuid references auth.users(id) on delete set null,
  bought_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (product_id is not null or item_name is not null)
);

create table if not exists public.recipes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid references public.households(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete restrict,
  scope text not null default 'household' check (scope in ('household', 'user', 'global')),
  title text not null,
  description text,
  instructions text,
  servings numeric(8,2),
  prep_minutes integer check (prep_minutes is null or prep_minutes >= 0),
  cook_minutes integer check (cook_minutes is null or cook_minutes >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (scope = 'household' and household_id is not null)
    or (scope in ('user', 'global'))
  )
);

create table if not exists public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  ingredient_text text not null,
  quantity numeric(12,3),
  unit text,
  is_optional boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (quantity is null or quantity >= 0)
);

-- Updated-at triggers
create trigger trg_households_updated_at
before update on public.households
for each row execute function public.set_updated_at();

create trigger trg_household_members_updated_at
before update on public.household_members
for each row execute function public.set_updated_at();

create trigger trg_products_updated_at
before update on public.products
for each row execute function public.set_updated_at();

create trigger trg_product_aliases_updated_at
before update on public.product_aliases
for each row execute function public.set_updated_at();

create trigger trg_barcode_mappings_updated_at
before update on public.barcode_mappings
for each row execute function public.set_updated_at();

create trigger trg_inventory_items_updated_at
before update on public.inventory_items
for each row execute function public.set_updated_at();

create trigger trg_shopping_list_items_updated_at
before update on public.shopping_list_items
for each row execute function public.set_updated_at();

create trigger trg_recipes_updated_at
before update on public.recipes
for each row execute function public.set_updated_at();

create trigger trg_recipe_ingredients_updated_at
before update on public.recipe_ingredients
for each row execute function public.set_updated_at();

-- Performance indexes
create index if not exists ix_household_members_user
  on public.household_members (user_id, status);

create index if not exists ix_products_name
  on public.products (canonical_name_normalized);

create index if not exists ix_product_aliases_product
  on public.product_aliases (product_id);

create index if not exists ix_barcode_mappings_product
  on public.barcode_mappings (product_id);

create index if not exists ix_inventory_items_household
  on public.inventory_items (household_id);

create index if not exists ix_inventory_items_low_stock
  on public.inventory_items (household_id, quantity, low_stock_threshold)
  where low_stock_threshold is not null;

create index if not exists ix_inventory_transactions_household_occurred
  on public.inventory_transactions (household_id, occurred_at desc);

create index if not exists ix_inventory_transactions_item
  on public.inventory_transactions (inventory_item_id, occurred_at desc);

create index if not exists ix_inventory_transactions_actor
  on public.inventory_transactions (actor_user_id, occurred_at desc);

create index if not exists ix_shopping_list_items_household_status
  on public.shopping_list_items (household_id, status, created_at desc);

create index if not exists ix_shopping_list_items_product
  on public.shopping_list_items (product_id)
  where product_id is not null;

create index if not exists ix_recipes_scope_household
  on public.recipes (scope, household_id, created_at desc);

create index if not exists ix_recipe_ingredients_recipe
  on public.recipe_ingredients (recipe_id, sort_order);

create index if not exists ix_recipe_ingredients_product
  on public.recipe_ingredients (product_id)
  where product_id is not null;

commit;
