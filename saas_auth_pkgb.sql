


/*
   ToDo List
   ---------
   * Add ability to change email (pass will need to be re-encrypted).
   * Send email when account is registered to confirm.
   * Work on is_admin and is_user.
   * Add social proof.
   * Limit use of table to specific apps if > 1 app in same user workspace.
   * Send email anytime password or email is changed.
   * Add config parms for password attributes and anything else I can think of.
   * Add "we sent you a secret token X minutes ago..."
   * Build ArcSQL rate limiter.
   * Have I been pwnd integration.
   * Consider using original email and logging all email changes.
   * Update form so email and user name are shown or only email which then is used as user name.
   * Add terms of service agreement.
   * Add a button which allows user to temporarily login without credentials for testing/preview.
*/

create or replace package body saas_auth_pkg as

function custom_hash (
   p_user_name in varchar2,
   p_password in varchar2) return raw is
   -- Returns SHA256 hash we will store in the password field.
   -- User name will be converted to lower-case to ensure consistency.
   v_password varchar2(100);
   v_salt     varchar2(100) := arcsql.get_setting('saas_auth_salt');
begin
   -- If email address is used we will always need to use original_email or email change would break password.
   -- To change email we will likely need to provide a link which allows the user to auth
   -- and then set up a new password.
   v_password := arcsql.encrypt_sha256(v_salt || p_password || p_user_name);
   return v_password;
end;

procedure set_error_message (p_message in varchar2) is 
begin 
   apex_error.add_error (
      p_message          => p_message,
      p_display_location => apex_error.c_inline_in_notification );
end;

procedure raise_email_already_exists (
   p_user_name in varchar2) is 
   n number;
begin 
   select count(*) into n 
      from saas_auth
     where email=lower(p_user_name);
   if n > 0 then 
      set_error_message('User is already registered.');
      raise_application_error(-20001, 'User is already registered.');
   end if;
end;

procedure raise_user_already_exists (
   p_user_name in varchar2) is 
   n number;
begin 
   select count(*) into n 
      from saas_auth
     where user_name=lower(p_user_name);
   if n > 0 then 
      set_error_message('User name already exists. Try using a different one.');
      raise_application_error(-20001, 'User name already exists.');
   end if;
end;

procedure raise_not_an_email (p_email in varchar2) is 
begin 
   if not arcsql.str_is_email(p_email) then 
      set_error_message('Email does not appear to be a valid email address.');
      raise_application_error(-20001, 'Email does not appear to be a valid email address.');
   end if;
end;

procedure add_user (
   p_user_name in varchar2,
   p_email in varchar2,
   p_password in varchar2) is
   v_message varchar2(4000);
   v_password raw(64);
   v_user_id number;
   v_email varchar2(120) := lower(p_email);
   v_user_name varchar2(120) := lower(p_user_name);
begin
   arcsql.debug('add_user: '||p_user_name||'~'||v_email);
   raise_not_an_email(v_email);
   raise_user_already_exists(v_email);
   v_password := custom_hash(p_user_name=>p_user_name, p_password=>p_password);
   insert into saas_auth (
      user_name,
      email, 
      original_email,
      role_id,
      password) values (
      v_user_name,
      v_email, 
      v_email,
      1,
      v_password);
end;

procedure delete_user (
   p_user_name in varchar2) is 
begin 
   delete from saas_auth where user_name=lower(p_user_name);
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
   --    * Build this.
   -- arcsql.raise_rate_limit(p_key=>'create_account', p_per_minute=>200, p_per_hour=>1000);
   raise_user_already_exists(v_user_name);
   if p_password != p_confirm then 
      set_error_message('Passwords do not match.');
      raise_application_error(-20001, 'Passwords do not match.');
   end if;
   raise_bad_password(p_password);
   add_user(
      p_user_name=>v_user_name,
      p_email=>v_email,
      p_password=>p_password);
   -- We don't need a real password here.
   v_password := utl_raw.cast_to_raw(dbms_random.string('x',10));
   apex_authentication.post_login (
      p_username=>lower(v_user_name), 
      p_password=>p_password);
end;

function custom_auth (
   p_username in varchar2,
   p_password in varchar2) return boolean is
   v_password varchar2(100);
   v_stored_password varchar2(100);
   v_username varchar2(120) := lower(p_username);
begin
   arcsql.debug('custom_auth: '||v_username||', '||p_password);
   -- First, check to see if the user is in the user table and look up their password
   begin
     select password
       into v_stored_password
       from saas_auth
      where user_name=v_username;
   exception 
      when others then 
         arcsql.debug('custom_auth: '||dbms_utility.format_error_stack);
         raise;
   end;
   -- Hash the password the person entered
   v_password := custom_hash(v_username, p_password);
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
       where user_name=v_username;
      arcsql.debug('custom_auth: true');
      return true;
   else
      update saas_auth 
         set reset_pass_token=null, 
             reset_pass_expire=null,
             last_failed_login=sysdate,
             failed_login_count=failed_login_count+1,
             last_session_id=v('APP_SESSION')
       where user_name=v_username;
      arcsql.debug('custom_auth: false');
      return false;
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
begin 
   arcsql.debug('send_reset_pass_token: '||p_email);
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
   v_app_name := apex_application.g_flow_name;
   sendgrid.send_message(
      to_address=>p_email,
      subject=>'Thanks for using '||v_app_name||'!',
      message=>v_app_name||': The secret token you need to reset your password is '||v_token);
end;

procedure reset_password (
   p_token in varchar2,
   p_password in varchar2,
   p_confirm in varchar2) is 
   v_hashed_password varchar2(100);
   n number;
   v_original_email varchar2(120);
begin
   select count(*) into n 
     from saas_auth 
    where reset_pass_token=p_token 
      and reset_pass_expire > sysdate;
   if n=0 then 
      set_error_message('Invalid or expired password reset token.');
      raise_application_error(-20001, 'Invalid or expired password reset token.');
   end if;
   if p_password != p_confirm then 
      set_error_message('Passwords do not match.');
      raise_application_error(-20001, 'Passwords do not match.');
   end if;
   raise_bad_password(p_password);
   select lower(original_email) into v_original_email 
     from saas_auth 
    where reset_pass_token=p_token;
   v_hashed_password := custom_hash(v_original_email, p_password);
   update saas_auth
      set password=v_hashed_password,
          reset_pass_expire=null,
          reset_pass_token=null
    where reset_pass_token=p_token;
end;

function is_admin (
    p_user_name in varchar2)
  return boolean
is
  l_is_admin varchar2(1);
begin
  select 'Y'
    into l_is_admin
    from saas_auth a
   where a.email=lower(p_user_name)
     and a.role_id=2;
  return true;
exception
when no_data_found then
  return false;
end;

--    * Not implemented yet.
function is_user(
    p_user_name in varchar2)
  return boolean
is
  l_is_user varchar2(1);
begin
  select 'Y'
    into l_is_user
    from saas_auth a
   where a.email=lower(p_user_name)
     and a.role_id in (1,2);
  return true;
exception
when no_data_found then
  return false;
end;

end;
/