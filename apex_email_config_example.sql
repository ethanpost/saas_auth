

-- This needs to run as admin user. This is set per APEX instance.
-- These values are generated in the Oracle Cloud console.
-- See smtp credentials in users and 'email delivery'.
-- https://blogs.oracle.com/apex/post/sending-email-from-your-oracle-apex-app-on-autonomous-database

begin
    apex_instance_admin.set_parameter('SMTP_HOST_ADDRESS', 'smtp.email.us-phoenix-1.oci.oraclecloud.com');
    apex_instance_admin.set_parameter('SMTP_USERNAME', 'ocid1.user.oc1..----------------------------------ocid1.tenancy.oc1..---------------.4j.com');
    apex_instance_admin.set_parameter('SMTP_PASSWORD', '----------------------');
    commit;
end;
/
