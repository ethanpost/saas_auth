

/*

README
-------------------------------------------------------------------------------

# UT 2.1 BUG

There is a bug in Universal Theme 2.1 which causes all of the hidden 
regions on the log in form to briefly appear. You may need to 
change the "Files" setting to "#IMAGE_PREFIX#themes/theme_42/1.6/"
to fix this problem.

# ARCSQL_USER_SETTING

Make sure you configure 'saas_auth_from_address' and 'saas_auth_salt' 
in the arcsql_user_setting package. The from address should be an
approved sender.

*/

whenever sqlerror exit failure;
-- set echo on

exec arcsql.set_app_version('saas_auth', .01);

-- Add a copy of this file in your app repo and make sure it installs after this one.
@saas_auth_config.sql
@saas_auth_schema.sql 
@saas_auth_pkgh.sql 
@saas_auth_pkgb.sql 
-- This file can be copied and modified within your app.
@saas_auth_events.sql

exec arcsql.confirm_app_version('saas_auth');


