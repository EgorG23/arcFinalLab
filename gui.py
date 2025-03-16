import psycopg2
import streamlit as st
import pandas as pd

# Функция для подключения к базе данных
def get_connection():
    try:
        conn = psycopg2.connect(
            database="phonebook_db",
            user="postgres",
            password="postgres",
            host="localhost",
            port="5432"
        )
        return conn
    except Exception as e:
        st.error(f"Ошибка подключения: {e}")
        return None

# Функция для добавления контакта
def add_contact(full_name, phone_number, note):
    conn = get_connection()
    if conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("add_contact", (full_name, phone_number, note))
                result = cur.fetchone()[0]
                conn.commit()
                st.success(result)
            except psycopg2.Error as e:
                st.error(f"Ошибка при добавлении контакта: {e}")
            finally:
                conn.close()

# Функция для удаления контакта
def delete_contact(contact_id):
    conn = get_connection()
    if conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("delete_contact", (contact_id,))
                result = cur.fetchone()[0]
                conn.commit()
                st.success(result)
            except psycopg2.Error as e:
                st.error(f"Ошибка при удалении контакта: {e}")
            finally:
                conn.close()

# Функция для обновления контакта
def update_contact(phone_number, full_name, new_phone_number, note):
    conn = get_connection()
    if conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("update_contact", (phone_number, full_name, new_phone_number, note))
                result = cur.fetchone()[0]
                conn.commit()
                st.success(result)
            except psycopg2.Error as e:
                st.error(f"Ошибка при обновлении контакта: {e}")
            finally:
                conn.close()

# Функция для поиска контактов
def search_contacts(search_query):
    conn = get_connection()
    if conn:
        with conn.cursor() as cur:
            try:
                cur.callproc("search_contacts", (search_query,))
                results = cur.fetchall()
                return results
            except psycopg2.Error as e:
                st.error(f"Ошибка при поиске контактов: {e}")
            finally:
               conn.close()
    return []

# Отображает содержимое таблицы контактов
def display_contacts(table_name: str = "contacts"):
    conn = get_connection()
    if not conn:
        return
    try:
        with conn.cursor() as cur:
            cur.callproc("show_table", (table_name,))
            results = cur.fetchall()

            if not results:
                st.warning("Таблица пуста")
                return

            if 'error' in results[0][0]:
                st.error(results[0][0]['error'])
                return

            data = [row[0] for row in results]

            columns_order = ['contact_id', 'full_name', 'phone_number', 'note']

            df = pd.DataFrame(data)

            if not df.empty:
                df = df[columns_order]
                st.dataframe(df, use_container_width=True)

    except Exception as e:
        st.error(f"Ошибка отображения данных: {e}")
    finally:
        conn.close()


# Основная функция для Streamlit
def main():
    st.title("Телефонная книга")

    # Меню для выбора действия
    menu = ["Добавить контакт", "Обновить контакт", "Удалить контакт", "Поиск контактов", "Просмотр всех контактов"]
    choice = st.sidebar.selectbox("Выберите действие", menu)

    if choice == "Добавить контакт":
        st.header("Добавить новый контакт")
        full_name = st.text_input("ФИО")
        phone_number = st.text_input("Номер телефона")
        note = st.text_area("Заметка")
        if st.button("Добавить"):
            if full_name and phone_number:
                add_contact(full_name, phone_number, note)
            else:
                st.error("Пожалуйста, заполните все обязательные поля.")

    elif choice == "Обновить контакт":
        st.header("Обновить контакт")
        phone_number = st.text_input("Введите номер телефона для обновления")
        full_name = st.text_input("ФИО")
        new_phone_number = st.text_input("Новый номер телефона")
        note = st.text_area("Заметка")
        if st.button("Обновить"):
            if phone_number and full_name and new_phone_number:
                update_contact(phone_number, full_name, new_phone_number, note)
            else:
                st.error("Пожалуйста, заполните все обязательные поля.")


    elif choice == "Удалить контакт":
        st.header("Удалить контакт")
        phone_number = st.text_input("Введите номер телефона для удаления")
        if st.button("Удалить"):
            if phone_number:
                delete_contact(phone_number)
            else:
                st.error("Пожалуйста, введите номер телефона.")

    elif choice == "Поиск контактов":
        st.header("Поиск контактов")
        search_query = st.text_input("Введите ФИО или номер телефона")
        if st.button("Найти"):
            if search_query:
                results = search_contacts(search_query)
                if results:
                    st.table(results)
                else:
                    st.warning("Контакты не найдены.")
            else:
                st.error("Пожалуйста, введите запрос для поиска.")

    elif choice == "Просмотр всех контактов":


        st.header("Просмотр таблиц")
        table_choice = st.selectbox("Выберите таблицу:", ["contacts"])
        if st.button("Показать"):
            display_contacts(table_choice)


if __name__ == "__main__":
    main()