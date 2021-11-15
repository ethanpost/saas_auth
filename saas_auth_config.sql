
create or replace package saas_auth_config as 
   saas_auth_from_address varchar2(120) := 'foo@bar.com';
   saas_auth_salt varchar2(120) := 'My secret authorization phrase.';
   saas_auth_test_pass varchar2(120) := 'TestPass123$';
end;
/
