(sleep 30
mysql -u root -pMicrosoft@1 -e "CREATE USER 'webpocdbuser' IDENTIFIED BY 'Microsoft@1'; create database employee_db; GRANT ALL PRIVILEGES ON employee_db.* TO 'webpocdbuser'"
mysql -u root -pMicrosoft@1 employee_db < /tmp/employee_db.sql
exit)&
