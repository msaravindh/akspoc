<%@ page language="java" contentType="text/html; charset=ISO-8859-1"
    pageEncoding="ISO-8859-1"%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1">
<title>Data Saved!</title>
</head>
<body>
<%= "Data Saved Successfully !!" %>
<%@ page import="java.sql.*" %>
<%@ page import="javax.sql.*" %>
<%@ page import="java.io.InputStream" %>
<%@ page import="java.util.Properties" %>
<%
String empid = request.getParameter("empid");
session.putValue("empid",empid);
String empname = request.getParameter("empname");
session.putValue("empname",empname);

//Class.forName("com.mysql.jdbc.Driver");
InputStream fis = this.getClass().getClassLoader().getResourceAsStream("/project.properties"); 
Properties p=new Properties (); 
p.load (fis); 
String dname= (String) p.get ("Dname"); 
//String url= (String) p.get ("Url"); 
String url = System.getenv("MYSQL_URI");
//String username= (String) p.get ("Uname");
String username = System.getenv("MYSQL_USER");
String password= (String) p.get ("Password"); 
Class.forName(dname); 

//String Url ="jdbc:mysql://osstestdbmysql.mysql.database.azure.com:3306/employee_db?serverTimezone=UTC"; 
//java.sql.Connection con = DriverManager.getConnection(Url, "vmadmin@osstestdbmysql", "Microsoft@1");
java.sql.Connection con = DriverManager.getConnection(url,username,password);
Statement st = con.createStatement();
ResultSet rs;
int i = st.executeUpdate("insert into employees values('"+empid+"','"+empname+"')");
out.println("Done :)");
%>
</body>
</html>