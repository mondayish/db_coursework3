-- Функция получения всех пришельцев, за которыми следит данный агент
create or replace function get_tracking_aliens_by_agent_id(agent_id integer)
    returns table (
                      alien_info_id integer,
                      first_name    varchar(64),
                      second_name   varchar(64),
                      age           integer,
                      profession varchar(64),
                      city varchar(64),
                      country varchar(64)
                  ) as $$
begin
    return query select alien_info.id, first_name, second_name, age, profession.name, location.city, location.country from alien_personality
        inner join profession on alien_personality.profession_id = profession.id
        inner join location on alien_personality.location_id = location.id
        inner join alien_info on alien_personality.id = alien_info.personality_id
    where alien_personality.id in
          (select personality_id from agent_alien inner join alien_info on agent_alien.alien_info_id = alien_info.id
          where agent_info_id = agent_id and start_date <= current_date and (end_date is null or end_date >= current_date));
end;
$$ language plpgsql;

-- Функция получения всех заявок, которые надо обработать данному агенту
create or replace function get_requests_by_agent_id(agent_id integer)
    returns table (
                      request_id integer,
                      creator    varchar(64),
                      request_type varchar(64),
                      request_status varchar(64),
                      create_date timestamp,
                      alien_form_id integer
                  ) as $$
begin
    return query select request.id, username, request_type.name, request_status.name, create_date, alien_form_id from request
        inner join "user" on request.creator_id = "user".id
        inner join request_type on request.type_id = request_type.id
        inner join request_status on request.status_id = request_status.id
    where executor_id = (select user_id from agent_info where id = agent_id);
end;
$$ language plpgsql;