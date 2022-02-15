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
	curr_user_id bigint;
begin
	select last_value from user_id_seq into curr_user_id;
	if curr_user_id = 1 then
		perform nextval('user_id_seq');
	end if;
    with ins as (
        insert into "user" (USERNAME, PASSW_HASH, USER_PHOTO)
        select md5(cast(currval('user_id_seq') as text)), md5(i::text), null
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
begin
	perform generate_user_roles('AGENT', generate_user($1));
	perform generate_user_roles('ALIEN', generate_user($2));
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION generate_planets(PlanetNum int) RETURNS int[] AS
$$
declare
    generated_planets_ids int[];
begin
	perform nextval('planet_id_seq');
    with ins as (
        insert into planet(name, race)
        select md5(cast(currval('planet_id_seq') as text)), md5(i::text)
        from generate_series(1, $1) s(i) returning id
    )
    select array_agg(id) into generated_planets_ids from ins;
    return generated_planets_ids;
end;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION generate_skills(SkillNum int) RETURNS int[] AS
$$
declare
    generated_skills_ids int[];
begin
    perform nextval('skill_id_seq');
    with ins as (
        insert into skill(name)
        select md5(cast(currval('skill_id_seq') as text))
        from generate_series(1, $1) s(i) returning id
    )
    select array_agg(id) into generated_skills_ids from ins;
    return generated_skills_ids;
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION generate_professions(ProfessionsNum int) RETURNS int[] AS
$$
declare
    generated_professions_ids int[];
begin
    perform nextval('profession_id_seq');
    with ins as (
        insert into profession(name)
        select md5(cast(currval('profession_id_seq') as text))
        from generate_series(1, $1) s(i) returning id
    )
    select array_agg(id) into generated_professions_ids from ins;
    return generated_professions_ids;
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION generate_skill_in_profession(SkillsIds int[], ProfessionsIds int[]) RETURNS VOID AS
$$
declare
    skills_num int;
    professions_num int;
begin
    professions_num = array_length(ProfessionsIds, 1);
    select array_length(SkillsIds, 1) into skills_num;

    -- каждую профессию связываем с i скиллами
    for i in 1..professions_num
        loop
            for j in 1..i % skills_num
                loop
                    insert into skill_in_profession(profession_id, skill_id)
                    values(ProfessionsIds[i], SkillsIds[j]);
                end loop;
        end loop;
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_skills_and_professions(SkillsNum int, ProfessionsNum int) RETURNS VOID AS
$$
begin
	perform generate_skill_in_profession(generate_skills(SkillsNum), generate_professions(ProfessionsNum));
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION generate_locations(LocationsNnum int) RETURNS int[] AS
$$
declare
    generated_ids int[];
begin
    perform nextval('location_id_seq');
    with ins as (
        insert into location(city, country)
        select md5(cast(currval('location_id_seq') as text)), md5(cast(currval('location_id_seq') as text))
        from generate_series(1, $1) s(i) returning id
    )
    select array_agg(id) into generated_ids from ins;
    return generated_ids;
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION
generate_alien_personality(PersonalityNum int)
RETURNS int[] AS
$$
declare
    generated_ids int[];
    professions_ids int[] := ARRAY(select id from profession);
    locations_ids int[] := ARRAY(select id from location);
begin
    with ins as (
        insert into alien_personality(first_name, second_name,
        age, profession_id, location_id, person_photo)
        select 'Ivan', 'Ivanov', 25, professions_ids[1+floor(random()*array_length(professions_ids, 1))::int],
         locations_ids[1+floor(random()*array_length(locations_ids, 1))::int], E'\\xDEADBEEF'
        from generate_series(1, $1) s(i) returning id
    )
    select array_agg(id) into generated_ids from ins;
    return generated_ids;
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_alien_form(AlienFormsNum int) RETURNS int[] AS
$$
declare
    generated_ids int[];
    planets_ids int[] := ARRAY(select id from planet);;
    user_ids int[] := ARRAY(select ur.user_id from user_roles ur join role r on r.id = ur.role_id where r.name = 'ALIEN');
begin
    with ins as (
        insert into alien_form(user_id, planet_id, visit_purpose, stay_time, comment)
        select user_ids[1+floor(random()*array_length(user_ids, 1))::int],
        planets_ids[1+floor(random()*array_length(planets_ids, 1))::int], md5(i::text), floor(random()*500+1)::int,
        md5(md5(i::text))
        from generate_series(1, $1) s(i) returning id
    )
    select array_agg(id) into generated_ids from ins;
    return generated_ids;
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION generate_skill_in_alien_form(AlienFormsIds int[])
 RETURNS VOID AS
$$
declare
    skills_ids int[] := ARRAY(select id from skill);
    skills_num int := array_length(skills_ids, 1);
    forms_num int := array_length(AlienFormsIds, 1);
begin
    for i in 1..forms_num
        loop
            for j in 1..(i % skills_num+1)
                loop
                    insert into skill_in_alien_form(alien_form_id, skill_id)
                    values(AlienFormsIds[i], skills_ids[j]);
                end loop;
        end loop;
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_alien_forms_connect_skills(AlienForms int)
 RETURNS VOID AS
$$
begin
	perform generate_skill_in_alien_form(generate_alien_form(10));
end;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION generate_agent_info() RETURNS VOID AS
$$
declare
    agents_ids int[] := ARRAY(select ur.user_id from user_roles ur join role r on ur.role_id = r.id where r.name = 'AGENT');
    agents int := array_length(agents_ids, 1);
    agents_nicks char[] = '{A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z}';
    c int = 1;
    curr_letter int = 1;
    curr_nick varchar(64) = '';
begin
    for i in 1..agents
    loop
        -- если закончились ники следующие делаем с +1 буквой
        if c = array_length(agents_nicks, 1) then c:= c + 1;
        end if;

        -- для каждой буквы
        for j in 1..c
        loop
            curr_nick := curr_nick || agents_nicks[curr_letter];
            -- след буква будет другой
            curr_letter := curr_letter + 1;
        end loop;

        insert into agent_info(user_id, nickname, is_alive) values (agents_ids[i], curr_nick, true),
                                                                   (agents_ids[i], curr_nick, false); -- умершие агенты
        curr_nick := '';
    end loop;
end;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_alien_forms_connect_skills(AlienForms int)
 RETURNS VOID AS
$$
begin
	perform generate_skill_in_alien_form(generate_alien_form(10));
end;
$$ LANGUAGE plpgsql;

-- TODO короче я не знаю потом
-- CREATE OR REPLACE FUNCTION alien_info() RETURNS VOID AS
-- $$
-- declare
--     aliens_ids int[];
--     aliens int;
--     alien_not_on_earth_id int;
-- begin
--     aliens_ids := ARRAY(select ur.user_id from user_roles ur join role r on ur.role_id = r.id where r.name = 'ALIEN');
--     aliens := array_length(aliens_ids, 1);
--     alien_not_on_earth_id := (select id from alien_status where name = 'NOT ON EARTH');
--     for i in 1..aliens
--     loop
--         insert into alien_info(departure_date, alien_status_id, user_id, personality_id)
--         values (null, alien_not_on_earth_id, aliens_ids[i],  ????????) ;
--     end loop;
-- end;
-- $$ LANGUAGE plpgsql;


-- create table alien_info
-- (
--     id              serial primary key,
--     departure_date  date,
--     alien_status_id integer references alien_status (id) on delete set null,
--     user_id         integer references "user" (id) on delete cascade,
--     personality_id  integer references alien_personality (id) on delete set null
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
