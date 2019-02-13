(sleep 30
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER 'webpocdbuser' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD'; create database employee_db; GRANT ALL PRIVILEGES ON employee_db.* TO 'webpocdbuser'"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" employee_db < /tmp/employee_db.sql
exit)&
