Authentication: Who Are You?

In chapter 4, we expanded Tunez with APIs — we now have HTML in the
browser, REST JSON, and GraphQL. It was fun seeing how Ash’s declarative
nature could be used to generate everything for us, using the existing domains,
resources and actions in our app.

But now it’s time to get down to serious business. The world is a scary place,
and unfortunately we can’t trust everyone in it to have free rein over the data
in Tunez. We need to start locking down access to critical functionality, to
only trusted users — but we don’t yet have any way of knowing who those
users are.

We can solve this by adding authentication to our app, and requiring users
to log in before they can create or modify any data. Ash has a library that can
help with this, called...

Introducing AshAuthentication
It’s a very imaginative package name, I know.

There are two parts to AshAuthentication — the core ash_authentication package,
and the ash_authentication_phoenix Phoenix extension to provide things like signup
and registration forms. We’ll start with the basic library, to get a feel for how
it works, and then add the web layer afterwards.

This chapter will be a little different than everything we’ve covered so far,
because we really won’t have to write much code until the later stages. The
AshAuthentication installer will generate most of the necessary code into our
app for us, and while we won’t have to modify a lot of it, it’s important to
understand it. (And it’s there if we do need to modify it!)

You can install AshAuthentication with Igniter:

$ mix igniter.installash_authentication

This will generate a lot of code in several stages — so let’s break it down bit
by bit.

You may get an error here, about SAT solver installation. Ash
requires a SAT solver^1 to run authorization policies — by default
it will attempt to install picosat_elixir on non-Windows machines,
but this can be fiddly to set up. If you get an error, follow the
prompts to uninstall picosat_elixir, and install simple_sat instead.
New domain, who’s this?

We’re now working with a whole different section of our domain model. Previ-
ously we were building music-related resources, so we created a domain
named Tunez.Music. Authentication is part of a separate system, an account
management system, and so the generator will create a new domain called
Tunez.Accounts. This domain will be populated with two new resources —
Tunez.Accounts.User and Tunez.Accounts.Token.

The Tunez.Accounts.User resource, in lib/tunez/accounts/user.ex, is what will represent,
well, users of your app. It comes pre-configured with AshPostgres as its data
layer, so each user record will be stored in a row of the users database table.

By itself, the user resource doesn’t do much yet. It doesn’t even have any
attributes, except an id. It does have some authentication-related configuration,
in the top-level authentication block — setting up the log_out_everywhere add-on,
and linking the resource with tokens. This is what makes up most of the rest
of the generated code.

Tokens and secrets and config, oh my!

Tokens, via the Tunez.Accounts.Token resource and the surrounding config, are
the secret sauce to a basic AshAuthentication installation. Tokens are how
we securely identify users — from an authentication token provided on every
request (“I am logged in as rebecca”), to password reset tokens appended to
links in emails, and more.

This is the part you really don’t want to get wrong when building a web app,
because the consequences could be pretty bad. So AshAuthentication gener-
ates all of the token-related code we need right up front, before we even do

https://codingnest.com/modern-sat-solvers-fast-neat-underused-part-1-of-n/
Chapter 5. Authentication: Who Are You? • 114

anything else. For basic uses, we shouldn’t need to touch anything in the
generated token code, but it’s there if we need to.

So how do we actually use all this code? We need to set up at least one
authentication strategy.

Setting Up Password Authentication
AshAuthentication supports a number of authentication strategies^2 — ways
we can identify users in our app. Traditionally, we think of logging in to an
app via entering an email address and password, which is one of the supported
strategies (the password strategy), but there are several more. We can authen-
ticate via different types of OAuth, or even via magic links sent to a user’s
email address.

Let’s set the password strategy up and get a feel for how it works. AshAuthenti-
cation comes with igniters to add strategies to our existing app, so you can
run the following command:

$ mix ash_authentication.add_strategypassword

This will add a lot more code to our app. We now have:

Two new attributes for the Tunez.Accounts.User resource — email and
hashed_password. The email attribute is also marked as an identity, so it must
be unique.
A strategies block added to the authentication configuration in the
Tunez.Accounts.User resource. This states that we want to use the email
attribute as the identity field for this strategy, and it also sets up the
resettable option to allow users to reset their passwords.
The confirmation add-on added to the add_ons block, as part of the authentication
configuration in the Tunez.Accounts.User resource. This will require users to
confirm their email addresses by clicking on links in emails, when regis-
tering for an account or changing their email address. Super handy!
A whole set of actions in our Tunez.Accounts.User resource, around signing
in, registering, and resetting passwords.
And lastly, some template email modules that will be used when it comes
to actually sending password reset/email confirmation emails.
That’s a lot of goodies!

Because the tasks have created a few new migrations, run ash.migrate to get
our database up to date:

https://hexdocs.pm/ash_authentication/get-started.html#choose-your-strategies-and-add-ons
Setting Up Password Authentication • 115

$ mix ash.migrate

There will be a few warnings from the email modules about the routes for
password reset/email confirmation not existing yet — that’s okay, we haven’t
looked at setting up AshAuthenticationPhoenix yet! But we can still test out
our code with the new password strategy in an iex session, to see how it works.

Don’t try this in a real app!
Note that we’ll skip AshAuthentication’s built-in authorization
policies for this testing, by passing the authorize?:false option to
Ash.create. This is only for testing purposes — the real code in our
app won’t do this.
Testing authentication actions in iex

One of the generated actions in the Tunez.Accounts.User resource is a regis-
ter_with_password create action, which takes email, password, and password_confirmation
arguments and creates a user record in the database. It doesn’t have a code
interface defined, but you can still run it by generating a changeset for the
action, and submitting it. Try using your own email address, and the password
supersecret:

iex(1)> Tunez.Accounts.User
Tunez.Accounts.User
iex(2)> |> Ash.Changeset.for_create( :register_with_password , %{ email:«email» ,
password:"supersecret",password_confirmation:"supersecret"})
#Ash.Changeset<
domain:Tunez.Accounts,
action_type::create,
action::register_with_password,
...

iex(3)> |> Ash.create!( authorize?: false)
[debug]QUERYOK source="users"db=2.4ms
INSERTINTO"users"("id","email","hashed_password")VALUES($1,$2,$3)
RETURNING"hashed_password","email","id","confirmed_at"[ «uuid» ,
#Ash.CiString< «email» >, «hashedpassword» ]
[debug]QUERYOK source="tokens"db=2.5ms
«severalqueriesto generatetokens»
#Tunez.Accounts.User<
meta:#Ecto.Schema.Metadata<:loaded,"users">,
confirmed_at:nil,
id: «uuid» ,
email:#Ash.CiString< «email» >,
...

Chapter 5. Authentication: Who Are You? • 116

Note that there are no code interfaces defined for the actions in the
Tunez.Accounts.User resource, so you’ll need to construct the changesets manu-
ally.

Calling this action has done a few things:

Inserted the new user record into the database, including securely hashing
the provided password;
Created tokens for the user to authenticate and also confirm their email
address, and
Generated an email to send to the user, to actually confirm their email
address. In development, it won’t send an actual email to the email address
we entered, but all of the plumbing is in place for the app to do so.
What can we do with our new user record? We can try to authenticate them,
using the created sign_in_with_password action. This mimics what a user would
do on a login form, by entering their email address and password:

iex(9)> Tunez.Accounts.User
Tunez.Accounts.User
iex(10)> |> Ash.Query.for_read( :sign_in_with_password , %{ email:«email» ,
...(10)> password:"supersecret" })
#Ash.Query<
resource:Tunez.Accounts.User,
arguments:%{password:" ****** redacted ****** ", email:#Ash.CiString< «email» >},
filter:#Ash.Filter<email== #Ash.CiString< «email» >>

iex(11)> |> Ash.read( authorize?: false)
[debug]QUERYOK source="users"db=0.7ms idle=1472.4ms
SELECTu0."id",u0."confirmed_at",u0."email",u0."hashed_password"FROM
"users"AS u0 WHERE(u0."email"::citext= ($1::citext))[ «email» ]
{:ok,
[
#Tunez.Accounts.User<
meta:#Ecto.Schema.Metadata<:loaded,"users">,
confirmed_at:nil,
email: «email» ,
...

And it works! AshAuthentication has validated that the credentials are correct,
by fetching any user records with the provided email, hashing the provided
password, and verifying that it matches what is stored in the database. You
can also try it with different credentials like an invalid password; AshAuthen-
tication will properly return an error.

Calling sign_in_with_password with correct credentials has also generated an
authentication token in the returned user’s metadata, to be stored in the
browser and used to authenticate the user in future.

Setting Up Password Authentication • 117

iex(12)> { :ok , [user]}= v()
{:ok,[#Tunez.Accounts.User< ...> ]}
iex(13)> user.metadata.token
"eyJhbGciOi..."

This token is a JSON Web Token, or JWT.^3 It’s cryptographically signed by
our app to prevent tampering — if a malicious user has a token and edits it
to attempt to impersonate another user, the token will no longer verify. To
test out the verification, we can use some of the built-in AshAuthentication
functions like AshAuthentication.Jwt.verify/2 and AshAuthentication.subject_to_user/2:

iex(14)> AshAuthentication.Jwt.verify(user.metadata.token, :tunez )
{:ok,
%{
"aud"=> "~> 4.5",
"exp"=> 1742123290,
"iat"=> 1740913690,
"iss"=> "AshAuthenticationv4.5.2",
"jti"=> «string» ,
"nbf"=> 1740913690,
"purpose"=> "user",
"sub"=> "user?id= «uuid» "
}, Tunez.Accounts.User}

The interesting parts of the decoded token here are the sub (subject) and the
purpose. JWTs can be created for all kinds of purposes, and this one is for user
authentication, hence the purpose “user”. The subject is a specially-formatted
string with a user ID in it, which we can verify belongs to a real user:

iex(15)> { :ok , claims,resource}= v()
{:ok,%{...},Tunez.Accounts.User}
iex(16)> AshAuthentication.subject_to_user(claims[ "sub" ], resource)
[debug]QUERYOK source="users"db=1.6ms queue=0.8msidle=1848.6ms
SELECTu0."id",u0."confirmed_at",u0."hashed_password",u0."email"FROM
"users"AS u0 WHERE(u0."id"::uuid = $1::uuid)[ «uuid» ]
{:ok,
#Tunez.Accounts.User<
email:#Ash.CiString< «youremail» >,
...

}

We don’t really need to muck around with all of this, though. It’s good to know
how AshAuthentication works, and how to verify that it works, but we’re
building a web app — we want forms that users can fill out to register or sign-
in. For that, we can look at AshAuthentication’s sister library, AshAuthenti-
cationPhoenix.

https://jwt.io/
Chapter 5. Authentication: Who Are You? • 118

Automatic UIs With AshAuthenticationPhoenix
As the name suggests, AshAuthenticationPhoenix is a library that connects
AshAuthentication with Phoenix, providing a great LiveView-powered UI that
we can tweak a little bit to fit our site look and feel, but otherwise don’t need
to touch.

Like other libraries, you can install it with Igniter:

$ mix igniter.installash_authentication_phoenix

Ignoring the same warnings about some routes not existing (this will be the
last time we see them!), the AshAuthenticationPhoenix installer will set up:

A basic Igniter config file in .igniter.exs — this is the first generator we’ve
run that needs specific configuration (for Igniter.Extensions.Phoenix), so it gets
written to a file
A TunezWeb.AuthOverrides module, that we can use to customize the look and
feel of the generated liveviews a bit (in lib/tunez_web/auth_overrides.ex)
A TunezWeb.AuthController module, to securely process sign-in requests (in
lib/tunez_web/controllers/auth_controller.ex). This is due to a bit of a quirk in how
LiveView works; it doesn’t have access to the user session to store data
on successful authentication.
A TunezWeb.LiveUserAuth module providing a set of hooks we can use in live-
views to require a certain authentication status (in
lib/tunez_web/live_user_auth.ex)
An addition to the mix phx.routes alias, to include routes from AshAuthenti-
cationPhoenix (in mix.exs)
And lastly, the most important part — updating our web app router in
lib/tunez_web/router.ex to add plugs and routes for all of our authentication-
related functionality.
Before we can test it out, there’s one manual change we need to make, as
Igniter doesn’t (yet) know how to patch JavaScript files. Because AshAuthen-
ticationPhoenix’s liveviews are styled with Tailwind CSS, we need to add its
liveview paths to Tailwind’s content lookup paths. Add the "../deps/ash_authenti-
cation_phoenix//.ex" line to the content array in assets/tailwind.config.js, restart your
mix phx.server, and then we can see what kind of UI we get, by visiting the sign-
in page at http://localhost:4000/sign-in:

Automatic UIs With AshAuthenticationPhoenix • 119

It’s pretty good! Out of the box we can sign-in, register for new accounts, and
request password resets, without lifting a finger.
After signing in, we get redirected back to the Tunez homepage — but there’s
no indication that we’re now logged in, and no link to log out. We’ll fix that
now.
Showing the currently-authenticated user
Most web apps show their current user indicator in the top-right corner of
the page, so that’s what we’ll implement as well. The main Tunez navigation
is part of the application layout, in lib/tunez_web/components/layouts/app.html.heex,
so we can edit to add a new rendered user_info component:
05/lib/tunez_web/components/layouts/app.html.heex
<divclass= "flexitems-centerw-fullp-4 pb-2border-b-2border-primary-600" >
<divclass= "flex-1mr-4" >
<% # ... %>

➤ <**.** user_infocurrent_user= _{@current_user}_ /> This is an existing function component located in the TunezWeb.Layouts module, in lib/tunez_web/components/layouts.ex, and shows sign in/register buttons if there’s no user logged in, and a dropdown of user-related things if there is. Refreshing the app after making this change shows a big error, however: key :current_usernot foundin: %{ socket:#Phoenix.LiveView.Socket<...>, sort_by:"-updated_at",
Chapter 5. Authentication: Who Are You? • 120

__changed__:%{...},
page_title:"Artists",
inner_content:%Phoenix.LiveView.Rendered{...},
...
What gives? Fixing this will require digging a bit into how the new router code
works, so let’s take a look.
Digging into AshAuthenticationPhoenix’s generated router code
We didn’t really go over the changes to our router in lib/tunez_web/router.ex, after
installing AshAuthenticationPhoenix — we just assumed everything was all
good. For the most part it is, but there are one or two things we need to tweak.
The igniter added plugs to our pipelines to load the current user —
load_from_bearer for our API pipelines, and load_from_session for our browser pipeline.
This works for traditional “deadview” web requests, that receive a request and
send the response in the same process.
LiveView works differently, though. When a new request is made to a liveview,
it spawns a new process and keeps that active websocket connection open
for that realtime data transfer. This new process doesn’t have access to the
session, so although our base request knows who the user is, the spawned
process does not.
Enter live_session, and how its wrapped by AshAuthentication, ash_authentica-
tion_live_session. This macro will ensure that when new processes are spawned,
they get copies of the data in the session so the app will continue working as
expected.
What does this mean for Tunez? It means that all our liveview routes that are
expected to have access to the current user, need to be moved into the
ash_authentication_live_session block in the router.
05/lib/tunez_web/router.ex
scope "/" , TunezWeb do
pipe_through :browser
➤ # Thisis the blockof routesto move
➤ live "/" , Artists.IndexLive
➤ # ...
➤ live "/albums/:id/edit" , Albums.FormLive, :edit

auth_routesAuthController,Tunez.Accounts.User, path:"/auth"
sign_out_routeAuthController
...
The ash_authentication_live_session helper is in a separate scope block in the router,
earlier on in the file:
Automatic UIs With AshAuthenticationPhoenix • 121

05/lib/tunez_web/router.ex
scope "/" , TunezWeb do
pipe_through :browser
ash_authentication_live_session :authenticated_routes do
➤ # Thisis the locationthatthe blockof routesshouldbe movedto
➤ live "/" , Artists.IndexLive
➤ # ...
➤ live "/albums/:id/edit" , Albums.FormLive, :edit
end
end
With this change, our app should be renderable, and we should see informa-
tion about the currently logged in user in the top-right corner of the main
navigation.

Now we can turn our attention to the generated liveviews themselves. We
want them to look totally seamless in our app, like we wrote and styled them
ourselves. While we don’t have control over the HTML that gets generated,
we can customize a lot of the styling and some of the content, using overrides.
Stylin’ and profilin’ with overrides
Each liveview component in AshAuthenticationPhoenix’s generated views has
a set of overrides configured, that we can use to change things like component
class names and image URLs.
When we installed AshAuthenticationPhoenix, a base TunezWeb.AuthOverrides
module was created in lib/tunez_web/auth_overrides.ex. This shows the syntax that
we can use to set different attributes, that will then be used when the liveview
is rendered:
05/lib/tunez_web/auth_overrides.ex
overrideAshAuthentication.Phoenix.Components.Banner do
set :image_url , "https://media.giphy.com/media/g7GKcSzwQfugw/giphy.gif"
set :text_class , "bg-red-500"
end
Chapter 5. Authentication: Who Are You? • 122

As well a link to the complete list of overrides^4 you can use, in the documen-
tation.
Let’s test it out, by changing the colour of the “Sign In” button on the sign in
page. Buttons in Tunez are purple, not blue! It can be a bit tricky to find
exactly which override will do what you want, but in this case, the submit
button is an input , and under AshAuthentication.Phoenix.Components.Password.Input is
an override for submit_class. Perfect.
In the overrides file, set a new override for that Input component:
05/lib/tunez_web/auth_overrides.ex
defmodule TunezWeb.AuthOverrides do
use AshAuthentication.Phoenix.Overrides
➤ overrideAshAuthentication.Phoenix.Components.Password.Input do
➤ set :submit_class , "bg-primary-600text-whitemy-4py-3px-5text-sm"
➤ end

Log out and return to the sign-in page, and the sign-in button will now be
purple!
As any overrides we set will completely override the default styles, there may
be more of a change than you expect. If you’re curious about what the default
values for each override are, or you want to copy and paste them so you can
only change what you need, you can see them in the AshAuthentication-
Phoenix source code.^5
The generated classes include styles for dark mode using the Tailwind dark:
class modifier,^6 so if you’re building an app that specifies darkMode:"media" (or
doesn’t specify darkMode at all) as part of its Tailwind config in assets/tailwind.con-
fig.js, you’ll see light or dark theming depending on your system theme. For
ease of use, Tunez has disabled automatic dark mode by setting darkMode:
"selector", but it’s good to be aware of.
We won’t bore you with every single class change to make, to turn a default
AshAuthenticationPhoenix form into one matching the rest of the site theme,
so we’ve provided a set of overrides in the starter app in lib/tunez_web/auth_over-
rides_sample.txt. You can take the contents of that file and replace the contents
of the TunezWeb.AuthOverrides module, like so:
https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html#reference
https://github.com/team-alembic/ash_authentication_phoenix/blob/main/lib/ash_authentication_phoenix/overrides/
default.ex
https://tailwindcss.com/docs/dark-mode
Automatic UIs With AshAuthenticationPhoenix • 123

05/lib/tunez_web/auth_overrides.ex
defmodule TunezWeb.AuthOverrides do
use AshAuthentication.Phoenix.Overrides
➤ aliasAshAuthentication.Phoenix.Components
➤
➤ overrideComponents.Banner do
➤ set :image_url , nil
➤ # ...

And it should look like this:
Feel free to tweak the styles the way you like - Tunez is your app, after all!
Why do users always forget their passwords!?
Earlier we mentioned that the app was automatically generating an email to
send to users after registration, to confirm their accounts. Let’s see what that
looks like!
When we added the password authentication to Tunez, AshAuthentication
generated two modules responsible for generating emails, senders in AshAu-
thentication jargon. These live in lib/tunez/accounts/user/senders — there’s one for
SendNewUserConfirmationEmail, and one for SendPasswordResetEmail.
Phoenix apps come with a Swoosh^7 integration built in for sending email, and
the generated senders have used that. Each sender module defines two critical
functions: a body/1 private function that generates the content for the email,
and a send/3 that is responsible for constructing and sending the email using
Swoosh.
We don’t need to set up an email provider to send real emails, while working
in development. Swoosh provides a “mailbox” we can use — any emails sent,
no matter the target email address, will be delivered to the dev mailbox (instead
of actually being sent!). This dev mailbox is added to our router in dev mode
only, and can be accessed at http://localhost:4000/dev/mailbox.
https://hexdocs.pm/swoosh/
Chapter 5. Authentication: Who Are You? • 124

The mailbox is empty by default, but if you register for a new account via the
web app and then refresh the mailbox:

The email contains a link to confirm the email address, which, sure, that’s
totally my email address and I did sign up for the account, so click the link.

You’ll be redirected back to the app homepage, with a flash message letting
us know that our email address is confirmed. It works!

Setting Up Magic Link Authentication
Word going around nowadays is that some users think that passwords are
just so passé, and they’d much prefer to be able to log in using magic links
instead — enter their email address, click the login link that gets sent straight
to their inbox, and they’re in. That’s no problem!

AshAuthentication doesn’t limit our apps to just one method of authentication,
we can add as many as we like from the supported strategies^8 or even write
our own. So there’s no problem with adding the magic link strategy to our
existing password-strategy-using app, and users can even log in with either
strategy depending on their mood. Let’s go.

To add the strategy, we can run the ash_authentication.add_strategy Mix task:

$ mix ash_authentication.add_strategymagic_link

This will:

Add a new magic_link authentication strategy block to our Tunez.Accounts.User
resource, in lib/tunez/accounts/user.ex
Add two new actions named sign_in_with_magic_link and request_magic_link, also
in our Tunez.Accounts.User resource,
Remove the allow_nil? false on the hashed_password attribute in the
Tunez.Accounts.User resource (users that sign in with magic links won’t nec-
essarily have passwords!)
And finally, add a new sender module responsible for generating the
magic link email, in lib/tunez/accounts/user/senders/send_magic_link_email.ex.
https://hexdocs.pm/ash_authentication/get-started.html#choose-your-strategies-and-add-ons
Setting Up Magic Link Authentication • 125

The magic_link config block in the Tunez.Accounts.User resource lists some sensible
values for the strategy configuration, such as the name of the identity attribute
(email by default). There are more options^9 that can be set, such as how long
generated magic links are valid for (token_lifetime), but we won’t need to add
anything extra to what is generated here.

A migration was generated for the allow_nil?false change on the users table, so
you’ll need to run that:

$ mix ash.migrate

Wait... that’s it? Yep, that’s it. The initial setup of AshAuthentication generates
a lot of code for the initial resources, but adding subsequent strategies typi-
cally only needs a little bit.

Once you’ve added the strategy, visiting the sign-in page will have a nice
surprise:

Is it really that simple?? If we fill out the magic link sign-in form with the
same email address we confirmed earlier, an email will be delivered to our
dev mailbox, with a sign-in link to click. Click the link, and you should be
back on the Artist catalog, with a flash message saying that you’re now signed
in. Awesome!

But you might not be signed in automatically. You might be back on the sign
in page, with a generic “incorrect email or password” message that doesn’t
give away any secrets. How can we tell what’s happening behind the scenes?

Debugging when authentication goes wrong

While showing a generic failure message is good in production for security
reasons (we don’t want to give away information like if an email address defi-
nitely belonged to an account, to potentially-bad actors), it’s not good in
development while you’re trying to make things work, or debugging issues.

https://hexdocs.pm/ash_authentication/dsl-ashauthentication-strategy-magiclink.html#options
Chapter 5. Authentication: Who Are You? • 126

To get more information about what’s going on, we can enable authentication
debugging for our development environment only , by placing the following at
the bottom of config/dev.exs:

05/config/dev.exs
config :ash_authentication , debug_authentication_failures?: true

Restart your mix phx.server to apply the new config change, and we’ll try some-
thing else. If you saw an error when clicking the magic link, try clicking the
same magic link again. You should see a big yellow warning in your server
logs:

[warning]Authenticationfailed:
BreadCrumbs:

Errorreturnedfrom:Tunez.Accounts.User.sign_in_with_magic_link

InvalidError

Invalidmagic_linktoken
(ash3.x.xx)lib/ash/error/changes/required.ex:4:Ash.Error.Changes...
(ash3.x.xx)lib/ash/changeset/changeset.ex:3337:Ash.Changeset...
...
This is what you will see if you’ve clicked on an expired magic link. Magic
link is only valid for 10 minutes by default, so if you’ve clicked on one after
that time it will fail and you’ll see this error in your logs.

There’s one other error message that may appear:

Attemptedto updatestale record of Tunez.Accounts.Userwith filter: not is_nil(confirmed_at)
For security reasons, you can’t use a magic link to an existing account that
has an unconfirmed email address, as this would allow account hijacking.^10
This will show a different flash message in the browser, instead of the generic
“incorrect email or password” — you’ll be told that the email address already
belongs to an account.

If you try with a different email address, either with an email belonging to a
confirmed account or not belonging to an existing account, this error will go
away!

Without turning the AshAuthentication debugging on, these kinds of issues
would be near-impossible to fix. It’s safe to leave it enabled in development,
as long as you don’t mind the warning about it during server start. If the
warning is too annoying, feel free to turn debugging off, but don’t forget that
it’s available to you!

10.https://hexdocs.pm/ash_authentication/confirmation.html#important-security-notes

Setting Up Magic Link Authentication • 127

And that’s all we need to do, to implement magic link authentication in our
apps. Users will be able to create accounts via magic links, and also log into
their existing accounts that were created with an email and password. Our
future users will thank us!
Can we allow authentication over our APIs?
In the previous chapter, we built two shiny APIs that users can use to pro-
grammatically access Tunez and its data. In order to make sure the APIs have
full feature parity with the web UI, we need to make sure they can register
and sign in via the API as well. When we start locking down access to critical
parts of the app, we don’t want API users to be left out!
Let’s give it a try, and see how far we can get. We’ll start with adding registra-
tion support, in our JSON API.
To add JSON API support to our Tunez.Accounts.User resource, we can extend it
using Ash’s extend patcher:
$ mix ash.extendTunez.Accounts.Userjson_api
This will configure our JSON API router, domain module, and resource with
everything we need to start connecting routes to actions. To create a POST
request to our register_with_password action, we can add a new route to the
domain,^11 like we did with Adding Albums to the API, on page 96. We’ve cus-
tomized the actual URL with the route option, to create a full URL like
/api/json/users/register.
05/lib/tunez/accounts.ex
defmodule Tunez.Accounts do
use Ash.Domain, extensions: [AshJsonApi.Domain]
➤ json_api do
➤ routes do
➤ base_route "/users" , Tunez.Accounts.User do
➤ post :register_with_password , route:"/register"
➤ end
➤ end
➤ end

# ...
end
Looks good so far! But if you try it in an API client, or using cURL, correctly
suppling all the arguments that the action expects... it won’t work, it always
returns a forbidden error. Drat.
11.https://hexdocs.pm/ash_json_api/dsl-ashjsonapi-domain.html#json_api-routes-base_route-post
Chapter 5. Authentication: Who Are You? • 128

This is because at the moment, the Tunez.Accounts.User resource is really tightly
secured. All of the actions are restricted, to only be accessible via AshAuthen-
ticationPhoenix’s form components. (Or if we skip authorization checks, like
we did earlieron page 116. That was for test purposes only!)

This is good for security reasons — we don’t want any old code to be able to
do things like change people’s passwords! It makes our development lives a
little bit harder, though, because to understand how to allow the functionality
we want, we need to dive into our next topic, authorization. Buckle up, this
may be a long one...

Setting Up Magic Link Authentication • 129

CHAPTER 6
