Barkeep supports a read-only demo mode. The intention is to let people play with Barkeep without having to
log in. We use it in the demo Barkeep installation linked from getbarkeep.com. This README describes how it
works and how it's implemented.

You can set `ENABLE_READONLY_DEMO_MODE = true` in `config/environment.rb`. `config/environment.rb` is
supposed to be generated during deploy (if you're using Fezzik or Capistrano). `ENABLE_READONLY_DEMO_MODE` is
set to true for our development environments, but should be false for most production environments.

When it's true, a demo user is created in the database (see `script/create_demo_user.rb`) when
`./script/initial_app_setup.rb` gets run.

When someone navigates to Barkeep and is not logged in, we log them in as this demo user. The demo user
can create saved searches in the UI, but rather than being stored server-side as they are normally, they're
stored in a cookie.

The demo user can post comments. Those comments are not emailed, and comments by the demo user which are over
an hour old are deleted. This is to prevent us from accumulating too many comments and to avoid spam.

While "logged in" as a demo user, you can still click the "signin" link and log in as a real user using our
regular signin mechanism. This is so we can leave real comments as ourselves on that demo instance, so it has
real data.
