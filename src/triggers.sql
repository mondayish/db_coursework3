-- Триггер для проверки того, что агент живой, когда добавляется слежка
create or replace function check_tracking_agent_is_alive() returns trigger as $$
declare
    agent_is_alive boolean := (select is_alive from agent_info where user_id = new.agent_info_id);
begin
    if not agent_is_alive then
        raise exception 'agent for tracking must be alive';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_tracking_agent_is_alive before insert on agent_alien
    for each row execute procedure check_tracking_agent_is_alive();


-- Триггер для проверки того, что агент живой, когда добавляется заявка
create or replace function check_creator_executor_is_alive() returns trigger as $$
declare
    creator_is_alive boolean := (select true from agent_info where user_id = new.creator_id and is_alive);
    executor_is_alive boolean := (select is_alive from agent_info where user_id = new.executor_id and is_alive);
begin
    if creator_is_alive is not null and not creator_is_alive then
        raise exception 'creator must be alive';
    end if;
    if executor_is_alive is not null and not executor_is_alive then
        raise exception 'executor must be alive';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_creator_executor_is_alive before insert or update on request
    for each row execute procedure check_creator_executor_is_alive();


-- Триггер для проверок ролей пользователей при проставлении CREATOR_ID и EXECUTOR_ID в заявках
create or replace function check_creator_executor_roles() returns trigger as $$
declare
    visit_status_id integer := (select id from request_status where name = 'VISIT');
    agent_role_id integer := (select id from role where name = 'AGENT');
    alien_role_id integer := (select id from role where name = 'ALIEN');
begin
    if new.status_id = visit_status_id and not (
            exists(select 1 from user_roles where user_id = new.creator_id and role_id = alien_role_id) and
            exists(select 1 from user_roles where user_id = new.executor_id and role_id = agent_role_id)) then
        raise exception 'request with status "VISIT" must create user with role "ALIEN" and execute user with role "AGENT"';
    end if;
    if new.status_id != visit_status_id and not (
            exists(select 1 from user_roles where user_id = new.creator_id and role_id = agent_role_id) and
            exists(select 1 from user_roles where user_id = new.executor_id and role_id = agent_role_id)) then
        raise exception 'request with statuses "WARNING", "NEUTRALIZATION", "DEPORTATION" must create and execute user with role "AGENT"';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_creator_executor_roles before insert or update on request
    for each row execute procedure check_creator_executor_roles();


-- Проверка, что USER_ID - пользователь с ролью “Агент”?
create or replace function check_agent_role() returns trigger as $$
declare
    agent_role_id integer := (select id from role where name = 'AGENT');
begin
    if not exists(select 1 from user_roles where user_id = new.user_id and role_id = agent_role_id) then
        raise exception 'user must have role "AGENT"';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_agent_role before insert or update on agent_info
    for each row execute procedure check_agent_role();


-- Проверка, что USER_ID - пользователь с ролью “Пришелец”?
create or replace function check_alien_role() returns trigger as $$
declare
    alien_role_id integer := (select id from role where name = 'ALIEN');
begin
    if not exists(select 1 from user_roles where user_id = new.user_id and role_id = alien_role_id) then
        raise exception 'user must have role "ALIEN"';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_alien_role before insert or update on alien_info
    for each row execute procedure check_alien_role();
create trigger check_alien_role before insert or update on alien_form
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
    if status = 'ON EARTH' then
        new.departure_date = current_date + stay_time;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger set_departure_date after update on alien_info
    for each row execute procedure set_departure_date();


-- Триггер для проверки дублей в alien_form если заявка еще на рассмотрении
create or replace function check_pending_form_duplicates() returns trigger as $$
declare
    pending_status_id integer := (select id from request_status where name = 'PENDING');
    visit_type_id integer := (select id from request_type where name = 'VISIT');
begin
    if exists(select 1 from request where creator_id = new.user_id and status_id = pending_status_id and type_id = visit_type_id) then
        raise exception 'cannot insert new alien_form if there is pending request exists';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_pending_form_duplicates before insert on alien_form
    for each row execute procedure check_pending_form_duplicates();


-- Триггер для проверки дублирования имен живых агентов
create or replace function check_alive_nickname_duplicates() returns trigger as $$
begin
    if exists(select 1 from agent_info where nickname = new.nickname and is_alive and new.is_alive) then
        raise exception 'alive agent with the same nickname already exists';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_alive_nickname_duplicates before insert or update on agent_info
    for each row execute procedure check_alive_nickname_duplicates();


-- Триггер для проверки того, что тип заявки и статус пришельца совместимы
create or replace function check_request_type_alien_status() returns trigger as $$
declare
    visit_type_id integer := (select id from request_status where name = 'VISIT');
    on_earth_st_id integer := (select id from alien_status where name = 'ON EARTH');
    not_on_earth_st_id integer := (select id from alien_status where name = 'NOT ON EARTH');
    st_id integer := (select alien_status_id from alien_info
                        where user_id = (select user_id from alien_form where id = new.alien_form_id));
begin
    if new.type_id = visit_type_id and st_id != not_on_earth_st_id then
        raise exception 'request with type "VISIT" can be created only for alien with status "NOT ON EARTH"';
    end if;
    if new.type_id != visit_type_id and st_id != on_earth_st_id then
        raise exception 'request with type "WARNING", "NEUTRALIZATION", "DEPORTATION" can be created only for alien with status "ON EARTH"';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_request_type_alien_status before insert or update on request
    for each row execute procedure check_request_type_alien_status();


-- Триггер для проверки того, что пришелец подает заявку на визит для себя
create or replace function check_request_alien_form() returns trigger as $$
declare
    visit_type_id integer := (select id from request_status where name = 'VISIT');
    alien_form_user_id integer := (select user_id from alien_form where id = new.alien_form_id);
begin
    if new.type_id = visit_type_id and new.creator_id != alien_form_user_id then
        raise exception 'creator_id in request with type "VISIT" must be = user_id in alien_form';
    end if;
    return new;
end;
$$ language plpgsql;

create trigger check_request_alien_form before insert or update on request
    for each row execute procedure check_request_alien_form();