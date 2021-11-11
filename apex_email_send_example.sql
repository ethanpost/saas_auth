begin
    apex_mail.send(p_from => 'ethan@arclogicsoftware.com', 
       p_to => 'post.ethan@gmail.com', 
       p_subj => 'Email from Autonomous',
       p_body => 'This is a test email from Autonomous'); 
    apex_mail.push_queue(); 
end; 
/
