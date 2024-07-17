from flask import Flask, render_template, request, redirect, url_for, session, flash
import hashlib
from flask_mysqldb import MySQL

app = Flask(__name__)
app.secret_key = 'your_secret_key'

# MySQL Configuration
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = '1234'
app.config['MYSQL_DB'] = 'hospital_management_system'
app.config['MYSQL_HOST'] = 'localhost'

mysql = MySQL(app)

@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        print(f"Attempting login with username: {username} and password: {password}")

        cursor = mysql.connection.cursor()
        cursor.execute('SELECT * FROM login WHERE ID = %s', (username,))
        user = cursor.fetchone()
        cursor.close()

        if user:
            stored_password = user[1]  # Assuming 'PW' is the second column in your query result tuple
            if password == stored_password:
                session['username'] = username
                return redirect(url_for('dashboard'))
            else:
                error = 'Invalid password'
        else:
            error = 'User not found'

        return render_template('login.html', error=error)

    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    if 'username' in session:
        return render_template('dashboard.html', username=session['username'])
    else:
        return redirect(url_for('login'))

@app.route('/patients')
def patients():
    if 'username' in session:
        cursor = mysql.connection.cursor()
        cursor.callproc('GetAllPatients')
        patients = cursor.fetchall()
        cursor.close()
        return render_template('patients.html', patients=patients)
    else:
        return redirect(url_for('login'))

@app.route('/employees')
def employees():
    if 'username' in session:
        cursor = mysql.connection.cursor()
        cursor.callproc('GetAllEmployees')
        employees = cursor.fetchall()
        cursor.close()
        return render_template('employees.html', employees=employees)
    else:
        return redirect(url_for('login'))

@app.route('/rooms')
def rooms():
    if 'username' in session:
        cursor = mysql.connection.cursor()
        cursor.callproc('GetAvailableRooms')
        rooms = cursor.fetchall()
        cursor.close()
        return render_template('rooms.html', rooms=rooms)
    else:
        return redirect(url_for('login'))

@app.route('/ambulances')
def ambulances():
    if 'username' in session:
        cursor = mysql.connection.cursor()
        cursor.callproc('GetAllAmbulances')
        ambulances = cursor.fetchall()
        cursor.close()
        return render_template('ambulances.html', ambulances=ambulances)
    else:
        return redirect(url_for('login'))

@app.route('/logout')
def logout():
    session.pop('username', None)
    return redirect(url_for('login'))

@app.route('/add_patient', methods=['GET', 'POST'])
def add_patient():
    if 'username' in session:
        if request.method == 'POST':
            p_id = request.form['id']
            p_name = request.form['name']
            p_number = request.form['number']
            p_gender = request.form['gender']
            p_disease = request.form['disease']
            p_room_number = request.form['room_number']
            p_admission_time = request.form['admission_time']
            p_deposite = request.form['deposite']

            cursor = mysql.connection.cursor()
            cursor.callproc('AddPatient', (p_id, p_name, p_number, p_gender, p_disease, p_room_number, p_admission_time, p_deposite))
            mysql.connection.commit()
            cursor.close()

            flash('Patient added successfully', 'success')
            return redirect(url_for('patients'))
        else:
            return render_template('add_patient.html')  # Display the form to add a new patient
    else:
        return redirect(url_for('login'))
    
@app.route('/remove_patient/<patient_id>', methods=['POST'])
def remove_patient(patient_id):
    if 'username' in session:
        cursor = mysql.connection.cursor()
        try:
            # Retrieve room number of the patient to update room availability
            cursor.execute('SELECT Room_Number FROM patient_info WHERE ID = %s', (patient_id,))
            room_number = cursor.fetchone()[0]

            # Remove the patient from the database
            cursor.execute('DELETE FROM patient_info WHERE ID = %s', (patient_id,))
            mysql.connection.commit()

            # Update room availability to 'Available'
            cursor.execute('UPDATE Room SET Availability = "Available" WHERE room_no = %s', (room_number,))
            mysql.connection.commit()

            cursor.close()

            return redirect(url_for('patients'))
        except Exception as e:
            print(f"Error removing patient: {e}")
            cursor.close()
            return "Error removing patient", 500
    else:
        return redirect(url_for('login'))
    
@app.route('/update_patient/<patient_id>', methods=['GET'])
def show_update_patient_form(patient_id):
    if 'username' in session:
        cursor = mysql.connection.cursor()
        cursor.execute('SELECT * FROM patient_info WHERE ID = %s', (patient_id,))
        patient = cursor.fetchone()
        cursor.close()
        return render_template('update_patient.html', patient=patient)
    else:
        return redirect(url_for('login'))

@app.route('/update_patient/<patient_id>', methods=['POST'])
def update_patient(patient_id):
    if 'username' in session:
        name = request.form['name']
        number = request.form['number']
        gender = request.form['gender']
        disease = request.form['disease']
        room_number = request.form['room_number']
        admission_time = request.form['admission_time']
        deposite = request.form['deposite']

        cursor = mysql.connection.cursor()
        cursor.execute('''
            UPDATE patient_info 
            SET Name = %s, Number = %s, Gender = %s, Patient_Disease = %s, Room_Number = %s, Admission_Time = %s, Deposite = %s 
            WHERE ID = %s
        ''', (name, number, gender, disease, room_number, admission_time, deposite, patient_id))
        mysql.connection.commit()
        cursor.close()

        flash('Patient details updated successfully', 'success')
        return redirect(url_for('patients'))
    else:
        return redirect(url_for('login'))

    
@app.route('/departments')
def departments():
    if 'username' in session:
        cursor = mysql.connection.cursor()
        cursor.execute('SELECT * FROM department')
        departments = cursor.fetchall()
        cursor.close()
        return render_template('departments.html', departments=departments)
    else:
        return redirect(url_for('login'))

if __name__ == '__main__':
    app.run(debug=True)




