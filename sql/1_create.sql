BEGIN;

CREATE ROLE postgraphql login password 'MAvpHSpoKqsxU5lp6v9y';
COMMENT ON ROLE postgraphql IS 'Группа для подключения postgraphql';

CREATE ROLE anonymous;
COMMENT ON ROLE anonymous IS 'Группа доступа неавторизованных пользователей';
grant anonymous to postgraphql;

CREATE ROLE authorized;
COMMENT ON ROLE authorized IS 'Группа доступа пользователей';
grant authorized to postgraphql;

CREATE ROLE admin;
COMMENT ON ROLE admin IS 'Группа доступа администраторов';
grant admin to postgraphql;
DROP SCHEMA IF EXISTS public CASCADE; -- не нужна

CREATE SCHEMA main;
COMMENT ON SCHEMA main IS 'Основная схема базы данных';
GRANT usage ON SCHEMA main TO anonymous, authorized, admin;

CREATE SCHEMA service;
COMMENT ON SCHEMA service IS 'Служебная схема';
GRANT usage ON SCHEMA service TO admin;

ALTER DATABASE linkhub SET search_path TO main;
SET search_path TO main;
-- для расширений используется схема service чтобы не было видно горы функций в интерфейсе graphql

-- хэширование паролей
CREATE EXTENSION IF NOT EXISTS "pgcrypto" SCHEMA service;
CREATE TYPE jwt_token AS (
  role TEXT,
  person_id INTEGER
);
COMMENT ON TYPE jwt_token IS 'Тип для токена';
CREATE TYPE role AS ENUM (
  'anonymous',
  'authorized',
  'admin'
);
COMMENT ON TYPE role IS 'Возможные группы доступа';
CREATE TYPE test_result AS (
  question_id INTEGER,
  test_id INTEGER,
  parameter TEXT,
  expectation TEXT,
  reality TEXT
);
COMMENT ON TYPE test_result IS 'Тип результата прогонки теста';
CREATE TABLE account (
  person_id         INTEGER PRIMARY KEY,
  login             TEXT NOT NULL UNIQUE CHECK (login ~* '^[a-z]+[a-z0-9]*$' AND char_length(login)<51),
  password_hash     TEXT NOT NULL,
  role              role NOT NULL,
  email             TEXT UNIQUE CHECK (email ~* '^.+@.+\..+$'),
  telegram_id       TEXT UNIQUE
);

COMMENT ON TABLE account IS 'Аккаунт пользователя';
COMMENT ON COLUMN account.person_id IS 'ИД пользователя аккаунта';
COMMENT ON COLUMN account.login IS 'Логин. Должен начинаться с латинской буквы, остальные символы могут бвть буквами или цифрами';
COMMENT ON COLUMN account.password_hash IS 'Хэш пароля аккаунта';
COMMENT ON COLUMN account.role IS 'Группа доступа аккаунта';
COMMENT ON COLUMN account.email IS 'Email аккаунта. Проверяется на корректность';
CREATE TABLE link (
  id          SERIAL PRIMARY KEY,
  title       TEXT NOT NULL,
  way         TEXT NOT NULL,
  person_id   INTEGER NOT NULL,
  created_at  TIMESTAMP DEFAULT now(),
  preview     TEXT,
  image_url   TEXT
);

COMMENT ON TABLE link IS 'Ссылка';
COMMENT ON COLUMN link.id IS 'ИД';
COMMENT ON COLUMN link.title IS 'Заголовок';
COMMENT ON COLUMN link.way IS 'Путь';
COMMENT ON COLUMN link.person_id IS 'Ид создателя';
COMMENT ON COLUMN link.created_at IS 'Время создания';
COMMENT ON COLUMN link.preview IS 'Описание ссылки для превью';
COMMENT ON COLUMN link.image_url IS 'Ссылка на картинку ссылки';

GRANT SELECT ON TABLE link TO anonymous, authorized, admin;
GRANT INSERT, UPDATE, DELETE ON TABLE link TO authorized, admin;

ALTER TABLE link ENABLE ROW LEVEL SECURITY;
CREATE POLICY all_link_as_admin ON link FOR ALL TO admin
  USING (TRUE);
CREATE POLICY select_link_as_authorized ON link FOR SELECT TO authorized
  USING (TRUE);
CREATE POLICY select_link_as_anonymous ON link FOR SELECT TO anonymous
  USING (TRUE);
CREATE POLICY insert_link_as_authorized ON link FOR INSERT TO authorized
  WITH CHECK (person_id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY update_link_as_authorized ON link FOR UPDATE TO authorized
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY delete_link_as_authorized ON link FOR DELETE TO authorized
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);

----------------------------------------
CREATE INDEX link_fts_idx ON link USING GIN (to_tsvector('russian', title || ' ' || preview));

----------------------------------------
CREATE FUNCTION search_link(search TEXT) RETURNS SETOF link AS $$
  SELECT *
  FROM link
  WHERE  search = '' or to_tsvector('russian', title || ' ' || COALESCE(preview, '')) @@ plainto_tsquery('russian', search)
$$ LANGUAGE SQL STABLE;



COMMENT ON FUNCTION search_link(TEXT) IS 'Поиск по заголовку и превью ссылки';
GRANT EXECUTE ON FUNCTION search_link(TEXT) TO anonymous, authorized, admin;

CREATE TABLE link_tag (
  link_id  INTEGER NOT NULL,
  tag_id   INTEGER NOT NULL,
  PRIMARY KEY (link_id, tag_id)
);

COMMENT ON TABLE link_tag IS 'Тэг';
COMMENT ON COLUMN link_tag.link_id IS 'ИД ссылки';
COMMENT ON COLUMN link_tag.tag_id IS 'ИД тэга';

GRANT SELECT ON TABLE link_tag TO anonymous, authorized, admin;
GRANT INSERT, UPDATE, DELETE ON TABLE link_tag TO authorized, admin;

ALTER TABLE link_tag ENABLE ROW LEVEL SECURITY;
CREATE POLICY all_link_tag_as_admin ON link_tag FOR ALL TO admin
  USING (TRUE);
CREATE POLICY select_link_tag_as_authorized ON link_tag FOR SELECT TO authorized
  USING (TRUE);
CREATE POLICY select_link_tag_as_anonymous ON link_tag FOR SELECT TO anonymous
  USING (TRUE);
CREATE POLICY insert_link_tag_as_authorized ON link_tag FOR INSERT TO authorized
  WITH CHECK (link_id IN (SELECT id FROM link WHERE person_id = 
  current_setting('jwt.claims.person_id')::INTEGER));
CREATE POLICY update_link_tag_as_authorized ON link_tag FOR UPDATE TO authorized
  USING (link_id IN (SELECT id FROM link WHERE person_id = 
  current_setting('jwt.claims.person_id')::INTEGER));
CREATE POLICY delete_link_tag_as_authorized ON link_tag FOR DELETE TO authorized
  USING (link_id IN (SELECT id FROM link WHERE person_id = 
  current_setting('jwt.claims.person_id')::INTEGER));
CREATE TABLE person (
  id               SERIAL PRIMARY KEY,
  first_name       VARCHAR(50) NOT NULL,
  last_name        VARCHAR(50),
  patronymic       VARCHAR(50),
  date_of_birth    TIMESTAMP,
  about            TEXT,
  created_at       TIMESTAMP DEFAULT now()
);

COMMENT ON TABLE person IS 'Физлицо';
COMMENT ON COLUMN person.id IS 'Уникальный идентификатор физлица';
COMMENT ON COLUMN person.first_name IS 'Фамилия физлица';
COMMENT ON COLUMN person.last_name IS 'Имя физлица';
COMMENT ON COLUMN person.patronymic IS 'Отчество физлица';
COMMENT ON COLUMN person.date_of_birth IS 'Дата рождения физлица';
COMMENT ON COLUMN person.about IS 'Краткое описание физлица (о себе)';
COMMENT ON COLUMN person.created_at IS 'Время создания физлица';

GRANT SELECT ON TABLE person TO anonymous, authorized, admin;
GRANT UPDATE, DELETE ON TABLE person TO authorized, admin;

CREATE FUNCTION search_link_tag(search_id INTEGER, search TEXT) RETURNS SETOF link AS $$
  SELECT * from search_link(search) 
  WHERE id in (select link_id from link_tag where tag_id = search_id)
$$ LANGUAGE SQL STABLE;

----------------------------------------
CREATE FUNCTION person_full_name(person person) RETURNS TEXT AS $$
  SELECT COALESCE(person.first_name, '') || ' ' || COALESCE(person.last_name,'')
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION person_full_name(person) IS 'Полное имя пользователя = Фамилия + Имя';
GRANT EXECUTE ON FUNCTION person_full_name(person) TO anonymous, authorized, admin;

CREATE TABLE rating (
  link_id     INTEGER NOT NULL,
  person_id   INTEGER NOT NULL,
  positive    BOOLEAN NOT NULL,
  created_at  TIMESTAMP DEFAULT now(),
  PRIMARY KEY (link_id, person_id)
);

COMMENT ON TABLE rating IS 'Лайк';
COMMENT ON COLUMN rating.link_id IS 'ИД ссылки';
COMMENT ON COLUMN rating.person_id IS 'ИД лайкнувшего';
COMMENT ON COLUMN rating.positive IS 'Это лайк';
COMMENT ON COLUMN rating.created_at IS 'Время лайка/дизлайка';

GRANT SELECT ON TABLE rating TO anonymous, authorized, admin;
GRANT INSERT, UPDATE, DELETE ON TABLE rating TO authorized, admin;

ALTER TABLE rating ENABLE ROW LEVEL SECURITY;
CREATE POLICY all_rating_as_admin ON rating FOR ALL TO admin
  USING (TRUE);
CREATE POLICY select_rating_as_authorized ON rating FOR SELECT TO authorized
  USING (TRUE);
CREATE POLICY select_rating_as_anonymous ON rating FOR SELECT TO anonymous
  USING (TRUE);
CREATE POLICY insert_rating_as_authorized ON rating FOR INSERT TO authorized
  WITH CHECK (person_id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY update_rating_as_authorized ON rating FOR UPDATE TO authorized
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);
CREATE POLICY delete_rating_as_authorized ON rating FOR DELETE TO authorized
  USING (person_id = current_setting('jwt.claims.person_id')::INTEGER);


CREATE TABLE tag (
  id    SERIAL PRIMARY KEY,
  name  TEXT NOT NULL
);

COMMENT ON TABLE tag IS 'Тэг';
COMMENT ON COLUMN tag.id IS 'ИД';
COMMENT ON COLUMN tag.name IS 'Имя';

GRANT SELECT ON TABLE tag TO anonymous, authorized;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE tag TO admin;
CREATE TABLE word_n_tag (
  word    TEXT PRIMARY KEY,
  tag_id  INTEGER NOT NULL
);

COMMENT ON TABLE word_n_tag IS 'Связь тегов со словами';
COMMENT ON COLUMN word_n_tag.word IS 'Слово';
COMMENT ON COLUMN word_n_tag.tag_id IS 'ИД тэга';

GRANT SELECT ON TABLE word_n_tag TO anonymous, authorized, admin;
GRANT INSERT ON TABLE word_n_tag TO authorized, admin;
GRANT UPDATE, DELETE ON TABLE word_n_tag TO admin;
ALTER TABLE account
  ADD CONSTRAINT account_person_id_fkey FOREIGN KEY (person_id)
      REFERENCES person (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE;

ALTER TABLE link
  ADD CONSTRAINT link_person_id_fkey FOREIGN KEY (person_id)
      REFERENCES person (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE;

ALTER TABLE link_tag
  ADD CONSTRAINT link_tag_link_id_fkey FOREIGN KEY (link_id)
      REFERENCES link (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE;

ALTER TABLE link_tag
  ADD CONSTRAINT link_tag_tag_id_fkey FOREIGN KEY (tag_id)
      REFERENCES tag (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE;
ALTER TABLE rating
  ADD CONSTRAINT rating_link_id_fkey FOREIGN KEY (link_id)
      REFERENCES link (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE;

ALTER TABLE rating
  ADD CONSTRAINT rating_person_id_fkey FOREIGN KEY (person_id)
      REFERENCES person (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE;
ALTER TABLE word_n_tag
  ADD CONSTRAINT word_n_tag_tag_id_fkey FOREIGN KEY (tag_id)
      REFERENCES tag (id) MATCH SIMPLE
      ON UPDATE NO ACTION ON DELETE CASCADE;

CREATE FUNCTION authenticate(
  login TEXT,
  password TEXT
) RETURNS jwt_token AS $$
DECLARE
  account account;
BEGIN
  SELECT a.* INTO account
  FROM account as a
  where a.login = authenticate.login;

  IF account.password_hash = service.crypt(password, account.password_hash) THEN
    PERFORM set_config('jwt.claims.person_id', account.person_id::text, true);
    RETURN (account.role, account.person_id)::jwt_token;
  ELSE
    RETURN NULL;
  END IF;
END;
$$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

COMMENT ON FUNCTION authenticate(TEXT, TEXT)
  IS 'Создает JWT - токен, который будет использоваться для идентификации пользователя';
GRANT EXECUTE ON FUNCTION authenticate(TEXT, TEXT) TO 
  anonymous, authorized, admin;
CREATE FUNCTION current_person() RETURNS person AS $$
  SELECT *
  FROM person
  WHERE id = current_setting('jwt.claims.person_id')::INTEGER
$$ LANGUAGE SQL STABLE;

COMMENT ON FUNCTION current_person() is 'Получение данных текущего пользователя';
GRANT EXECUTE ON FUNCTION current_person() TO anonymous, authorized, admin;
CREATE OR REPLACE FUNCTION current_person_id_telegram(telegram_id text)
 RETURNS integer
 LANGUAGE plpgsql
 STRICT SECURITY DEFINER
AS $function$
DECLARE
  pid integer;
BEGIN
	SELECT person_id INTO pid FROM account WHERE account.telegram_id = current_person_id_telegram.telegram_id;
	IF FOUND THEN
	    return pid;
	else
		return 0;
	END IF;
END;
$function$;
CREATE OR REPLACE FUNCTION is_user_telegram(telegram_id text)
 RETURNS boolean
 LANGUAGE plpgsql
 STRICT SECURITY DEFINER
AS $function$
DECLARE
  acc account;
BEGIN
	SELECT * INTO acc FROM account WHERE account.telegram_id = is_user_telegram.telegram_id;
	IF NOT FOUND THEN
	    return false;
	else
		return true;
	END IF;
END;
$function$;

COMMENT ON FUNCTION is_user_telegram(TEXT) IS 'Проверяет является ли пользователем телеграма по ид';


CREATE OR REPLACE FUNCTION login_is_awailable(login text)
 RETURNS boolean
 LANGUAGE plpgsql
 STRICT SECURITY DEFINER
AS $function$
DECLARE
  acc account;
BEGIN
	SELECT * INTO acc FROM account WHERE account.login = login_is_awailable.login;
	IF NOT FOUND THEN
	    RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END;
$function$;

COMMENT ON FUNCTION login_is_awailable(TEXT)
  IS 'Проверяет доступность логина';
GRANT EXECUTE ON FUNCTION login_is_awailable(TEXT) TO 
  anonymous, authorized, admin;
CREATE FUNCTION register(
  first_name TEXT,
  last_name TEXT,
  email TEXT,
  login TEXT,
  password TEXT
) RETURNS person AS $$
DECLARE
  person person;
BEGIN
  INSERT INTO person (first_name, last_name) VALUES (first_name, last_name)
    RETURNING * INTO person;
  INSERT INTO account (person_id, login, password_hash, role, email) VALUES
    (person.id, login, service.crypt(password, service.gen_salt('bf')), 'authorized', email);
  RETURN person;
END;
$$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

COMMENT ON FUNCTION register(TEXT, TEXT, TEXT, TEXT, TEXT) IS 'Регистрация пользователя';
GRANT EXECUTE ON FUNCTION register(TEXT, TEXT, TEXT, TEXT, TEXT) TO anonymous;
CREATE FUNCTION register_telegram(
  first_name TEXT,
  login TEXT,
  password TEXT,
  telegram_id TEXT
) RETURNS person AS $$
DECLARE
  person person;
BEGIN
  INSERT INTO person (first_name) VALUES (first_name)
    RETURNING * INTO person;
  INSERT INTO account (person_id, login, password_hash, role, telegram_id) VALUES
    (person.id, login, service.crypt(password, service.gen_salt('bf')), 'authorized', telegram_id);
  RETURN person;
END;
$$ LANGUAGE plpgsql STRICT SECURITY DEFINER;

COMMENT ON FUNCTION register_telegram(TEXT, TEXT, TEXT, TEXT) IS 'Регистрация пользователя через телеграм';
GRANT EXECUTE ON FUNCTION register_telegram(TEXT, TEXT, TEXT, TEXT) TO anonymous;
CREATE FUNCTION set_role(
  user_id INTEGER,
  role_name TEXT
) RETURNS BOOLEAN AS $$
BEGIN
  UPDATE account SET role = role_name WHERE person_id = user_id;
  RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION set_role(INTEGER, TEXT) is 'Установка пользователю новой роли.';
GRANT EXECUTE ON FUNCTION set_role(INTEGER, TEXT) TO admin;
-- set default value for person id to 0
ALTER DATABASE linkhub SET jwt.claims.person_id TO 0;

GRANT USAGE, SELECT, UPDATE 
  ON ALL SEQUENCES IN SCHEMA main
  TO authorized, admin;
COMMIT;