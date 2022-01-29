-- todo идеи для триггеров
-- Триггер для проверки того, что агент живой, когда добавляется слежка или запрос для него
-- Триггеры для проверок ролей пользователей при проставлении CREATOR_ID и EXECUTOR_ID в заявках
-- Триггер для добавления роли при добавлении строк в таблицы ALIEN_FORM, ALIEN_INFO, AGENT_INFO?
-- Проверка, что USER_ID - пользователь с ролью “пришелец”?

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
    -- todo я забыл в днях или в чем
    stay_time integer := (select stay_time from alien_form where user_id = new.user_alien_id);
begin
    if status == 'На Земле' then
        new.departure_date = current_date + stay_time;
    end if;
    return new;
end;
$$ language plpgsql;

create trigger set_departure_date after update on alien_info
    for each row execute procedure set_departure_date();