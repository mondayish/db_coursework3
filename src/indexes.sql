-- Позволяет оптимизировать выборку личной информации пришельца по его идентификатору пользователя,
-- которая используется в функциях
create index alien_info_user_id on alien_info using hash(user_id);

-- Позволяет оптимизировать выборку запросов для конкретного агента
create index request_executor_id on request using hash(executor_id);

-- Позволяет оптимизировать выборку пришельцев, за которыми следит агент
create index agent_alien_agent_info_id on agent_alien using hash(agent_info_id);