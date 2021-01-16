

-- uninstall: drop table saas_auth_role cascade constraints purge;
exec drop_table('saas_auth_role');
begin
   if not does_table_exist('saas_auth_role') then 
      execute_sql('
      create table saas_auth_role (
      role_id number not null,  
      role_name varchar2(120) not null
      )', false);
      execute_sql('alter table saas_auth_role add constraint pk_saas_auth_role primary key (role_id)', false);
      execute_sql('create unique index saas_auth_role_1 on saas_auth_role(role_name)', false);
   end if;
end;
/

begin 
   update saas_auth_role set role_id=1 where role_id=1;
   if sql%rowcount = 0 then 
      insert into saas_auth_role (
         role_id,
         role_name) values (
         1,
         'user');
   end if;
   update saas_auth_role set role_id=2 where role_id=2;
   if sql%rowcount = 0 then 
      insert into saas_auth_role (
         role_id,
         role_name) values (
         2,
         'admin');
   end if;
end;
/

-- uninstall: drop table saas_auth cascade constraints purge;
exec drop_table('saas_auth');
begin
   if not does_table_exist('saas_auth') then 
      execute_sql('
      create table saas_auth (
      user_id number generated by default on null as identity minvalue 1 maxvalue 9999999999999999999999999999 increment by 1 start with 1 cache 20 noorder nocycle nokeep noscale not null,
      role_id number,
      user_name varchar2(120) not null,
      email varchar2(120) not null,
      password varchar2(120) not null,
      last_session_id varchar2(120) default null,
      last_login date default null,
      login_count number default 0,
      last_failed_login date default null,
      failed_login_count number default 0,
      reset_pass_token varchar2(120),
      reset_pass_expire date default null,
      lock_account varchar2(1) default ''n'',
      created date not null,
      created_by varchar2(120) not null,
      updated date not null,
      updated_by varchar2(120) not null
      )', false);
      execute_sql('alter table saas_auth add constraint pk_saas_auth primary key (user_id)', false);
      execute_sql('create unique index saas_auth_1 on saas_auth(user_name)', false);
      execute_sql('create index saas_auth_2 on saas_auth(role_id)', false);
      execute_sql('alter table saas_auth add constraint saas_auth_fk_role_id foreign key (role_id) references saas_auth_role (role_id) on delete cascade', false);
   end if;
end;
/

create or replace trigger saas_auth_trig
   before insert or update
   on saas_auth
   for each row
begin
   if inserting then
      :new.created := sysdate;
      :new.created_by := nvl(sys_context('apex$session','app_user'), user);
      if :new.user_name is null then 
         :new.user_name := lower(:new.email);
      end if;
   end if;
   :new.updated := sysdate;
   :new.updated_by := nvl(sys_context('apex$session','app_user'), user);
   :new.email := lower(:new.email);
end;
/
