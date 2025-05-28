## AdminEcommerceApp with Flutter-Postgresql-SUPABASE 
## RESTApi


<div style="display: flex; gap: 5px;">
  <img src="https://github.com/user-attachments/assets/3e686c38-186c-411d-9f51-94fcb7ab7529" style="width:18%;" />
  <img src="https://github.com/user-attachments/assets/21444645-df7c-452d-beda-539717f17696" style="width:18%;" />
  <img src="https://github.com/user-attachments/assets/d978ceec-0df0-426b-b078-ef1bca99e636" style="width:18%;" />
  <img src="https://github.com/user-attachments/assets/95cbf88c-a7cd-4a40-b7c8-5092dcc2850b" style="width:18%;" />
  <img src="https://github.com/user-attachments/assets/21fabea0-51d3-4d14-ad53-e440eba4bdaa" style="width:18%;" />
</div>


# PostgreSql
## sql codes: 

<code>
create table products (

  id          serial primary key,
  name        text        not null,
  description text,
  price       numeric(10,2) not null,
  image_url   text

);


create table carts (
  id          serial primary key,
  user_id     uuid        not null,
  created_at  timestamptz default now()
);
create table cart_items (

  id          serial primary key,
  cart_id     integer     references carts(id),
  product_id  integer     references products(id),
  quantity    integer     default 1

);

create table orders (

  id          serial primary key,
  user_id     uuid      not null,
  total       numeric(10,2),
  created_at  timestamptz default now()

);

create table order_items (

  id          serial primary key,
  order_id    integer    references orders(id),
  product_id  integer    references products(id),
  quantity    integer    not null

);
</code>




