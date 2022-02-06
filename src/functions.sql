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
    return query select ai.id, first_name, second_name, age, p.name, l.city, l.country
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
    return query select request.id, username, request_type.name, request_status.name, create_date, alien_form_id
                 from request
                          join "user" on request.creator_id = "user".id
                          join request_type on request.type_id = request_type.id
                          join request_status on request.status_id = request_status.id
                 where executor_id = (select user_id from agent_info where id = agent_id);
end;
$$ language plpgsql;

-- Функция для получения всех пользователей с ролью role
create or replace function get_requests_by_agent_id(role varchar(32))
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

