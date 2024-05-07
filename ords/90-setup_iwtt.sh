#!/bin/sh

if [ -f /stash/iwttimp.txt ]
then
   echo "iwttimp already loaded"
else
   echo "loading iwttimp on first start"
   
   sql -S iwtt/${IWTT_PWD}@iwttxe:1521/XEPDB1 <<EOF
DECLARE
   h1 NUMBER;
   js VARCHAR2(4000 Char);
BEGIN

   h1 := DBMS_DATAPUMP.OPEN(
       operation   => 'IMPORT'
      ,job_mode    => 'SCHEMA'
      ,remote_link => NULL
      ,job_name    => 'DZ1'
   );

   DBMS_DATAPUMP.ADD_FILE(
       handle      => h1
      ,filename    => 'iwtt_OWSTG.dmp'
      ,directory   => 'LOADING_DOCK'
   );

   DBMS_DATAPUMP.ADD_FILE(
       handle      => h1
      ,filename    => 'iwtt_OWSTG.log'
      ,directory   => 'LOADING_DOCK'
      ,filetype    => DBMS_DATAPUMP.KU\$_FILE_TYPE_LOG_FILE
   );

   DBMS_DATAPUMP.SET_PARAMETER(
       handle      => h1
      ,name        => 'TABLE_EXISTS_ACTION'
      ,value       => 'REPLACE'
   );

   DBMS_DATAPUMP.START_JOB(h1);

   DBMS_DATAPUMP.WAIT_FOR_JOB(
       handle      => h1
      ,job_state   => js    
   );

END;
/

exit;
EOF

   sql -S iwtt_rest/${IWTT_PWD}@iwttxe:1521/XEPDB1 <<EOF
DECLARE
   h1 NUMBER;
   js VARCHAR2(4000 Char);
BEGIN
   
   h1 := DBMS_DATAPUMP.OPEN(
       operation   => 'IMPORT'
      ,job_mode    => 'SCHEMA'
      ,remote_link => NULL
      ,job_name    => 'DZ2'
   );

   DBMS_DATAPUMP.ADD_FILE(
       handle      => h1
      ,filename    => 'iwtt_rest_OWSTG.dmp'
      ,directory   => 'LOADING_DOCK'
   );

   DBMS_DATAPUMP.ADD_FILE(
       handle      => h1
      ,filename    => 'iwtt_rest_OWSTG.log'
      ,directory   => 'LOADING_DOCK'
      ,filetype    => DBMS_DATAPUMP.KU\$_FILE_TYPE_LOG_FILE
   );

   DBMS_DATAPUMP.SET_PARAMETER(
       handle      => h1
      ,name        => 'TABLE_EXISTS_ACTION'
      ,value       => 'REPLACE'
   );

   DBMS_DATAPUMP.START_JOB(h1);

   DBMS_DATAPUMP.WAIT_FOR_JOB(
       handle      => h1
      ,job_state   => js    
   );
   
END;
/

exit;
EOF

   sql -S iwtt_rest/${IWTT_PWD}@iwttxe:1521/XEPDB1 <<EOF
BEGIN
   ORDS.ENABLE_SCHEMA(
      p_url_mapping_pattern => 'iwtt'
   );
   COMMIT;
   
   IWTT_REST.IWTT_ORDS.ORDS_ALL();
   
END;
/

exit;
EOF

fi

touch /stash/iwttimp.txt
