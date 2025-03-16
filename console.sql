CREATE DATABASE phonebook_db;

CREATE TABLE contacts (
    contact_id SERIAL PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone_number TEXT NOT NULL UNIQUE,
    note TEXT
);

CREATE OR REPLACE FUNCTION show_table(p_table_name TEXT)
RETURNS TABLE(
    table_content JSONB
) AS $$
DECLARE
    v_query TEXT;
    v_table_exists BOOLEAN;
BEGIN
    -- Проверка существования таблицы
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_name = p_table_name
    ) INTO v_table_exists;

    -- Если таблица не существует, возвращаем сообщение
    IF NOT v_table_exists THEN
        RAISE NOTICE 'Таблица % не существует.', p_table_name;
        RETURN QUERY SELECT jsonb_build_object('error', format('Таблица %s не существует', p_table_name));
        RETURN;
    END IF;

    -- Формирование запроса с явным преобразованием в JSONB и экранированием имени таблицы
    v_query := format('SELECT to_jsonb(t) FROM %I t', p_table_name);

    -- Возврат данных
    RETURN QUERY EXECUTE v_query;

EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Ошибка при выводе таблицы: %', SQLERRM;
        RETURN QUERY SELECT jsonb_build_object('error', SQLERRM);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION delete_contact(
    p_phone_number TEXT
) RETURNS TEXT AS $$
BEGIN
    -- Проверка номера телефона
    IF NOT validate_phone_number(p_phone_number) THEN
        RETURN 'Ошибка: номер телефона должен начинаться с 7 или 8 и содержать ровно 11 цифр.';
    END IF;

    -- Удаление контакта по номеру телефона
    DELETE FROM contacts WHERE phone_number = p_phone_number;

    -- Проверка, был ли удалён контакт
    IF NOT FOUND THEN
        RETURN 'Контакт с указанным номером телефона не найден.';
    END IF;

    RETURN 'Контакт успешно удален.';
EXCEPTION
    WHEN others THEN
        RETURN 'Ошибка при удалении контакта: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Функция для добавления контакта
CREATE OR REPLACE FUNCTION add_contact(
    p_full_name TEXT,
    p_phone_number TEXT,
    p_note TEXT
) RETURNS TEXT AS $$
BEGIN
    -- Проверка номера телефона на уникальность
    IF EXISTS(SELECT 1 FROM contacts WHERE phone_number = p_phone_number) THEN
        RETURN 'Ошибка: контакт с таким номером уже существует';
    END IF;
    -- Проверка ФИО
    IF NOT validate_text(p_full_name) THEN
        RETURN 'Ошибка: ФИО содержит недопустимые символы или пусто.';
    END IF;

    -- Проверка номера телефона
    IF NOT validate_phone_number(p_phone_number) THEN
        RETURN 'Ошибка: номер телефона должен начинаться с 7 или 8 и содержать ровно 11 цифр.';
    END IF;

    -- Вставка данных
    BEGIN
        INSERT INTO contacts (full_name, phone_number, note)
        VALUES (p_full_name, p_phone_number, p_note);
        RETURN 'Контакт успешно добавлен.';
    EXCEPTION
        WHEN unique_violation THEN
            RETURN 'Ошибка: номер телефона уже существует.';
        WHEN others THEN
            RETURN 'Ошибка при добавлении контакта: ' || SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- Функция для обновления контакта
CREATE OR REPLACE FUNCTION update_contact(
    p_phone_number TEXT,
    p_full_name TEXT,
    p_new_phone_number TEXT,
    p_note TEXT
) RETURNS TEXT AS $$

BEGIN
    -- Проверка на корректность ФИО
    IF NOT validate_text(p_full_name) THEN
        RETURN 'Ошибка: ФИО содержит недопустимые символы или пусто.';
    END IF;

    -- Проверка на корректность номера телефона
    IF NOT validate_phone_number(p_new_phone_number) THEN
        RETURN 'Ошибка: номер телефона должен начинаться с 7 или 8 и содержать ровно 11 цифр.';
    END IF;

    -- Проверка существования контакта по старому номеру
    IF NOT EXISTS (SELECT 1 FROM contacts WHERE phone_number = p_phone_number) THEN
        RETURN 'Ошибка: контакт с таким номером телефона не найден.';
    END IF;

    -- Проверка на уникальность нового номера телефона
    IF EXISTS (SELECT 1 FROM contacts WHERE phone_number = p_new_phone_number) THEN
        RETURN 'Ошибка: контакт с таким новым номером телефона уже существует.';
    END IF;

    -- Обновление данных
    BEGIN
        UPDATE contacts
        SET full_name = p_full_name, phone_number = p_phone_number, note = p_note
        WHERE phone_number = p_phone_number;
        RETURN 'Контакт успешно обновлен.';
    EXCEPTION
        WHEN unique_violation THEN
            RETURN 'Ошибка: номер телефона уже существует.';
        WHEN others THEN
            RETURN 'Ошибка при обновлении контакта: ' || SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- Функция для удаления контакта
CREATE OR REPLACE FUNCTION delete_contact(
    p_phone_number TEXT
) RETURNS TEXT AS $$
DECLARE
    v_clean_phone TEXT;
BEGIN
    -- Очистка номера телефона от нецифровых символов
    v_clean_phone := REGEXP_REPLACE(p_phone_number, '[^0-9]', '', 'g');

    -- Проверка корректности номера телефона
    IF NOT validate_phone_number(v_clean_phone) THEN
        RETURN 'Ошибка: номер телефона должен начинаться с 7 или 8 и содержать ровно 11 цифр.';
    END IF;

    -- Проверка существования контакта с таким номером телефона
    IF NOT EXISTS (SELECT 1 FROM contacts WHERE phone_number = v_clean_phone) THEN
        RETURN 'Ошибка: контакт с указанным номером телефона не найден.';
    END IF;

    -- Удаление контакта
    DELETE FROM contacts WHERE phone_number = v_clean_phone;

    -- Проверка, был ли удалён контакт
    IF NOT FOUND THEN
        RETURN 'Ошибка: контакт не был удалён.';
    END IF;

    RETURN 'Контакт успешно удалён.';
EXCEPTION
    WHEN others THEN
        RETURN 'Ошибка при удалении контакта: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- Функция для поиска контактов
CREATE OR REPLACE FUNCTION search_contacts(
    p_search_query TEXT
) RETURNS TABLE(
    contact_id INT,
    full_name TEXT,
    phone_number TEXT,
    note TEXT
) AS $$
BEGIN
    RETURN QUERY
        SELECT * FROM contacts
        WHERE contacts.full_name ILIKE '%' || p_search_query || '%'
           OR contacts.phone_number ILIKE '%' || p_search_query || '%';
END;
$$ LANGUAGE plpgsql;




-- Функция для проверки номера телефона
CREATE OR REPLACE FUNCTION validate_phone_number(p_phone_number TEXT) RETURNS BOOLEAN AS $$
BEGIN
    -- Очистка номера телефона от нецифровых символов
    p_phone_number := REGEXP_REPLACE(p_phone_number, '[^0-9]', '', 'g');

    IF p_phone_number ~ '^[78]\d{10}$' THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Функция для проверки адреса
CREATE OR REPLACE FUNCTION validate_text(p_text TEXT) RETURNS BOOLEAN AS $$
BEGIN
    -- Проверка, что адрес не пустой
    IF p_text IS NULL OR p_text = '' THEN
        RETURN FALSE;
    END IF;

    IF p_text ~ '[^a-zA-Zа-яА-Я0-9\s\-\.,]' THEN
        RETURN FALSE;
    END IF;

    IF p_text ~ '[()!@#\$%\^&\*\+=\[\]\{\};:"\\|<>/?`~_]' THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

