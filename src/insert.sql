insert into request_type values (1, 'VISIT'),
                                (2, 'WARNING'),
                                (3, 'NEUTRALIZATION'),
                                (4, 'DEPORTATION');

insert into request_status values (1, 'PENDING'),
                                  (2, 'APPROVED'),
                                  (3, 'REJECTED');

insert into alien_status values (1, 'NOT ON EARTH'),
                                (2, 'ON EARTH'),
                                (3, 'DEPORTED'),
                                (4, 'NEUTRALIZED');

insert into role values (1, 'AGENT'),
                        (2, 'ALIEN');



CREATE OR REPLACE FUNCTION generate_user(UserNum int) RETURNS int[] AS
$$
declare 
    generated_users_ids int[];
begin
    with ins as (
        insert into "user" (USERNAME, PASSW_HASH, USER_PHOTO, AT_EARTH)
        select md5(cast(nextval('user_id_seq') as text)), md5(i::text), null, TRUE
        from generate_series(1, $1) s(i) returning id
    ) 
    select array_agg(id) into generated_users_ids from ins;
    return generated_users_ids;
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_user_roles(RoleStr varchar(32), UsersIds int[]) RETURNS VOID AS
$$
declare role_id int;
begin
	select id from role where name=RoleStr into role_id;
    for i in 1..array_length(UsersIds, 1)
        loop
            insert into user_roles(user_id, role_id) values(UsersIds[i], role_id);
        end loop;
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION generate_aliens_and_agents(AliensNum int, AgentsNum int) RETURNS VOID AS
$$
declare
	agents_ids int[];
	aliens_ids int[];
begin
	select generate_user($1) into agents_ids; 
	perform generate_user_roles('AGENT', agents_ids);
	perform generate_user_roles('ALIEN', generate_user($2));
end;
$$ LANGUAGE plpgsql;

-- GENERATE 
select generate_aliens_and_agents(10, 10);



-- create table planet
-- (
--     id   serial primary key,
--     --- added unique
--     name varchar(64) not null unique,
--     race varchar(64)
-- );

-- create table skill
-- (
--     id   serial primary key,
--     name varchar(32) not null unique
-- );

-- create table profession
-- (
--     id   serial primary key,
--     name varchar(64) not null unique
-- );

-- create table skill_in_profession
-- (
--     id            serial primary key,
--     profession_id integer references profession (id) on delete cascade,
--     skill_id      integer references skill (id) on delete cascade
-- );

-- create table location
-- (
--     id      serial primary key,
--     city    varchar(64) not null,
--     country varchar(64) not null,
--     unique (city, country)
-- );

-- create table alien_status
-- (
--     id   serial primary key,
--     name varchar(32) not null unique
-- );

-- create table alien_personality
-- (
--     id            serial primary key,
--     first_name    varchar(64) not null,
--     second_name   varchar(64),
--     age           integer     not null check (age >= 0),
--     profession_id integer     references profession (id) on delete set null,
--     location_id   integer     references location (id) on delete set null,
--     person_photo  bytea       not null
-- );

-- create table alien_form
-- (
--     id            serial primary key,
--     user_id       integer references "user" (id) on delete cascade,
--     planet_id     integer     references planet (id) on delete set null,
--     visit_purpose varchar(64) not null,
--     stay_time     integer     not null,
--     comment       text
-- );

-- create table skill_in_alien_form
-- (
--     id            serial primary key,
--     alien_form_id integer references alien_form (id) on delete cascade,
--     skill_id      integer references skill (id) on delete cascade
-- );

-- create table request
-- (
--     id            serial primary key,
--     creator_id    integer references "user" (id) on delete set null,
--     executor_id   integer references "user" (id) on delete set null,
--     type_id       integer references request_type (id) on delete set null,
--     status_id     integer references request_status (id) on delete set null,
--     create_date   timestamp check ( create_date <= current_timestamp ),
--     alien_form_id integer references alien_form (id) on delete cascade
-- );

-- create table agent_info
-- (
--     id       serial primary key,
--     user_id  integer references "user" (id) on delete cascade,
--     nickname varchar(64) not null,
--     is_alive boolean     not null,
--     unique (nickname, is_alive)
-- );

-- create table alien_info
-- (
--     id              serial primary key,
--     departure_date  date,
--     alien_status_id integer references alien_status (id) on delete set null,
--     user_id         integer references "user" (id) on delete cascade,
--     personality_id  integer references alien_personality (id) on delete set null
-- );

-- create table warning
-- (
--     id           serial primary key,
--     alien_id     integer references alien_info (id) on delete cascade,
--     name         varchar(64) not null,
--     description  text,
--     warning_date date
-- );

-- create table agent_alien
-- (
--     id            serial primary key,
--     alien_info_id integer references alien_info (id) on delete cascade,
--     agent_info_id integer references agent_info (id) on delete cascade,
--     start_date    date not null default current_date,
--     end_date      date
-- );

-- create table tracking_report
-- (
--     id             serial primary key,
--     report_date    date    not null default current_date,
--     behavior       integer not null check ( behavior >= 0 and behavior <= 10 ),
--     description    text,
--     agent_alien_id integer references agent_alien (id) on delete cascade
-- );