-- Функция получения всех пришельцев, за которыми следит данный агент
create or replace function get_tracking_aliens_by_agent_id(agent_id integer)
    returns table
            (
                alien_info_id integer,
                first_name    varchar(64),
                second_name   varchar(64),
                age           integer,
                profession    varchar(64),
                city          varchar(64),
                country       varchar(64)
            )
as
$$
begin
    return query select ai.id, ap.first_name, ap.second_name, ap.age, p.name, l.city, l.country
                 from alien_personality ap
                          join profession p on ap.profession_id = p.id
                          join location l on ap.location_id = l.id
                          join alien_info ai on ap.id = ai.personality_id
                 where ap.id in
                       (select personality_id
                        from agent_alien aa
                                 join alien_info ai on aa.alien_info_id = ai.id
                        where agent_info_id = agent_id
                          and start_date <= current_date
                          and (end_date is null or end_date >= current_date));
end;
$$ language plpgsql;


-- Функция получения всех заявок, которые надо обработать данному агенту
create or replace function get_requests_by_agent_id(agent_id integer)
    returns table
            (
                request_id     integer,
                creator        varchar(64),
                request_type   varchar(64),
                request_status varchar(64),
                create_date    timestamp,
                alien_form_id  integer
            )
as
$$
begin
    return query select r.id, u.username, rt.name, rs.name, r.create_date, r.alien_form_id
                 from request r
                          join "user" u on r.creator_id = u.id
                          join request_type rt on r.type_id = rt.id
                          join request_status rs on r.status_id = rs.id
                 where r.executor_id = (select user_id from agent_info where id = agent_id);
end;
$$ language plpgsql;


-- Функция для получения всех пользователей с ролью role
create or replace function get_all_users_with_role(role varchar(32))
    returns table
            (
                user_id  integer,
                username varchar(64)
            )
as
$$
begin
    return query select ur.user_id
                 from user_roles ur
                          join role r on ur.role_id = r.id
                 where r.name = role;
end;
$$ language plpgsql;


-- Функция для получения личной информации пришельца
create or replace function get_alien_info_by_user_id(uid integer)
    returns table
            (
                first_name    varchar(64),
                second_name   varchar(64),
                age           integer,
                profession    varchar(64),
                city          varchar(64),
                country       varchar(64),
                person_photo  bytea,
                departure_date date,
                alien_status varchar(32)
            )
as
$$
begin
    return query select ap.first_name, ap.second_name, ap.age, p.name, l.city, l.country, ap.person_photo, ai.departure_date, als.name
                 from alien_info ai
                     join alien_personality ap on ai.personality_id = ap.id
                     join profession p on ap.profession_id = p.id
                     join location l on ap.location_id = l.id
                     join alien_status als on ai.alien_status_id = als.id
    where ai.user_id = uid;
end;
$$ language plpgsql;


-- Функция для получения предупреждений для определенного пришельца
create or replace function get_warnings_by_user_id(uid integer)
    returns table
            (
                name         varchar(64),
                description  text,
                warning_date date
            )
as
$$
begin
    return query select name, description, warning_date
                 from warning where alien_id = (select id from alien_info where user_id = uid);
end;
$$ language plpgsql;
