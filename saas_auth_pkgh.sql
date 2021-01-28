
-- uninstall: drop package saas_auth_pkg;
create or replace package saas_auth_pkg as
  
   -- Add this to your authentication scheme. Calls all packaged procedures with name 'post_auth'.
   procedure post_auth;

   procedure add_user (
      p_user_name in varchar2,
      p_email    in varchar2,
      p_password in varchar2);

   procedure delete_user (
      p_user_name in varchar2);

   procedure create_account (
      p_user_name in varchar2,
      p_email    in varchar2,
      p_password in varchar2,
      p_confirm in varchar2);

   function custom_auth (
      p_username in varchar2,
      p_password in varchar2) return boolean;

   procedure send_reset_pass_token (
      p_email in varchar2);

   procedure reset_password (
      p_token in varchar2,
      p_password in varchar2,
      p_confirm in varchar2);

   -- This is set up in APEX as a custom authorization.
   function is_signed_in return boolean;
   
   -- This is set up in APEX as a custom authorization.
   function is_not_signed_in return boolean;

   function is_admin (
      p_user_id in number) return boolean;

   function is_user (
      p_user_name in varchar2) return boolean;

end;
/



