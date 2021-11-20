

-- This procedure will get called anytime a new account is created.

-- uninstall: exec drop_procedure('on_create_account');
create or replace procedure on_create_account (p_user_id in number) as 
begin
   arcsql.debug('on_create_account: '||p_user_id); 
   null;
end;
/


-- uninstall: exec drop_procedure('on_delete_account');
create or replace procedure on_delete_account (p_user_id in number) as 
begin
   arcsql.debug('on_delete_account: '||p_user_id); 
   null;
end;
/


-- uninstall: exec drop_procedure('on_login');
create or replace procedure on_login (p_user_id in number) as 
begin
   arcsql.debug('on_login: '||p_user_id); 
   null;
end;
/

