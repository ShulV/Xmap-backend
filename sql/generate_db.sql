------------------------------------------------------------------------------------------------------------------------
-- Виды спотов (справочник)
drop table if exists spot_type cascade;
CREATE TABLE spot_type(
    id integer NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    "name" varchar(20) NOT NULL
);
-- заполнение справочника
INSERT INTO spot_type(name)
VALUES ('скейтпарк'),
       ('стрит'),
       ('дёрты'),
       ('вёрт'),
       ('bmx-рейсинг'),
       ('флэтленд');
------------------------------------------------------------------------------------------------------------------------
-- Виды спорта (справочник)
drop table if exists sport_type cascade;
CREATE TABLE sport_type(
                                   id integer NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                                   "name" varchar(20) NOT NULL,
                                   transport_name varchar(20) NOT NULL
);
-- заполнение справочника
INSERT INTO sport_type(name, transport_name)
VALUES ('bmx-фристайл', 'bmx'),
       ('скейтбординг', 'скейтборд'),
       ('самокат-фристайл', 'самокат'),
       ('горный велоспорт', 'MTB'),
       ('роллер-спорт', 'ролики'),
       ('лыжный спорт', 'лыжи'),
       ('сноубординг', 'сноуборд');
------------------------------------------------------------------------------------------------------------------------
-- Тип помещения как пространства для катания (справочник)
drop table if exists space_type cascade;
CREATE TABLE space_type(
                                   id integer NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                                   "name" varchar(20) NOT NULL
);
-- заполнение справочника
INSERT INTO space_type(name)
VALUES ('крытое помещение'),
       ('под навесом'),
       ('под открытым небом');


------------------------------------------------------------------------------------------------------------------------
-- Страны
drop table if exists country cascade;
CREATE TABLE country(
                                 id int NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                                 "name" varchar(128) NOT NULL
);

------------------------------------------------------------------------------------------------------------------------
-- Регионы
drop table if exists region cascade;
CREATE TABLE region(
                               id int NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                               country_id int not null REFERENCES country (id) ON UPDATE CASCADE ON DELETE SET NULL,
                               "name" varchar(128) NOT NULL
);

------------------------------------------------------------------------------------------------------------------------
-- Города
drop table if exists city cascade;
CREATE TABLE city(
                              id int NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                              region_id	int not null REFERENCES region (id) ON UPDATE CASCADE ON DELETE SET NULL,
                              "name" varchar(128) NOT NULL
);


------------------------------------------------------------------------------------------------------------------------
-- Пользователи
drop table if exists "user" cascade;
CREATE TABLE "user"(
                             id BIGINT NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                             "name" varchar(30) NOT NULL UNIQUE,
                             email varchar(50) NOT NULL UNIQUE,
                             pass_hash varchar(256) NOT NULL,
                             phone_number varchar(15) NOT NULL UNIQUE,
                             birthday date NOT NULL,
                             reg_date date NOT NULL,
                             role varchar(10) NOT NULL, -- хранятся в enum, размера на слово administrator хватит, если что - увеличим
                             city_id int REFERENCES city (id) ON UPDATE CASCADE ON DELETE SET NULL
);
------------------------------------------------------------------------------------------------------------------------
-- Токены (пока тут только BEARER для пользователя)
drop table if exists token cascade;
CREATE TABLE token(
                              id BIGINT NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                              value varchar(255) NOT NULL UNIQUE,
                              token_type varchar(255) NOT NULL,
                              user_id BIGINT NOT NULL REFERENCES "user" (id) ON UPDATE CASCADE ON DELETE CASCADE
);
------------------------------------------------------------------------------------------------------------------------
-- Споты
drop table if exists spot cascade;
CREATE TABLE spot(
                             id BIGINT NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                             "name" varchar(50) NOT NULL,
    -- latitude coordinate (координата широты)
                             lat FLOAT NOT NULL,
    -- longitude coordinate (координата долготы)
                             lon FLOAT NOT NULL,
                             accepted BOOLEAN NOT NULL DEFAULT FALSE,
                             adding_date date NOT NULL,
                             updating_date date,
                             description varchar(300) NOT NULL,
                             space_type_id int NOT NULL REFERENCES space_type (id)
                                 ON UPDATE CASCADE ON DELETE NO ACTION,
                             user_id BIGINT DEFAULT NULL REFERENCES "user" (id)
                                           ON UPDATE CASCADE ON DELETE SET NULL,
                             moder_id BIGINT DEFAULT NULL REFERENCES "user" (id)
                                           ON UPDATE CASCADE ON DELETE SET NULL,
                             city_id int REFERENCES city (id)
                                           ON UPDATE CASCADE ON DELETE SET NULL
);
------------------------------------------------------------------------------------------------------------------------
-- Информация об изображениях (спотов, пользователей, )
drop table if exists image_info cascade;
CREATE TABLE image_info(
                                  id BIGINT NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                                  orig_name varchar(255) NOT NULL,
                                  gen_name varchar(100) NOT NULL,
                                  size integer NOT NULL,
                                  upload_date date NOT NULL,
                                  spot_id BIGINT DEFAULT NULL REFERENCES spot (id)
                                      ON UPDATE CASCADE ON DELETE CASCADE,
                                  user_id BIGINT DEFAULT NULL REFERENCES "user" (id)
                                      ON UPDATE CASCADE ON DELETE CASCADE
);
------------------------------------------------------------------------------------------------------------------------
-- Комментарии
drop table if exists comment cascade;
CREATE TABLE comment(
                                id BIGINT NOT NULL GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
                                "text" varchar(100) NOT NULL,
                                upload_date date NOT NULL,
                                spot_id BIGINT NOT NULL REFERENCES spot (id)
                                    ON UPDATE CASCADE ON DELETE CASCADE,
                                user_id BIGINT NOT NULL REFERENCES "user" (id)
                                    ON UPDATE CASCADE ON DELETE CASCADE
);
------------------------------------------------------------------------------------------------------------------------
-- Промежуточная таблица спот-пользователь
drop table if exists spot_user cascade;
CREATE TABLE spot_user(
                                   favorite BOOLEAN NOT NULL DEFAULT FALSE,
                                   liked BOOLEAN NOT NULL DEFAULT FALSE,
                                   spot_id BIGINT NOT NULL REFERENCES spot (id)
                                       ON UPDATE CASCADE ON DELETE CASCADE,
                                   user_id BIGINT REFERENCES "user" (id)
                                       ON UPDATE CASCADE ON DELETE CASCADE,
                                   PRIMARY KEY (spot_id, user_id)
);
------------------------------------------------------------------------------------------------------------------------
-- Промежуточная таблица спот-вид_спота
drop table if exists spot_spot_type cascade;
CREATE TABLE spot_spot_type(
                                        spot_id BIGINT NOT NULL REFERENCES spot (id)
                                            ON UPDATE CASCADE ON DELETE CASCADE,
                                        spot_type_id int REFERENCES spot_type (id)
                                                           ON UPDATE CASCADE ON DELETE SET NULL,
                                        PRIMARY KEY (spot_id, spot_type_id)
);
------------------------------------------------------------------------------------------------------------------------
-- Промежуточная таблица спот-вид_спорта
drop table if exists spot_sport_type cascade;
CREATE TABLE spot_sport_type(
                                         spot_id BIGINT NOT NULL REFERENCES spot (id)
                                             ON UPDATE CASCADE ON DELETE CASCADE,
                                         sport_type_id int REFERENCES sport_type (id)
                                                            ON UPDATE CASCADE ON DELETE SET NULL,
                                         PRIMARY KEY (spot_id, sport_type_id)
);
------------------------------------------------------------------------------------------------------------------------
-- Функция выборки всех спотов находящихся в определенном радиусе (формула гаверсинуса)
CREATE OR REPLACE FUNCTION get_spots_in_radius(user_lat DOUBLE PRECISION, user_long DOUBLE PRECISION, raduis DOUBLE PRECISION)
    RETURNS SETOF spot AS $$
BEGIN
    return query
        SELECT * FROM spot as s
        WHERE (((acos(sin(($1*pi()/180)) * sin((s.lat*pi()/180)) +
                      cos(($1*pi()/180)) * cos((s.lat*pi()/180)) *
                      cos((($2 - s.lon) * pi()/180)))) * 180/pi()) * 60 * 1.1515 * 1.609344) < $3;
END;
$$ LANGUAGE plpgsql;
-- Пример ее использования: SELECT * FROM get_spots_in_radius(53.34, 83.69, 4000.0);
------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------