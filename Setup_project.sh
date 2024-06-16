#!/bin/bash

# Set project directory
PROJECT_DIR="credentials_project"
CGI_BIN_DIR="$PROJECT_DIR/cgi-bin"

# Create project directories
mkdir -p "$CGI_BIN_DIR"

# Create HTML form file
FORM_FILE="$PROJECT_DIR/credentials_form.html"
cat <<EOL > "$FORM_FILE"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Credentials Form</title>
</head>
<body>
    <h1>Enter Database and API Credentials</h1>
    <form action="/cgi-bin/process_credentials.py" method="post">
        <h2>Database Credentials</h2>
        <label for="db_user">Database User:</label>
        <input type="text" id="db_user" name="db_user" required><br><br>

        <label for="db_password">Database Password:</label>
        <input type="password" id="db_password" name="db_password" required><br><br>

        <label for="db_host">Database Host:</label>
        <input type="text" id="db_host" name="db_host" required><br><br>

        <label for="db_name">Database Name:</label>
        <input type="text" id="db_name" name="db_name" required><br><br>

        <h2>API Credentials</h2>
        <label for="api_username">API Username:</label>
        <input type="text" id="api_username" name="api_username" required><br><br>

        <label for="api_password">API Password:</label>
        <input type="password" id="api_password" name="api_password" required><br><br>

        <input type="submit" value="Submit">
    </form>
</body>
</html>
EOL

# Create Python CGI script
CGI_SCRIPT="$CGI_BIN_DIR/process_credentials.py"
cat <<EOL > "$CGI_SCRIPT"
#!/usr/bin/env python3

import cgi
import cgitb
import requests
import mysql.connector
from mysql.connector import Error

cgitb.enable()  # Enable CGI error reporting

# API endpoints
login_url = "https://ebms.obr.gov.bi:9443/ebms_api"
invoice_url = "https://ebms.obr.bi:9443/ebms_api/getInvoice"

def get_bearer_token(api_username, api_password):
    credentials = {
        'username': api_username,
        'password': api_password
    }
    try:
        response = requests.post(login_url, json=credentials)
        response.raise_for_status()
        return response.json()['token']
    except requests.RequestException as e:
        print(f"Error obtaining bearer token: {e}")
        return None

def fetch_invoices(token):
    headers = {'Authorization': f'Bearer {token}'}
    try:
        response = requests.get(invoice_url, headers=headers)
        response.raise_for_status()
        return response.json()
    except requests.RequestException as e:
        print(f"Error fetching invoices: {e}")
        return None

def connect_to_database(config):
    try:
        connection = mysql.connector.connect(**config)
        if connection.is_connected():
            print("Successfully connected to the database")
            return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}")
        return None

def main():
    # Print content-type header
    print("Content-Type: text/html\n")

    # Parse form data
    form = cgi.FieldStorage()
    db_user = form.getvalue('db_user')
    db_password = form.getvalue('db_password')
    db_host = form.getvalue('db_host')
    db_name = form.getvalue('db_name')
    api_username = form.getvalue('api_username')
    api_password = form.getvalue('api_password')

    # Database configuration
    db_config = {
        'user': db_user,
        'password': db_password,
        'host': db_host,
        'database': db_name,
    }

    # Get the bearer token
    token = get_bearer_token(api_username, api_password)
    if not token:
        return

    # Fetch invoices
    invoices = fetch_invoices(token)
    if not invoices:
        return

    # Connect to the database
    connection = connect_to_database(db_config)
    if not connection:
        return

    cursor = connection.cursor()

    # Example of processing invoices and inserting them into the database
    for invoice in invoices:
        try:
            # Assuming the invoices have these fields, adapt as necessary
            invoice_id = invoice['id']
            amount = invoice['amount']
            customer = invoice['customer']
            date = invoice['date']
            
            query = """
            INSERT INTO invoices (invoice_id, amount, customer, date)
            VALUES (%s, %s, %s, %s)
            """
            cursor.execute(query, (invoice_id, amount, customer, date))
            connection.commit()
            print(f"Inserted invoice {invoice_id} into the database.")
        except Error as e:
            print(f"Error inserting invoice into MySQL: {e}")

    # Close database connection
    cursor.close()
    connection.close()

if __name__ == "__main__":
    main()
EOL

# Make the CGI script executable
chmod +x "$CGI_SCRIPT"

echo "Project setup complete. Place the 'credentials_project' directory in your web server's document root and configure CGI execution if necessary."