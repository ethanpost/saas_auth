

function saas_auth_show(r) {
   if ( r == 'REGISTER' ) {
      $(REGISTER_REGION).show();
      $(LOGIN_REGION).hide();
      $(LOG_IN_EXTRA_REGION).hide();
      $(CHANGE_PASSWORD_REGION).hide();
      $(FORGOT_PASSWORD_REGION).hide();
   } else if (r=='FORGOT') {
      $(REGISTER_REGION).hide();
      $(LOGIN_REGION).hide();
      $(LOG_IN_EXTRA_REGION).hide();
      $(CHANGE_PASSWORD_REGION).hide();
      $(FORGOT_PASSWORD_REGION).show();
   } else if (r=='LOGIN') {
      $(REGISTER_REGION).hide();
      $(LOGIN_REGION).show();
      $(LOG_IN_EXTRA_REGION).show();
      $(CHANGE_PASSWORD_REGION).hide();
      $(FORGOT_PASSWORD_REGION).hide();
   } else if (r=='CHANGE') {
      $(REGISTER_REGION).hide();
      $(LOGIN_REGION).hide();
      $(LOG_IN_EXTRA_REGION).hide();
      $(CHANGE_PASSWORD_REGION).show();
      $(FORGOT_PASSWORD_REGION).hide();
   }
}


