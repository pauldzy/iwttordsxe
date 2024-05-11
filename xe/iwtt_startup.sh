#!/bin/sh

if [ -f /opt/oracle/oradata/iwttdb.txt ]
then
   echo "iwttdb already set up"
else
   echo "setting up iwttdb on first start"
   
   sqlplus -s "sys/${ORACLE_PWD}@iwttxe:1521/XEPDB1 as sysdba" <<EOF
CREATE TABLESPACE iwtt_data_orcwater DATAFILE 'iwtt_data_orcwater.dbf' SIZE 400M AUTOEXTEND ON NEXT 1m;

CREATE USER iwtt IDENTIFIED BY "${IWTT_PWD}" DEFAULT TABLESPACE iwtt_data_orcwater QUOTA UNLIMITED ON iwtt_data_orcwater;
GRANT connect,resource,create view TO iwtt;

CREATE USER iwtt_rest IDENTIFIED BY "${IWTT_PWD}" DEFAULT TABLESPACE iwtt_data_orcwater QUOTA UNLIMITED ON iwtt_data_orcwater;
GRANT connect,resource,create view TO iwtt_rest;

CREATE DIRECTORY loading_dock AS '/loading_dock';
GRANT read,write ON DIRECTORY loading_dock TO iwtt;
GRANT read,write ON DIRECTORY loading_dock TO iwtt_rest;

exit;
EOF

fi

touch /opt/oracle/oradata/iwttdb.txt
