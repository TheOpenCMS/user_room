$(document).on 'ready turbolinks:load',  ->
  do Notifications.init
  do SocialLoginButtons.init