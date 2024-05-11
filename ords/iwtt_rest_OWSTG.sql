CREATE OR REPLACE PACKAGE iwtt_rest.ords_util
AUTHID CURRENT_USER
AS

   TYPE param_array IS TABLE OF CLOB;

   TYPE param_dict IS TABLE OF CLOB
   INDEX BY VARCHAR2(4000 Char);

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION body_parse(
       p_str              IN  CLOB
   ) RETURN param_dict DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION query_param(
       p_clb_dict         IN  param_dict
      ,p_key              IN  VARCHAR2
      ,p_default_value    IN  VARCHAR2 DEFAULT NULL
   ) RETURN CLOB DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION query_param_num(
       p_clb_dict         IN  param_dict
      ,p_key              IN  VARCHAR2
      ,p_default_value    IN  NUMBER DEFAULT NULL
   ) RETURN NUMBER DETERMINISTIC;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE delete_service(
       p_module_name        IN  VARCHAR2
      ,p_base_path          IN  VARCHAR2     DEFAULT NULL
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE define_service(
       p_module_name        IN  VARCHAR2
      ,p_base_path          IN  VARCHAR2     DEFAULT NULL
      ,p_pattern            IN  VARCHAR2     DEFAULT '.'
      ,p_source_get_type    IN  VARCHAR2     DEFAULT ORDS.SOURCE_TYPE_PLSQL
      ,p_source_get         IN  CLOB         DEFAULT NULL
      ,p_source_post_type   IN  VARCHAR2     DEFAULT ORDS.SOURCE_TYPE_PLSQL
      ,p_source_post        IN  CLOB         DEFAULT NULL
      ,p_items_per_page     IN  INTEGER      DEFAULT 0
      ,p_status             IN  VARCHAR2     DEFAULT 'PUBLISHED'
      ,p_priority           IN  INTEGER      DEFAULT 0
      ,p_etag_type          IN  VARCHAR2     DEFAULT 'HASH'
      ,p_etag_query         IN  VARCHAR2     DEFAULT NULL
      ,p_mimes_allowed      IN  VARCHAR2     DEFAULT NULL
      ,p_module_comments    IN  VARCHAR2     DEFAULT NULL
      ,p_template_comments  IN  VARCHAR2     DEFAULT NULL
      ,p_handler_comments   IN  VARCHAR2     DEFAULT NULL
      ,p_origins_allowed    IN  VARCHAR2     DEFAULT NULL
   );
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE reject_request;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE setup_ref_tables;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_env
   RETURN VARCHAR2 RESULT_CACHE;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_origins(
      p_service  IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2 RESULT_CACHE;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_header_name
   RETURN VARCHAR2 RESULT_CACHE;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION chk_header(
      p_header_value  IN  VARCHAR2
   ) RETURN BOOLEAN RESULT_CACHE;
   
END ords_util;
/

CREATE OR REPLACE PACKAGE BODY iwtt_rest.ords_util
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION safe_to_number(
       p_input            IN VARCHAR2
      ,p_null_replacement IN NUMBER DEFAULT NULL
   ) RETURN NUMBER
   AS
   BEGIN
      RETURN TO_NUMBER(
         REPLACE(
            REPLACE(
               p_input,
               CHR(10),
               ''
            ),
            CHR(13),
            ''
         ) 
      );
      
   EXCEPTION
      WHEN VALUE_ERROR
      THEN
         RETURN p_null_replacement;
         
   END safe_to_number;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION gz_split(
       p_str              IN CLOB
      ,p_regex            IN VARCHAR2
      ,p_match            IN VARCHAR2 DEFAULT NULL
      ,p_end              IN NUMBER   DEFAULT 0
      ,p_trim             IN VARCHAR2 DEFAULT 'FALSE'
   ) RETURN param_array DETERMINISTIC 
   AS
      int_delim      PLS_INTEGER;
      int_position   PLS_INTEGER := 1;
      int_counter    PLS_INTEGER := 1;
      ary_output     param_array;
      num_end        NUMBER      := p_end;
      str_trim       VARCHAR2(5 Char) := UPPER(p_trim);
      
      FUNCTION trim_varray(
         p_input            IN param_array
      ) RETURN param_array
      AS
         ary_output param_array := param_array();
         int_index  PLS_INTEGER := 1;
         str_check  CLOB;
         
      BEGIN

         --------------------------------------------------------------------------
         -- Step 10
         -- Exit if input is empty
         --------------------------------------------------------------------------
         IF p_input IS NULL
         OR p_input.COUNT = 0
         THEN
            RETURN ary_output;
            
         END IF;

         --------------------------------------------------------------------------
         -- Step 20
         -- Trim the strings removing anything utterly trimmed away
         --------------------------------------------------------------------------
         FOR i IN 1 .. p_input.COUNT
         LOOP
            str_check := TRIM(p_input(i));
            
            IF str_check IS NULL
            OR str_check = ''
            THEN
               NULL;
               
            ELSE
               ary_output.EXTEND(1);
               ary_output(int_index) := str_check;
               int_index := int_index + 1;
               
            END IF;

         END LOOP;

         --------------------------------------------------------------------------
         -- Step 10
         -- Return the results
         --------------------------------------------------------------------------
         RETURN ary_output;

      END trim_varray;

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Create the output array and check parameters
      --------------------------------------------------------------------------
      ary_output := param_array();

      IF str_trim IS NULL
      THEN
         str_trim := 'FALSE';
         
      ELSIF str_trim NOT IN ('TRUE','FALSE')
      THEN
         RAISE_APPLICATION_ERROR(-20001,'boolean error');
         
      END IF;

      IF num_end IS NULL
      THEN
         num_end := 0;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 20
      -- Exit early if input is empty
      --------------------------------------------------------------------------
      IF p_str IS NULL
      OR p_str = ''
      THEN
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 30
      -- Account for weird instance of pure character breaking
      --------------------------------------------------------------------------
      IF p_regex IS NULL
      OR p_regex = ''
      THEN
         FOR i IN 1 .. LENGTH(p_str)
         LOOP
            ary_output.EXTEND(1);
            ary_output(i) := SUBSTR(p_str,i,1);
            
         END LOOP;
         
         RETURN ary_output;
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 40
      -- Break string using the usual REGEXP functions
      --------------------------------------------------------------------------
      LOOP
         EXIT WHEN int_position = 0;
         int_delim  := REGEXP_INSTR(p_str,p_regex,int_position,1,0,p_match);
         
         IF  int_delim = 0
         THEN
            -- no more matches found
            ary_output.EXTEND(1);
            ary_output(int_counter) := SUBSTR(p_str,int_position);
            int_position  := 0;
            
         ELSE
            IF int_counter = num_end
            THEN
               -- take the rest as is
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position);
               int_position  := 0;
               
            ELSE
               --dbms_output.put_line(ary_output.COUNT);
               ary_output.EXTEND(1);
               ary_output(int_counter) := SUBSTR(p_str,int_position,int_delim-int_position);
               int_counter := int_counter + 1;
               int_position := REGEXP_INSTR(p_str,p_regex,int_position,1,1,p_match);
               
            END IF;
            
         END IF;
         
      END LOOP;

      --------------------------------------------------------------------------
      -- Step 50
      -- Trim results if so desired
      --------------------------------------------------------------------------
      IF str_trim = 'TRUE'
      THEN
         RETURN trim_varray(
            p_input => ary_output
         );
         
      END IF;

      --------------------------------------------------------------------------
      -- Step 60
      -- Cough out the results
      --------------------------------------------------------------------------
      RETURN ary_output;
      
   END gz_split;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION body_parse(
       p_str              IN  CLOB
   ) RETURN param_dict DETERMINISTIC
   AS
      ary_clob      param_array;
      ary_items     param_array;
      dict_results  param_dict;
   
   BEGIN
      
      IF p_str IS NULL
      OR p_str = ''
      THEN
         RETURN dict_results;
         
      END IF;
      
      ary_clob := gz_split(
          p_str   => p_str
         ,p_regex => CHR(38)
         ,p_trim  => 'TRUE'
      );
      
      FOR i IN 1 .. ary_clob.COUNT
      LOOP
         ary_items := gz_split(
             p_str   => ary_clob(i)
            ,p_regex => '='
            ,p_trim  => 'TRUE'
         );
         
         IF ary_items.COUNT = 2
         THEN
            IF ary_items(2) IS NOT NULL
            AND LENGTH(ary_items(2)) > 0
            AND TO_CHAR(SUBSTR(ary_items(2),1,1)) != ' '
            THEN
               dict_results(ary_items(1)) := UTL_URL.UNESCAPE(
                  REPLACE(ary_items(2),'+','%20')
               );
            
            END IF;
            
         END IF;
      
      END LOOP;
      
      RETURN dict_results;
      
   END body_parse;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION query_param(
       p_clb_dict         IN  param_dict
      ,p_key              IN  VARCHAR2
      ,p_default_value    IN  VARCHAR2 DEFAULT NULL
   ) RETURN CLOB DETERMINISTIC
   AS
      str_loop_key     VARCHAR2(4000 Char);
      clb_results      CLOB;
     
   BEGIN
   
      str_loop_key := p_clb_dict.FIRST;
      WHILE str_loop_key IS NOT NULL
      LOOP
         IF str_loop_key = p_key
         THEN
            RETURN p_clb_dict(str_loop_key);
            
         END IF;
      
         str_loop_key := p_clb_dict.NEXT(str_loop_key);
         
      END LOOP;
      
      RETURN p_default_value;
      
   END query_param;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION query_param_num(
       p_clb_dict         IN  param_dict
      ,p_key              IN  VARCHAR2
      ,p_default_value    IN  NUMBER DEFAULT NULL
   ) RETURN NUMBER DETERMINISTIC
   AS
      str_loop_key     VARCHAR2(4000 Char);
      clb_results      CLOB;
     
   BEGIN
   
      str_loop_key := p_clb_dict.FIRST;
      WHILE str_loop_key IS NOT NULL
      LOOP
         IF str_loop_key = p_key
         THEN
            RETURN safe_to_number(
                TO_CHAR(SUBSTR(p_clb_dict(str_loop_key),1,32000))
               ,p_default_value
            );
            
         END IF;
      
         str_loop_key := p_clb_dict.NEXT(str_loop_key);
         
      END LOOP;
      
      RETURN p_default_value;
   
   END query_param_num;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE delete_service(
       p_module_name        IN  VARCHAR2
      ,p_base_path          IN  VARCHAR2     DEFAULT NULL
   )
   AS
      str_name VARCHAR2(4000 Char);

   BEGIN

      ORDS.DELETE_MODULE(
         p_module_name => p_module_name
      );

      IF p_base_path IS NOT NULL
      THEN
         BEGIN
            SELECT
            a.name
            INTO
            str_name
            FROM
            user_ords_services a
            WHERE
            a.base_path = '/' || p_base_path;

         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               str_name := NULL;

            WHEN OTHERS
            THEN
               RAISE;

         END;

         IF str_name IS NOT NULL
         THEN
            ORDS.DELETE_MODULE(
               p_module_name => str_name
            );

         END IF;

      END IF;

      COMMIT;

   END delete_service;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE define_service(
       p_module_name        IN  VARCHAR2
      ,p_base_path          IN  VARCHAR2     DEFAULT NULL
      ,p_pattern            IN  VARCHAR2     DEFAULT '.'
      ,p_source_get_type    IN  VARCHAR2     DEFAULT ORDS.SOURCE_TYPE_PLSQL
      ,p_source_get         IN  CLOB         DEFAULT NULL
      ,p_source_post_type   IN  VARCHAR2     DEFAULT ORDS.SOURCE_TYPE_PLSQL
      ,p_source_post        IN  CLOB         DEFAULT NULL
      ,p_items_per_page     IN  INTEGER      DEFAULT 0
      ,p_status             IN  VARCHAR2     DEFAULT 'PUBLISHED'
      ,p_priority           IN  INTEGER      DEFAULT 0
      ,p_etag_type          IN  VARCHAR2     DEFAULT 'HASH'
      ,p_etag_query         IN  VARCHAR2     DEFAULT NULL
      ,p_mimes_allowed      IN  VARCHAR2     DEFAULT NULL
      ,p_module_comments    IN  VARCHAR2     DEFAULT NULL
      ,p_template_comments  IN  VARCHAR2     DEFAULT NULL
      ,p_handler_comments   IN  VARCHAR2     DEFAULT NULL
      ,p_origins_allowed    IN  VARCHAR2     DEFAULT NULL
   )
   AS
      str_base_path       VARCHAR2(32000 Char);
      str_origins_allowed VARCHAR2(32000 Char);
      str_header_name     VARCHAR2(4000 Char);

   BEGIN

      --------------------------------------------------------------------------
      -- Step 10
      -- Check over incoming parameters
      --------------------------------------------------------------------------
      IF p_base_path IS NULL
      THEN
         str_base_path := LOWER(p_module_name) || '/';

      ELSE
         str_base_path := p_base_path;

      END IF;

      IF p_origins_allowed IS NULL
      THEN
         str_origins_allowed := get_origins(LOWER(p_module_name));

      ELSE
         str_origins_allowed := p_origins_allowed;

      END IF;
      
      str_header_name := ords_util.get_header_name();

      --------------------------------------------------------------------------
      -- Step 20
      -- Delete any preexising service
      --------------------------------------------------------------------------
      delete_service(
          p_module_name     => p_module_name
         ,p_base_path       => str_base_path
      );

      --------------------------------------------------------------------------
      -- Step 30
      -- Create the module
      --------------------------------------------------------------------------
      ORDS.DEFINE_MODULE(
          p_module_name     => p_module_name
         ,p_base_path       => str_base_path
         ,p_items_per_page  => p_items_per_page
         ,p_status          => p_status
         ,p_comments        => p_module_comments
      );

      --------------------------------------------------------------------------
      -- Step 40
      -- Create the template
      --------------------------------------------------------------------------
      ORDS.DEFINE_TEMPLATE(
          p_module_name     => p_module_name
         ,p_pattern         => p_pattern
         ,p_priority        => p_priority
         ,p_etag_type       => p_etag_type
         ,p_etag_query      => p_etag_query
         ,p_comments        => p_template_comments
      );

      --------------------------------------------------------------------------
      -- Step 50
      -- Define the GET endpoint if requested
      --------------------------------------------------------------------------
      IF p_source_get IS NOT NULL
      THEN
         ORDS.DEFINE_HANDLER(
             p_module_name     => p_module_name
            ,p_pattern         => p_pattern
            ,p_method          => 'GET'
            ,p_source_type     => p_source_get_type
            ,p_source          => p_source_get
            ,p_items_per_page  => p_items_per_page
            ,p_mimes_allowed   => p_mimes_allowed
            ,p_comments        => p_handler_comments
         );
         
         IF str_header_name IS NOT NULL
         AND str_header_name != 'NA'
         THEN
            ORDS.DEFINE_PARAMETER(
                p_module_name        => p_module_name
               ,p_pattern            => p_pattern
               ,p_method             => 'GET'
               ,p_name               => str_header_name
               ,p_bind_variable_name => REPLACE(str_header_name,'-','_')
               ,p_source_type        => 'HEADER'
               ,p_param_type         => 'STRING'
               ,p_access_method      => 'IN'
               ,p_comments           => NULL
            );
            
         END IF;

      END IF;

      --------------------------------------------------------------------------
      -- Step 60
      -- Define the POST endpoint if requested
      --------------------------------------------------------------------------
      IF p_source_post IS NOT NULL
      THEN
         ORDS.DEFINE_HANDLER(
             p_module_name     => p_module_name
            ,p_pattern         => p_pattern
            ,p_method          => 'POST'
            ,p_source_type     => p_source_post_type
            ,p_source          => p_source_post
            ,p_items_per_page  => p_items_per_page
            ,p_mimes_allowed   => p_mimes_allowed
            ,p_comments        => p_handler_comments
         );
         
         IF str_header_name IS NOT NULL
         AND str_header_name != 'NA'
         THEN
            ORDS.DEFINE_PARAMETER(
                p_module_name        => p_module_name
               ,p_pattern            => p_pattern
               ,p_method             => 'POST'
               ,p_name               => str_header_name
               ,p_bind_variable_name => REPLACE(str_header_name,'-','_')
               ,p_source_type        => 'HEADER'
               ,p_param_type         => 'STRING'
               ,p_access_method      => 'IN'
               ,p_comments           => NULL
            );
            
         END IF;

      END IF;

      --------------------------------------------------------------------------
      -- Step 70
      -- Commit to close things out
      --------------------------------------------------------------------------
      ORDS.SET_MODULE_ORIGINS_ALLOWED(
          p_module_name     => p_module_name
         ,p_origins_allowed => str_origins_allowed
      );

      --------------------------------------------------------------------------
      -- Step 80
      -- Commit to close things out
      --------------------------------------------------------------------------
      COMMIT;

   END define_service;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE reject_request
   AS   
   BEGIN
      OWA_UTIL.MIME_HEADER('application/json',FALSE,'UTF-8');
      HTP.P('Status: 403 Forbidden');
      
      OWA_UTIL.HTTP_HEADER_CLOSE;
      
      HTP.P('{"return_code":403,"status_message":"forbidden"}');
      
   END reject_request;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE setup_ref_tables
   AS
      str_sql VARCHAR2(32000 Char);
      
   BEGIN
   
      str_sql := 'CREATE TABLE ref_env('
              || '    database_name VARCHAR2(4000 Char) NOT NULL '
              || '   ,environment   VARCHAR2(4000 Char) NOT NULL '
              || '   ,PRIMARY KEY (database_name) '
              || ') ';
              
      EXECUTE IMMEDIATE str_sql;
   
      str_sql := 'CREATE TABLE ref_origins('
              || '    service_match VARCHAR2(4000 Char) NOT NULL '
              || '   ,origins_list  VARCHAR2(4000 Char) '
              || '   ,PRIMARY KEY (service_match) '
              || ') ';
              
      EXECUTE IMMEDIATE str_sql;
      
      str_sql := 'CREATE TABLE ref_header_check('
              || '    header_name   VARCHAR2(4000 Char) NOT NULL '
              || '   ,header_value  VARCHAR2(4000 Char) NOT NULL '
              || '   ,PRIMARY KEY (header_name) '
              || ') ';
              
      EXECUTE IMMEDIATE str_sql;
   
   END setup_ref_tables;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_env
   RETURN VARCHAR2 RESULT_CACHE
   AS
      str_sql           VARCHAR2(32000 Char);
      str_env           VARCHAR2(4000 Char);
      str_dbname        VARCHAR2(4000 Char);
      
   BEGIN

      SELECT ora_database_name INTO str_dbname FROM dual;
      
      str_sql := 'SELECT '
              || 'a.environment '
              || 'FROM '
              || 'ref_env a '
              || 'WHERE '
              || 'a.database_name = :p01 ';
              
      EXECUTE IMMEDIATE str_sql 
      INTO str_env USING str_dbname;
      
      RETURN str_env;
   
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         -- if no entry in ref_env, assume prod
         RETURN 'prod';
         
      WHEN OTHERS
      THEN
         RAISE;
   
   END get_env;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_origins(
      p_service  IN  VARCHAR2 DEFAULT NULL
   ) RETURN VARCHAR2 RESULT_CACHE
   AS
      str_sql           VARCHAR2(32000 Char);
      str_service       VARCHAR2(4000 Char) := p_service;
      str_origins       VARCHAR2(4000 Char);
      
   BEGIN
      
      IF str_service IS NULL
      THEN
         str_service := '*';
         
      END IF;
      
      BEGIN
         str_sql := 'SELECT '
                 || 'a.origins_list '
                 || 'FROM '
                 || 'ref_origins a '
                 || 'WHERE '
                 || 'a.service_match = :p01 ';
         
         EXECUTE IMMEDIATE str_sql 
         INTO str_origins USING str_service;
         
         RETURN str_origins;
   
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            str_service := '*';
            
         WHEN OTHERS
         THEN
            IF SQLCODE = -942
            THEN
               RAISE_APPLICATION_ERROR(-20001,'ref_origins table is missing, execute setup_ref_tables to correct');
               
            ELSE
               RAISE;
            
            END IF;
            
      END;
      
      BEGIN
         str_sql := 'SELECT '
                 || 'a.origins_list '
                 || 'FROM '
                 || 'ref_origins a '
                 || 'WHERE '
                 || 'a.service_match = :p01 ';
         
         EXECUTE IMMEDIATE str_sql 
         INTO str_origins USING str_service;
         
         RETURN str_origins;
   
      EXCEPTION
         WHEN NO_DATA_FOUND
         THEN
            RETURN NULL;
            
         WHEN OTHERS
         THEN
            IF SQLCODE = -942
            THEN
               RAISE_APPLICATION_ERROR(-20001,'ref_origins table is missing, execute setup_ref_tables to correct');
               
            ELSE
               RAISE;
            
            END IF;
            
      END;
   
   END get_origins;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE fetch_header_info(
       out_header_name  OUT VARCHAR2
      ,out_header_value OUT VARCHAR2
   )
   AS
      str_sql           VARCHAR2(32000 Char);
      str_server        VARCHAR2(4000 Char);
      
   BEGIN
   
      str_sql := 'SELECT '
              || ' a.header_name '
              || ',a.header_value '
              || 'FROM '
              || 'ref_header_check a ';
           
      EXECUTE IMMEDIATE str_sql 
      INTO out_header_name,out_header_value;
      
      IF out_header_name IS NULL
      THEN
         RAISE_APPLICATION_ERROR(-20001,'header entry required, set NA to skip');
         
      END IF;

   EXCEPTION
   
      WHEN NO_DATA_FOUND
      THEN
         RAISE_APPLICATION_ERROR(-20001,'ref_header_check table is empty, add an NA record to skip header checking');
         
      WHEN OTHERS
      THEN
         IF SQLCODE = -942
         THEN
            RAISE_APPLICATION_ERROR(-20001,'ref_header_check table is missing, execute setup_ref_tables to correct');
            
         ELSE
            RAISE;
         
         END IF;
         
   END fetch_header_info;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION get_header_name
   RETURN VARCHAR2 RESULT_CACHE
   AS
      str_header_name   VARCHAR2(4000 Char);
      str_header_value  VARCHAR2(4000 Char);
      
   BEGIN
   
      fetch_header_info(str_header_name,str_header_value);
      
      RETURN str_header_name;
   
   END get_header_name;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION chk_header(
      p_header_value  IN  VARCHAR2
   ) RETURN BOOLEAN RESULT_CACHE
   AS
      str_header_name   VARCHAR2(4000 Char);
      str_header_value  VARCHAR2(4000 Char);
      
   BEGIN
   
      fetch_header_info(str_header_name,str_header_value);

      IF str_header_name IS NULL
      THEN
         -- header check not specified, deny for safety
         RETURN FALSE;
         
      ELSIF str_header_name = 'NA'
      THEN
         -- header check turned off via ref table
         RETURN TRUE;
      
      ELSIF p_header_value = str_header_value
      THEN
         -- headers match, allow
         RETURN TRUE;
         
      ELSE
         -- headers do not match, deny      
         RETURN FALSE;
         
      END IF;
   
   END chk_header;

END ords_util;
/

CREATE OR REPLACE PACKAGE iwtt_rest.iwtt_ords
AUTHID CURRENT_USER
AS
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE ords_all;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION owrap(
       p_service            IN  VARCHAR2
      ,p_method             IN  VARCHAR2
   ) RETURN CLOB;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION ocode(
       p_service            IN  VARCHAR2
      ,p_method             IN  VARCHAR2
   ) RETURN CLOB;
   
END iwtt_ords;
/

CREATE OR REPLACE PACKAGE BODY iwtt_rest.iwtt_ords
AS

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   PROCEDURE ords_all
   AS
   BEGIN

      ords_util.define_service(
          p_module_name     => 'healthcheck'
         ,p_base_path       => 'healthcheck/'
         ,p_source_get_type => ORDS.SOURCE_TYPE_QUERY_ONE_ROW
         ,p_source_get      => 'SELECT 0 AS "result" FROM dual'
         ,p_source_post     => NULL
      );
      ords_util.define_service(
          p_module_name  => 'art_search_csvv01'
         ,p_base_path    => 'v1/art_search_csv/'
         ,p_source_get   => owrap('art_search_csvv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'art_search_jsonv01'
         ,p_base_path    => 'v1/art_search_json/'
         ,p_source_get   => owrap('art_search_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'guid_search_d_csvv01'
         ,p_base_path    => 'v1/guid_search_d_csv/'
         ,p_source_get   => owrap('guid_search_d_csvv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'guid_search_i_csvv01'
         ,p_base_path    => 'v1/guid_search_i_csv/'
         ,p_source_get   => owrap('guid_search_i_csvv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'guid_search_jsonv01'
         ,p_base_path    => 'v1/guid_search_json/'
         ,p_source_get   => owrap('guid_search_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'guid_search_p_csvv01'
         ,p_base_path    => 'v1/guid_search_p_csv/'
         ,p_source_get   => owrap('guid_search_p_csvv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'guid_search_raw'
         ,p_base_path    => 'v1/guid_search_raw/'
         ,p_source_get   => owrap('guid_search_raw','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'guid_search_t_csvv01'
         ,p_base_path    => 'v1/guid_search_t_csv/'
         ,p_source_get   => owrap('guid_search_t_csvv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'lookup_doc_type_jsonv01'
         ,p_base_path    => 'v1/lookup_doc_type_json/'
         ,p_source_get   => owrap('lookup_doc_type_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'lookup_industry_jsonv01'
         ,p_base_path    => 'v1/lookup_industry_json/'
         ,p_source_get   => owrap('lookup_industry_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'lookup_motiv_cat_jsonv01'
         ,p_base_path    => 'v1/lookup_motiv_cat_json/'
         ,p_source_get   => owrap('lookup_motiv_cat_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'lookup_naics_jsonv01'
         ,p_base_path    => 'v1/lookup_naics_json/'
         ,p_source_get   => owrap('lookup_naics_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'lookup_parameter_jsonv01'
         ,p_base_path    => 'v1/lookup_parameter_json/'
         ,p_source_get   => owrap('lookup_parameter_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'lookup_sic_jsonv01'
         ,p_base_path    => 'v1/lookup_sic_json/'
         ,p_source_get   => owrap('lookup_sic_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'lookup_treat_tech_jsonv01'
         ,p_base_path    => 'v1/lookup_treat_tech_json/'
         ,p_source_get   => owrap('lookup_treat_tech_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'lookup_year_jsonv01'
         ,p_base_path    => 'v1/lookup_year_json/'
         ,p_source_get   => owrap('lookup_year_jsonv01','get')
         ,p_source_post  => NULL
      );
      ords_util.define_service(
          p_module_name  => 'report_jsonv01'
         ,p_base_path    => 'v1/report_json/'
         ,p_source_get   => owrap('report_jsonv01','get')
         ,p_source_post  => NULL
      );

   END ords_all;
   
   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION owrap(
       p_service            IN  VARCHAR2
      ,p_method             IN  VARCHAR2
   ) RETURN CLOB
   AS
      str_results CLOB;
      str_header  VARCHAR2(4000);
      
   BEGIN
   
      str_header := ords_util.get_header_name();
   
      str_results := q'[
         DECLARE
            boo_check BOOLEAN;
      ]';
      
      IF p_method IN ('post')
      THEN
         str_results := str_results || q'[
            dict_body ords_util.param_dict;
         ]';
         
      END IF;
      
      str_results := str_results || q'[
         BEGIN
      ]';
      
      IF p_method IN ('post')
      THEN
         str_results := str_results || q'[
            dict_body := ords_util.body_parse(:body_text);
         ]';
         
      END IF;
      
      IF str_header = 'NA'
      THEN
         str_results := str_results || q'[
            IF 1=1
            THEN
         ]';
         
      ELSE
         str_results := str_results 
                     || '      '
                     || 'boo_check := ords_util.chk_header(:' || REPLACE(str_header,'-','_') || ');';
         
         str_results := str_results || q'[
            
            IF boo_check
            THEN
         ]';
         
      END IF;
      
      str_results := str_results || ocode(p_service,p_method);
      
      str_results := str_results || q'[
            ELSE
               ords_util.reject_request();
               
            END IF;
      ]';
      
      IF ords_util.get_env() IN ('stage','dev')
      THEN         
         str_results := str_results || q'[
         EXCEPTION
            WHEN OTHERS
            THEN
               HTP.P(SQLERRM);
         
         ]';
         
      END IF;

      str_results := str_results || q'[     
         END;
      ]';
      
      RETURN str_results;
   
   END owrap;

   -----------------------------------------------------------------------------
   -----------------------------------------------------------------------------
   FUNCTION ocode(
       p_service            IN  VARCHAR2
      ,p_method             IN  VARCHAR2
   ) RETURN CLOB
   AS
   BEGIN
      
      IF    p_service = 'art_search_csvv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.art_search_csvv01(
                p_point_source_category_code    => :p_point_source_category_code
               ,p_point_source_category_desc    => :p_point_source_category_desc
               ,p_treatment_technology_code     => :p_treatment_technology_code
               ,p_treatment_technology_desc     => :p_treatment_technology_desc
               ,p_treatment_scale               => :p_treatment_scale
               ,p_pollutant_search_term         => :p_pollutant_search_term
               ,p_pollutant_search_term_wc      => :p_pollutant_search_term_wc
               ,p_percent_removal_flag          => :p_percent_removal_flag
               ,p_percent_min                   => :p_percent_min
               ,p_percent_max                   => :p_percent_max
               ,p_sic                           => :p_sic
               ,p_naics                         => :p_naics
               ,p_year_min                      => :p_year_min
               ,p_year_max                      => :p_year_max
               ,p_motivation_category           => :p_motivation_category
               ,p_document_type                 => :p_document_type
               ,p_keyword                       => :p_keyword
               ,p_author                        => :p_author
               ,p_filename_override             => :p_filename_override
               ,p_add_bom                       => :p_add_bom
               ,f                               => :f
               ,api_key                         => :api_key
            );
         ]';

      ELSIF p_service = 'art_search_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.art_search_jsonv01(
                p_point_source_category_code    => :p_point_source_category_code
               ,p_point_source_category_desc    => :p_point_source_category_desc
               ,p_treatment_technology_code     => :p_treatment_technology_code
               ,p_treatment_technology_desc     => :p_treatment_technology_desc
               ,p_treatment_scale               => :p_treatment_scale
               ,p_pollutant_search_term         => :p_pollutant_search_term
               ,p_pollutant_search_term_wc      => :p_pollutant_search_term_wc
               ,p_percent_removal_flag          => :p_percent_removal_flag
               ,p_percent_min                   => :p_percent_min
               ,p_percent_max                   => :p_percent_max
               ,p_sic                           => :p_sic
               ,p_naics                         => :p_naics
               ,p_year_min                      => :p_year_min
               ,p_year_max                      => :p_year_max
               ,p_motivation_category           => :p_motivation_category
               ,p_document_type                 => :p_document_type
               ,p_keyword                       => :p_keyword
               ,p_author                        => :p_author
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            );   
         ]';

      ELSIF p_service = 'guid_search_d_csvv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.guid_search_d_csvv01(
                p_point_source_category_code    => :p_point_source_category_code
               ,p_point_source_category_desc    => :p_point_source_category_desc
               ,p_treatment_technology_code     => :p_treatment_technology_code
               ,p_treatment_technology_desc     => :p_treatment_technology_desc
               ,p_pollutant_search_term         => :p_pollutant_search_term
               ,p_pollutant_search_term_wc      => :p_pollutant_search_term_wc
               ,p_parameter_desc                => :p_parameter_desc
               ,p_filename_override             => :p_filename_override
               ,p_add_bom                       => :p_add_bom
               ,f                               => :f
               ,api_key                         => :api_key
            ); 
         ]';

      ELSIF p_service = 'guid_search_i_csvv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.guid_search_i_csvv01(
                p_point_source_category_code    => :p_point_source_category_code
               ,p_point_source_category_desc    => :p_point_source_category_desc
               ,p_treatment_technology_code     => :p_treatment_technology_code
               ,p_treatment_technology_desc     => :p_treatment_technology_desc
               ,p_pollutant_search_term         => :p_pollutant_search_term
               ,p_pollutant_search_term_wc      => :p_pollutant_search_term_wc
               ,p_parameter_desc                => :p_parameter_desc
               ,p_filename_override             => :p_filename_override
               ,p_add_bom                       => :p_add_bom
               ,f                               => :f
               ,api_key                         => :api_key
            );  
         ]';

      ELSIF p_service = 'guid_search_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.guid_search_jsonv01(
                p_point_source_category_code    => :p_point_source_category_code
               ,p_point_source_category_desc    => :p_point_source_category_desc
               ,p_treatment_technology_code     => :p_treatment_technology_code
               ,p_treatment_technology_desc     => :p_treatment_technology_desc
               ,p_pollutant_search_term         => :p_pollutant_search_term
               ,p_pollutant_search_term_wc      => :p_pollutant_search_term_wc
               ,p_parameter_desc                => :p_parameter_desc
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            );
         ]';

      ELSIF p_service = 'guid_search_p_csvv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.guid_search_p_csvv01(
                p_point_source_category_code    => :p_point_source_category_code
               ,p_point_source_category_desc    => :p_point_source_category_desc
               ,p_treatment_technology_code     => :p_treatment_technology_code
               ,p_treatment_technology_desc     => :p_treatment_technology_desc
               ,p_pollutant_search_term         => :p_pollutant_search_term
               ,p_pollutant_search_term_wc      => :p_pollutant_search_term_wc
               ,p_parameter_desc                => :p_parameter_desc
               ,p_filename_override             => :p_filename_override
               ,p_add_bom                       => :p_add_bom
               ,f                               => :f
               ,api_key                         => :api_key
            );  
         ]';

      ELSIF p_service = 'guid_search_raw'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.guid_search_raw(
                p_point_source_category_code => :p_point_source_category_code
               ,p_point_source_category_desc => :p_point_source_category_desc
               ,p_treatment_technology_code  => :p_treatment_technology_code
               ,p_treatment_technology_desc  => :p_treatment_technology_desc
               ,p_pollutant_search_term      => :p_pollutant_search_term
               ,p_pollutant_search_term_wc   => :p_pollutant_search_term_wc
               ,p_parameter_desc             => :p_parameter_desc
               ,p_filename_override          => :p_filename_override
               ,p_add_bom                    => :p_add_bom
               ,f                            => :f
               ,api_key                      => :api_key
            );
         ]';

      ELSIF p_service = 'guid_search_t_csvv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.guid_search_t_csvv01(
                p_point_source_category_code    => :p_point_source_category_code
               ,p_point_source_category_desc    => :p_point_source_category_desc
               ,p_treatment_technology_code     => :p_treatment_technology_code
               ,p_treatment_technology_desc     => :p_treatment_technology_desc
               ,p_pollutant_search_term         => :p_pollutant_search_term
               ,p_pollutant_search_term_wc      => :p_pollutant_search_term_wc
               ,p_parameter_desc                => :p_parameter_desc
               ,p_filename_override             => :p_filename_override
               ,p_add_bom                       => :p_add_bom
               ,f                               => :f
               ,api_key                         => :api_key
            );
               
         ]';

      ELSIF p_service = 'lookup_doc_type_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.lookup_document_type_jsonv01(
                p_document_type                 => :p_document_type
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            ); 
         ]';

      ELSIF p_service = 'lookup_industry_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.lookup_industry_jsonv01(
                p_industry_id                   => :p_industry_id
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            ); 
         ]';

      ELSIF p_service = 'lookup_motiv_cat_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.lookup_motivation_cat_jsonv01(
                p_motivation_cat                => :p_motivation_cat
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            );
         ]';

      ELSIF p_service = 'lookup_naics_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.lookup_naics_jsonv01(
                p_naics_code                    => :p_naics_code
               ,p_naics_desc                    => :p_naics_desc
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            ); 
         ]';

      ELSIF p_service = 'lookup_parameter_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.lookup_parameter_jsonv01(
                p_pollutant_search_term         => :p_pollutant_search_term
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            );  
         ]';

      ELSIF p_service = 'lookup_sic_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.lookup_sic_jsonv01(
                p_sic_code                      => :p_sic_code
               ,p_sic_desc                      => :p_sic_desc
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            ); 
         ]';

      ELSIF p_service = 'lookup_treat_tech_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.lookup_treatment_tech_jsonv01(
                p_treatment_technology_code     => :p_treatment_technology_code
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            );
         ]';

      ELSIF p_service = 'lookup_year_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.lookup_year_jsonv01(
                p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            ); 
         ]';

      ELSIF p_service = 'report_jsonv01'
      AND   p_method = 'get'
      THEN
         RETURN q'[
            iwtt.iwtt_services.report_jsonv01(
                p_ref_id                        => :p_ref_id
               ,p_pretty_print                  => :p_pretty_print
               ,f                               => :f
               ,api_key                         => :api_key
            );
         ]';

      ELSE
         RAISE_APPLICATION_ERROR(-20001,'err ' || p_service || ':' || p_method);
      
      END IF; 

   END ocode;

END iwtt_ords;
/

BEGIN
   ords_util.setup_ref_tables();
   
END;
/

BEGIN
   
   INSERT INTO ref_env(
       database_name
      ,environment
   ) VALUES (
       (SELECT ora_database_name FROM dual)
      ,'stage'
   );

   INSERT INTO ref_origins(
       service_match
      ,origins_list
   ) VALUES (
       '*'
      ,'http://localhost'
   );

   INSERT INTO ref_header_check(
       header_name
      ,header_value
   ) VALUES (
       'NA'
      ,'NA'
   );

   COMMIT;
   
END;
/

BEGIN
   
   ORDS.ENABLE_SCHEMA(
      p_url_mapping_pattern => 'iwtt'
   );
   COMMIT;
   
   iwtt_ords.ords_all();
   
END;
/

