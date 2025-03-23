from flask import Flask, render_template, request, redirect, url_for
import psycopg2

app = Flask(__name__)

def get_db_connection():
    conn = psycopg2.connect(
        host="db",
        database="phonebook",
        user="admin",
        password="admin"
    )
    return conn

@app.route('/')
def index():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('SELECT * FROM contacts;')
    contacts = cur.fetchall()
    cur.close()
    conn.close()
    return render_template('index.html', contacts=contacts)

@app.route('/add', methods=['POST'])
def add():
    full_name = request.form['full_name']
    phone_number = request.form['phone_number']
    note = request.form['note']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('INSERT INTO contacts (full_name, phone_number, note) VALUES (%s, %s, %s)',
                (full_name, phone_number, note))
    conn.commit()
    cur.close()
    conn.close()
    return redirect(url_for('index'))

@app.route('/edit/<int:id>', methods=['POST'])
def edit(id):
    full_name = request.form['full_name']
    phone_number = request.form['phone_number']
    note = request.form['note']
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('UPDATE contacts SET full_name = %s, phone_number = %s, note = %s WHERE id = %s',
                (full_name, phone_number, note, id))
    conn.commit()
    cur.close()
    conn.close()
    return redirect(url_for('index'))

@app.route('/delete/<int:id>')
def delete(id):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute('DELETE FROM contacts WHERE id = %s', (id,))
    conn.commit()
    cur.close()
    conn.close()
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(host='0.0.0.0')
