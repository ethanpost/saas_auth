


/*
   ToDo List
   ---------
   * Add ability to change email (pass will need to be re-encrypted).
   * Send email when account is registered to confirm.
   * Work on is_admin and is_user. (change to has_role or something)
   * Add social proof.
   * Limit use of table to specific apps if > 1 app in same user workspace.
   * Send email anytime password or email is changed.
   * Add config parms for password attributes and anything else I can think of.
   * Add "we sent you a secret token X minutes ago..."
   * Have I been pwnd integration.
   * Update form so email and user name are shown or only email which then is used as user name.
   * Add terms of service agreement.
   * Add a button which allows user to temporarily login without credentials for testing/preview.
*/

create or replace package body saas_auth_pkg as


procedure set_error_message (p_message in varchar2) is 
begin 
   apex_error.add_error (
      p_message          => p_message,
      p_display_location => apex_error.c_inline_in_notification );
end;


procedure raise_auth_request_rate_exceeded is 
begin 
  if arcsql.get_request_count(p_request_key=>'saas_auth', p_min=>1) > 20 then
     set_error_message('Allowed request rate exceeded.');
     raise_application_error(-20001, 'Allowed request rate exceeded.');
     apex_util.pause(1);
  end if;
end;


function custom_hash (
   p_user_name in varchar2,
   p_password in varchar2) return raw is
   -- Returns SHA256 hash we will store in the password field.
   -- User name will be converted to lower-case to ensure consistency.
   v_password varchar2(100);
   v_salt     varchar2(100) := saas_auth_config.saas_auth_salt;
begin
   v_password := arcsql.encrypt_sha256(v_salt || p_password || p_user_name);
   return v_password;
end;

function does_email_already_exist (
   p_email in varchar2) return boolean is
   n number;
begin
   arcsql.debug('does_email_already_exist: email='||p_email);
   select count(*) into n 
      from saas_auth
     where email=lower(p_email);
   if n > 0 then 
      return true;
   else
      return false;
   end if;
end;


procedure raise_email_already_exists (
   p_email in varchar2) is 
   -- Raises error if the email address exists.
   n number;
begin 
   if does_email_already_exist(p_email) then
      set_error_message('User is already registered.');
      raise_application_error(-20001, 'User is already registered.');
   end if;
end;


function is_user (
   p_user_name in varchar2) return boolean is
   n number;
   v_lower_user_name saas_auth.user_name%type := lower(p_user_name);
begin 
   arcsql.debug('is_user: '||v_lower_user_name);
   select count(*) into n 
      from saas_auth
     where user_name=v_lower_user_name;
   if n = 1 then 
      return true;
   else
      return false;
   end if;
end;


procedure raise_user_found (
   p_user_name in varchar2) is 
   -- Raises error if user exists.
   n number;
begin 
   if is_user(p_user_name) then
      set_error_message('User name already exists. Try using a different one.');
      raise_application_error(-20001, 'User name already exists.');
   end if;
end;


procedure raise_user_not_found (
   p_user_name in varchar2) is 
   -- Raises error if user is not found.
   n number;
begin 
   if not is_user(p_user_name) then
      set_error_message('User not found.');
      raise_application_error(-20001, 'raise_user_not_found: '||p_user_name);
   end if;
end;


function get_user_id (p_user_name in varchar2) return number is 
    n number;
    v_lower_user_name saas_auth.user_name%type := lower(p_user_name);
begin 
   if is_user(v_lower_user_name) then 
       select user_id into n from saas_auth where user_name = v_lower_user_name;
   else 
      raise_application_error(-20001, 'get_user_id: User '''||v_lower_user_name||''' not found.');
   end if;
   return n;
end;


procedure raise_not_an_email (p_email in varchar2) is 
begin 
   if not arcsql.str_is_email(p_email) then 
      set_error_message('Email does not appear to be a valid email address.');
      raise_application_error(-20001, 'Email does not appear to be a valid email address.');
   end if;
end;


-- Add a user which is only accessible in dev mode.
procedure add_test_user (
   p_user_name in varchar2,
   -- If email is not provided it is assumed the user name is an email address.
   p_email in varchar2 default null) is 

   v_email varchar2(120) := p_email;
   test_pass varchar2(120);
begin
   arcsql.debug('add_test_user: '||p_user_name);
   test_pass := saas_auth_config.saas_auth_test_pass;
   if v_email is null then 
      v_email := p_user_name;
   end if;
   if not is_user(p_user_name=>p_user_name) then
      add_user (
         p_user_name=>p_user_name,
         p_email=>v_email,
         p_password=>test_pass,
         p_is_test_user=>true);
   end if;
end;


procedure fire_create_account(p_user_id in varchar2) is 
   n number;
begin 
   select count(*) into n from user_source 
    where name = 'ON_CREATE_ACCOUNT'
      and type='PROCEDURE';
   if n > 0 then 
      arcsql.debug('fire_create_account: '||p_user_id);
      execute immediate 'begin on_create_account('||p_user_id||'); end;';
   end if;
end;
    

procedure add_user (
   p_user_name in varchar2,
   p_email in varchar2,
   p_password in varchar2,
   p_is_test_user in boolean default false) is
   v_message varchar2(4000);
   v_password raw(64);
   v_user_id number;
   v_email varchar2(120) := lower(p_email);
   v_user_name varchar2(120) := lower(p_user_name);
   v_is_test_user varchar2(1) := 'n';
begin
   arcsql.debug('add_user: '||p_user_name||'~'||v_email);
   raise_not_an_email(v_email);
   raise_user_found(p_user_name=>v_email);
   v_password := custom_hash(p_user_name=>p_user_name, p_password=>p_password);
   if p_is_test_user then 
      v_is_test_user := 'y';
   end if;
   insert into saas_auth (
      user_name,
      email, 
      role_id,
      password,
      last_session_id,
      is_test_user) values (
      v_user_name,
      v_email, 
      1,
      v_password,
      v('APP_SESSION'),
      v_is_test_user);
   v_user_id := get_user_id(p_user_name=>lower(v_user_name));
   fire_create_account(v_user_id);
end;


procedure delete_user (
   p_user_name in varchar2) is 
begin 
   delete from saas_auth 
    where user_name=lower(p_user_name);
end;


procedure raise_bad_password (
   p_password in varchar2) is 
begin 
   if not arcsql.str_complexity_check(text=>p_password, chars=>8) then 
      set_error_message('Password needs to be at least 8 characters long.');
      raise_application_error(-20001, 'Password needs to be at least 8 characters long.');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, uppercase=>1) then 
      set_error_message('Password needs at least 1 upper-case character.');
      raise_application_error(-20001, 'Password needs at least 1 upper-case character.');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, lowercase=>1) then 
      set_error_message('Password needs at least 1 lower-case character.');
      raise_application_error(-20001, 'Password needs at least 1 lower-case character.');
   end if;
   if not arcsql.str_complexity_check(text=>p_password, digit=>1) then 
      set_error_message('Password needs at least 1 digit.');
      raise_application_error(-20001, 'Password needs at least 1 digit.');
   end if;
end;


procedure create_account (
   p_user_name in varchar2,
   p_email in varchar2,
   p_password in varchar2,
   p_confirm in varchar2) is
   v_message varchar2(4000);
   v_user_name varchar2(120) := lower(p_user_name);
   v_email varchar2(120) := lower(p_email);
   v_password raw(64);
   v_user_id number;
begin
   arcsql.debug('create_account: '||lower(p_email));
   arcsql.count_request(p_request_key=>'saas_auth', p_sub_key=>'create_account');
   raise_auth_request_rate_exceeded;
   raise_user_found(p_user_name=>v_user_name);
   if p_password != p_confirm then 
      set_error_message('Passwords do not match.');
      raise_application_error(-20001, 'Passwords do not match.');
   end if;
   raise_bad_password(p_password);
   add_user (
      p_user_name=>v_user_name,
      p_email=>v_email,
      p_password=>p_password);
   -- We don't need a real password here.
   v_password := utl_raw.cast_to_raw(dbms_random.string('x',10));
   apex_authentication.post_login (
      p_username=>lower(v_user_name), 
      p_password=>p_password);
end;


procedure fire_login(p_user_id in varchar2) is 
   n number;
begin 
   select count(*) into n from user_source 
    where name = 'ON_LOGIN'
      and type='PROCEDURE';
   if n > 0 then 
      arcsql.debug('fire_login: '||p_user_id);
      execute immediate 'begin on_login('||p_user_id||'); end;';
   end if;
end;


function custom_auth (
   p_username in varchar2,
   p_password in varchar2) return boolean is
   v_password varchar2(100);
   v_stored_password varchar2(100);
   v_user_name varchar2(120) := lower(p_username);
   v_user_id number;
begin
   arcsql.debug('custom_auth: '||v_user_name||', '||p_password);
   arcsql.count_request(p_request_key=>'saas_auth', p_sub_key=>'custom_auth');
   raise_auth_request_rate_exceeded;
   raise_user_not_found(p_username);
   select password, user_id
     into v_stored_password, v_user_id
     from saas_auth
    where user_name=v_user_name;
   -- Hash the password the person entered
   v_password := custom_hash(v_user_name, p_password);
   -- Finally, we compare them to see if they are the same and return either TRUE or FALSE
   -- arcsql.debug('v_stored_password: '||v_stored_password);
   -- arcsql.debug('v_password: '||v_password);
   if v_password=v_stored_password then
      update saas_auth 
         set reset_pass_token=null, 
             reset_pass_expire=null,
             last_login=sysdate,
             login_count=login_count+1,
             last_session_id=v('APP_SESSION')
       where user_name=v_user_name;
      arcsql.debug('custom_auth: true');
      fire_login(v_user_id);
      return true;
   else
      update saas_auth 
         set reset_pass_token=null, 
             reset_pass_expire=null,
             last_failed_login=sysdate,
             failed_login_count=failed_login_count+1,
             last_session_id=v('APP_SESSION')
       where user_name=v_user_name;
      arcsql.debug('custom_auth: false');
      return false;
      -- ToDo: May want to add fire_failed_login event here.
   end if;
exception
   when no_data_found then
      return false;
end;


procedure post_auth is
   cursor package_names is 
   -- Looks for any procedure name called "post_auth" in any user owned
   -- packages and executes the procedure. This allows you to write your
   -- own post_auth events. Ideally it would be nice to pass the user name.
   select name from user_source 
    where lower(text) like '% post_auth;%'
      and name not in ('SAAS_AUTH_PKG')
      and type='PACKAGE';
begin
   arcsql.debug('post_auth: saas_auth_pkg');
   for n in package_names loop 
      arcsql.debug('post_auth: '||n.name||'.post_auth');
      execute immediate 'begin '||n.name||'.post_auth; end;';
   end loop;
end;


procedure send_reset_pass_token (
   p_email in varchar2) is 
   n number;
   v_token varchar2(120);
   v_app_name varchar2(120);
   v_from_address varchar2(120);
begin 
   arcsql.debug('send_reset_pass_token: '||p_email);
   arcsql.count_request(p_request_key=>'saas_auth', p_sub_key=>'send_reset_pass_token');
   raise_auth_request_rate_exceeded;
   select count(*) into n from saas_auth where email=lower(p_email);
   if n=0 then 
      set_error_message('Email not found. Check the address and try again or contact support.');
      raise_application_error(-20001, 'Email not found. Check the address and try again or contact support.');
   end if;
   while 1=1 loop 
      v_token := arcsql.str_random(8, 'an');
      select count(*) into n from saas_auth where reset_pass_token=v_token;
      if n=0 then 
         exit;
      end if;
   end loop;
   update saas_auth 
      set reset_pass_token=v_token,
          reset_pass_expire=sysdate+15/1440,
          last_session_id=v('APP_SESSION')
    where email=lower(p_email);
   v_app_name := arcsql.apex_get_app_name;
   v_from_address := saas_auth_config.saas_auth_from_address;
   send_email (
      p_to=>p_email,
      p_from=>v_from_address,
      p_subject=>'Thanks for using '||v_app_name||'!',
      p_body=>v_app_name||': The secret token you need to reset your password is '||v_token);
end;


procedure reset_password (
   p_token in varchar2,
   p_password in varchar2,
   p_confirm in varchar2) is 
   v_hashed_password varchar2(100);
   n number;
   v_user_name varchar2(120);
begin
   arcsql.count_request(p_request_key=>'saas_auth', p_sub_key=>'reset_password');
   raise_auth_request_rate_exceeded;
   select count(*) into n 
     from saas_auth 
    where reset_pass_token=p_token 
      and reset_pass_expire > sysdate;
   if n=0 then 
      set_error_message('Your token is either expired of invalid.');
      raise_application_error(-20001, 'Invalid password reset token.');
   end if;
   if p_password != p_confirm then 
      set_error_message('Passwords do not match.');
      raise_application_error(-20001, 'Passwords do not match.');
   end if;
   raise_bad_password(p_password);
   select lower(user_name) into v_user_name 
     from saas_auth 
    where reset_pass_token=p_token;
   v_hashed_password := custom_hash(v_user_name, p_password);
   update saas_auth
      set password=v_hashed_password,
          reset_pass_expire=null,
          reset_pass_token=null
    where reset_pass_token=p_token;
end;


function is_signed_in return boolean is 
begin 
   if lower(v('APP_USER')) not in ('guest', 'nobody') then 
      return true;
   else 
      return false;
   end if;
end;


function is_not_signed_in return boolean is 
begin 
   if lower(v('APP_USER')) in ('guest', 'nobody') then 
      return true;
   else 
      return false;
   end if;
end;


function is_admin (
   p_user_id in number) return boolean is
   x varchar2(1);
begin
   select 'Y'
    into x
    from saas_auth a
   where user_id=p_user_id
     and a.role_id=(select role_id from saas_auth_role where role_name='admin');
   return true;
exception
   when no_data_found then
      return false;
end;


-- -- * Not implemented yet.
-- function is_user (
--     p_user_name in varchar2)
--   return boolean
-- is
--   l_is_user varchar2(1);
-- begin
--   select 'Y'
--     into l_is_user
--     from saas_auth a
--    where a.email=lower(p_user_name)
--      and a.role_id in (1,2);
--   return true;
-- exception
-- when no_data_found then
--   return false;
-- end;


procedure login_with_new_demo_account is 
   v_user varchar2(120);
   v_pass varchar2(120);
   n number;
begin 
   -- Generate a random demo user and password.
   v_user := 'Demo'||arcsql.str_random(5, 'a');
   v_pass := 'FooBar'||arcsql.str_random(5)||'@foo$';
   select count(*) into n 
     from saas_auth 
    where last_session_id=v('APP_SESSION') 
      and created >= sysdate-(.1/1440);
   if n = 0 then 
      saas_auth_pkg.create_account (
         p_user_name=>v_user,
         p_email=>v_user||'@null.com',
         p_password=>v_pass,
         p_confirm=>v_pass);
      apex_authentication.login(
         p_username => v_user,
         p_password => v_pass);
      post_auth;
   else 
      apex_error.add_error ( 
         p_message=>'Please wait 10 seconds before trying to create a new account.',
         p_display_location=>apex_error.c_inline_in_notification);
   end if;
end;


end;
/
