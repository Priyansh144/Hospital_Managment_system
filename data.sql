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
this is the backend code
-- Create database and switch to itDROP DATABASE IF EXISTS hospital_management_system;
DROP DATABASE IF EXISTS hospital_management_system;
CREATE DATABASE hospital_management_system;
USE hospital_management_system;


-- Create login table
CREATE TABLE login (
    ID VARCHAR(20) PRIMARY KEY,
    PW VARCHAR(64) NOT NULL  -- Assuming 64-character hash length for SHA-256
);

-- Insert initial data into login table
INSERT INTO login (ID, PW) VALUES ("Priyansh", "123456789");
select *from login;


-- Create Room table
CREATE TABLE Room (
    room_no VARCHAR(20) PRIMARY KEY,
    Availability VARCHAR(20) NOT NULL,
    Price DECIMAL(10, 2) NOT NULL,
    Room_Type VARCHAR(100) NOT NULL
);

-- Insert initial data into Room table
INSERT INTO Room (room_no, Availability, Price, Room_Type) VALUES
("100", "Available", 500, "G Bed 1"),
("101", "Available", 500, "G Bed 2"),
("102", "Available", 500, "G Bed 3"),
("103", "Available", 500, "G Bed 4"),
("200", "Available", 1500, "Private Room"),
("201", "Available", 1500, "Private Room"),
("202", "Available", 1500, "Private Room"),
("203", "Available", 1500, "Private Room"),
("300", "Available", 3500, "ICU Bed 1"),
("301", "Available", 3500, "ICU Bed 2"),
("302", "Available", 3500, "ICU Bed 3"),
("303", "Available", 3500, "ICU Bed 4"),
("304", "Available", 3500, "ICU Bed 5"),
("305", "Available", 3500, "ICU Bed 6");

-- Create patient_info table
CREATE TABLE patient_info (
    ID VARCHAR(20) PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Number VARCHAR(20) NOT NULL,
    Gender VARCHAR(20),
    Patient_Disease VARCHAR(50),
    Room_Number VARCHAR(20),
    Admission_Time DATETIME,
    Deposite DECIMAL(10, 2),
    FOREIGN KEY (Room_Number) REFERENCES Room(room_no)
);

-- Create department table
CREATE TABLE department (
    Department_ID INT AUTO_INCREMENT PRIMARY KEY,
    Department_Name VARCHAR(100) NOT NULL,
    Phone_no VARCHAR(20) NOT NULL
);

-- Insert initial data into department table
INSERT INTO department (Department_Name, Phone_no) VALUES
("Surgical department", "123456789"),
("Nursing department", "123456789"),
("Operation theatre Complex (OT)", "123456789"),
("Paramedical department", "123456789");

-- Create EMP_INFO table
CREATE TABLE EMP_INFO (
    Employee_ID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(50) NOT NULL,
    Age INT NOT NULL,
    Phone_Number VARCHAR(20) NOT NULL,
    Salary DECIMAL(10, 2) NOT NULL,
    Gmail VARCHAR(50) NOT NULL,
    Aadhar_Number VARCHAR(20) NOT NULL,
    Department_ID INT,
    FOREIGN KEY (Department_ID) REFERENCES department(Department_ID)
);

-- Insert initial data into EMP_INFO table
INSERT INTO EMP_INFO (Name, Age, Phone_Number, Salary, Gmail, Aadhar_Number, Department_ID) VALUES
("Doctor1", 30, "123456789", 50000, "doc1@gmail.com", "123456789", 1),
("Doctor2", 35, "987654321", 60000, "doc2@gmail.com", "987654321", 1),
("Nurse1", 25, "123123123", 30000, "nurse1@gmail.com", "111111111", 2);

-- Create Ambulance table
CREATE TABLE Ambulance (
    Ambulance_ID INT AUTO_INCREMENT PRIMARY KEY,
    Driver_Name VARCHAR(50) NOT NULL,
    Gender VARCHAR(20),
    Car_name VARCHAR(20),
    Availability VARCHAR(20) NOT NULL,
    Location VARCHAR(50)
);

-- Insert initial data into Ambulance table
INSERT INTO Ambulance (Driver_Name, Gender, Car_name, Availability, Location) VALUES
("John Doe", "Male", "Zen", "Available", "Area 16");

-- Add a trigger to update room availability when a patient is admitted
DELIMITER //

CREATE TRIGGER update_room_availability
AFTER INSERT ON patient_info
FOR EACH ROW
BEGIN
    UPDATE Room
    SET Availability = 'Occupied'
    WHERE room_no = NEW.Room_Number;
END //

DELIMITER ;

-- Create a procedure to discharge a patient and free up the room
DELIMITER //

CREATE PROCEDURE DischargePatient(IN patient_id VARCHAR(20))
BEGIN
    DECLARE room_no VARCHAR(20);
    
    -- Get the room number of the patient
    SELECT Room_Number INTO room_no FROM patient_info WHERE ID = patient_id;
    
    -- Delete the patient record
    DELETE FROM patient_info WHERE ID = patient_id;
    
    -- Update the room availability
    UPDATE Room SET Availability = 'Available' WHERE room_no = room_no;
END //

DELIMITER ;

-- Create a procedure to get all available rooms
DELIMITER //

CREATE PROCEDURE GetAvailableRooms()
BEGIN
    SELECT * FROM Room WHERE Availability = 'Available';
END //

DELIMITER ;

-- Create a procedure to add a new patient
DELIMITER //

CREATE PROCEDURE AddPatient(
    IN p_id VARCHAR(20),
    IN p_name VARCHAR(50),
    IN p_number VARCHAR(20),
    IN p_gender VARCHAR(20),
    IN p_disease VARCHAR(50),
    IN p_room_number VARCHAR(20),
    IN p_admission_time DATETIME,
    IN p_deposite DECIMAL(10, 2)
)
BEGIN
    INSERT INTO patient_info (ID, Name, Number, Gender, Patient_Disease, Room_Number, Admission_Time, Deposite)
    VALUES (p_id, p_name, p_number, p_gender, p_disease, p_room_number, p_admission_time, p_deposite);
END //

DELIMITER ;

-- Create a procedure to get all patients
DELIMITER //

CREATE PROCEDURE GetAllPatients()
BEGIN
    SELECT 
        p.ID,
        p.Name,
        p.Number,
        p.Gender,
        p.Patient_Disease,
        p.Admission_Time,
        p.Deposite,
        r.Room_Type,
        r.Price
    FROM 
        patient_info p
    JOIN 
        Room r ON p.Room_Number = r.room_no;
END //

DELIMITER ;

-- Create a procedure to get detailed employee information
DELIMITER //

CREATE PROCEDURE GetAllEmployees()
BEGIN
    SELECT 
        e.Employee_ID,
        e.Name,
        e.Age,
        e.Phone_Number,
        e.Salary,
        e.Gmail,
        e.Aadhar_Number,
        d.Department_Name
    FROM 
        EMP_INFO e
    JOIN 
        department d ON e.Department_ID = d.Department_ID;
END //

DELIMITER ;

-- Create a procedure to get all ambulances and their availability
DELIMITER //

CREATE PROCEDURE GetAllAmbulances()
BEGIN
    SELECT 
        Ambulance_ID,
        Driver_Name,
        Gender,
        Car_name,
        Availability,
        Location
    FROM 
        Ambulance;
END //

DELIMITER ;

-- Select statements to view data in tables
SELECT * FROM login;
SELECT * FROM patient_info;
SELECT * FROM Room;
SELECT * FROM department;
SELECT * FROM EMP_INFO;
SELECT * FROM Ambulance;