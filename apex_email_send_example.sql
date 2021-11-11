

-- Test procedure to run if you have set up APEX email. Change the addresses of course.
-- And make sure you check your spam folder!s

begin
    apex_mail.send(p_from => 'ethan@foo.com', 
       p_to => 'post.ethan@bar.com', 
       p_subj => 'Email from Autonomous',
       p_body => 'This is a test email from Autonomous'); 
    apex_mail.push_queue(); 
end; 
/
