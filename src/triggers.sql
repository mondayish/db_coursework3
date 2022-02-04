-- todo идеи для триггеров
-- Триггер для проверки того, что агент живой, когда добавляется слежка или запрос для него

-- Триггер для проверок ролей пользователей при проставлении CREATOR_ID и EXECUTOR_ID в заявках
create or replace function check_creator_executor_roles() returns trigger as $$
declare
    visit_status_id integer := (select id from request_status where name = 'Посещение Земли');
    agent_role_id integer := (select id from role where name = 'Агент');
    alien_role_id integer := (select id from role where name = 'Пришелец');
begin
    if not (new.status_id == visit_status_id and
            exists(select 1 from user_roles where user_id = new.creator_id and role_id = alien_role_id) and
            exists(select 1 from user_roles where user_id = new.executor_id and role_id = agent_role_id)) then
        raise exception 'request with status "Посещение Земли" must create user with role "Пришелец" and execute user with role "Агент"';
    end if;
    if not (new.status_id != visit_status_id and
            exists(select 1 from user_roles where user_id = new.creator_id and role_id = agent_role_id) and
            exists(select 1 from user_roles where user_id = new.executor_id and role_id = agent_role_id)) then
        raise exception 'request with statuses "Предупреждение", "Нейтрализация", "Депортация" must create user with role "Пришелец" and execute user with role "Агент"';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_creator_executor_roles before insert or update on request
    for each row execute procedure check_creator_executor_roles();


-- Проверка, что USER_ID - пользователь с ролью “Агент”?
create or replace function check_agent_role() returns trigger as $$
declare
    agent_role_id integer := (select id from role where name = 'Агент');
begin
    if not exists(select 1 from user_roles where user_id = new.user_id and role_id = agent_role_id) then
        raise exception 'user must have role "Агент"';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_agent_role before insert or update on agent_info
    for each row execute procedure check_agent_role();


-- Проверка, что USER_ID - пользователь с ролью “Пришелец”?
create or replace function check_alien_role() returns trigger as $$
declare
    alien_role_id integer := (select id from role where name = 'Пришелец');
begin
    if not exists(select 1 from user_roles where user_id = new.user_id and role_id = alien_role_id) then
        raise exception 'user must have role "Пришелец"';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_alien_role before insert or update on alien_info
    for each row execute procedure check_alien_role();
create trigger check_alien_role before insert or update on alien_info
    for each row execute procedure check_alien_role();


-- Триггер для проверки START_DATE <= END_DATE в таблице AGENT_ALIEN
create or replace function check_agent_alien_date() returns trigger as $$
begin
    if new.end_date is not null and new.start_date > new.end_date then
        raise exception 'start_date cannot be > end_date';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_agent_alien_date before insert or update on agent_alien
    for each row execute procedure check_agent_alien_date();


-- Триггер для проверки даты (REPORT_DATE <= END_DATE) в таблице TRACKING_REPORT
create or replace function check_report_date() returns trigger as $$
declare
    start_date date := (select start_date from agent_alien where id = new.agent_alien_id);
    end_date date := (select end_date from agent_alien where id = new.agent_alien_id);
begin
    if new.report_date < start_date or (end_date is not null and new.report_date > end_date) then
        raise exception 'report_date must be >= start_date and <= end_date';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_report_date before insert or update on tracking_report
    for each row execute procedure check_report_date();


-- Триггер выставления DEPARTURE_DATE, когда статус пришельца становится "На Земле"
create or replace function set_departure_date() returns trigger as $$
declare
    status varchar(32) := (select name from alien_status where alien_status.id = new.alien_status_id);
    stay_time integer := (select stay_time from alien_form where user_id = new.user_id);
begin
    if status == 'На Земле' then
        new.departure_date = current_date + stay_time;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger set_departure_date after update on alien_info
    for each row execute procedure set_departure_date();