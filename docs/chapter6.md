Authorization: What Can You Do?

We left Tunez in a good place at the end of the previous chapter. Visitors to
the app can now register accounts, or login with either an email and password
or a magic link. Now we can identify who is using Tunez.

However, we couldn’t allow users to authenticate or register an account for
Tunez via either of our APIs. The app also doesn’t behave any differently
depending on whether a user is logged in or not. Anyone can still create, edit
and delete data, without needing to be logged in. This is what we want to
prevent, for better data integrity — unauthenticated users should have a total
read-only view of the app, and authenticated users should be able to perform
only the actions they are granted access to. We can enforce this by implement-
ing access control in the app, using a component of Ash called policies.

Introducing Policies
Policies define who has access to resources within our app, and what actions
they can run. Each resource can have its own set of policies, and each policy
can apply to one or more actions defined in that resource.

Policies are checked internally by Ash before any action is run — if all policies
that apply to a given action pass (return authorized), then the action is run.
If one or more of the policies fail (return unauthorized), then the action is not
run and an error is returned.

Because policies are part of resource definitions, they will automatically be
checked on all calls to actions in those resources. You only have to write them
once, and they will apply everywhere — in our web UI, our REST and GraphQL
APIs, an iex REPL, and any other interfaces we add in future. You also don’t
have to worry about the how of policy checking, the when , you’re freed up to

focus on the actual business logic of who can access what. This makes access
control simple, straightforward, and fast to implement.

A lot of policy checks will naturally depend on the entity calling the action,
or the actor. This is usually (but not always!) the person using the app,
clicking buttons and links in their browser. This is why it’s a pre-requisite to
know who our users are!

At its core, a policy is made up of two things:

One or more policy conditions , to determine whether or not the policy
applies to a specific action request
A set of policy checks , that are run to see if a policy passes or fails. Each
policy check is itself made up of a check condition, and an action to take
if the check condition matches the action condition.
There’s a lot of conditions to consider, so an example will hopefully make it
clearer. If we were building a Blog application, and wanted to add policies for
a Post in our blog, a policy might look like the following:

defmodule Blog.Post do
use Ash.Resource, authorizers: [Ash.Policy.Authorizer]
policies do
policyaction( :publish ) do
forbid_ifexpr(published== true)
authorize_ifactor_attribute_equals( :role , "admin" )
end
end
end

The single condition for this policy is action(:publish), meaning the policy will
apply to any calls to the hypothetical publish action in this Blog.Post resource.
It has two policy checks — one that will forbid the action if the published
attribute on the resource is true, and one that will authorize the action if the
actor calling the action has the attribute role set to “admin”.

Or in human terms, admin users can publish a blog post if it’s not already
published. Any other cases would return an error.

As mentioned previously in Loading Related Resource Data, on page 44, all
actions (including code interfaces) support an extra argument of options to
customize the behaviour of the action. One of the options that all actions
support is actor (as seen in the list of options for each action type),^1 so we can
modify each action call to add the actor option:

https://hexdocs.pm/ash/Ash.html
Chapter 6. Authorization: What Can You Do? • 132

# Insteadof this...
Blog.Post.publish(post)

# We can use this!
Blog.Post.publish(post, actor: current_user)

Decisions, decisions

When evaluating policy checks, the first check that successfully makes a
decision determines the overall result of the policy. Policies could be thought
of like a cond statement — checks are evaluated in order until one makes a
decision, and the rest are ignored — so the order of checks within a policy is
really important, perhaps more than it first appears.

In our Blog.Post example, if we attempt to publish a post that has the attribute
published equal to true, the first check will make a decision because the check
condition is true (the attribute published is indeed equal to true), and the action
is to forbid_if the check condition is true.

The second check for the admin role is irrelevant — a decision has already
been made, so no-one can publish an already-published blog post, period.

If the order of the checks in our policy was reversed:

policyaction( :publish ) do
authorize_ifactor_attribute_equals( :role , "admin" )
forbid_ifexpr(published== true)
end

Then the logic is actually a bit different. Now we only check the published
attribute if the first check doesn’t make a decision. To not make a decision,
the actor would have to have role attribute that doesn’t equal “admin”. In
other words, this policy would mean that admin users can publish any blog
post. Subtly different, enough to cause unintended behaviour in your app.

If none of the checks in a policy make a decision, the default behaviour of a
policy is to forbid access, as if each policy had a hidden forbid_ifalways() at the
bottom. And once an authorizer is added to a resource, if no policies apply
to a call to an action, then the request will also be forbidden. This is perfect
for security purposes!

Authorizing API Access for Authentication
Now that we have a bit of context around policies and how they can restrict
access to actions, we can check out the policies that were automatically
generated in the Tunez.Accounts.User resource when we installed AshAuthentica-
tion:

Authorizing API Access for Authentication • 133

06/lib/tunez/accounts/user.ex
defmodule Tunez.Accounts.User do
# ...
policies do
bypassAshAuthentication.Checks.AshAuthenticationInteraction do
authorize_ifalways()
end
policyalways() do
forbid_ifalways()
end
end
# ...
end

There are two policies defined in the resource — one bypass (more on
bypasses on page 147 ) and one standard policy. The AshAuthenticationInteraction
module, used in the the bypass, contains a custom policy condition that
applies to any actions called from AshAuthenticationPhoenix’s liveviews, and
it will always authorize them. So the web UI works out of the box, and allows
actions like register_with_password or sign_in_with_magic_link to be run.

The second policy always applies to any other action call (the policy condition),
and it will forbid if , well, always! This includes action calls from any of our
generated API endpoints, and explains why we always got a forbidden error
when we tried to register an account via the API. The User resource is open
for AshAuthentication’s internal action calls, and firmly closed for absolutely
everything else. Let’s update this and write some new policies, to allow access
to the actions we want.

Writing our first user policy

If you test running any actions on the Tunez.Accounts.User resource in iex (without
skipping authorization with authorize?:false, like we did earlieron page 116 ),
you’ll immediately see the forbidden errors that were getting processed by
AshJsonApi, and returned in our API responses.

iex(1)> Tunez.Accounts.User
Tunez.Accounts.User
iex(2)> |> Ash.Changeset.for_create( :register_with_password , %{ email:
...(2)> «email» , password:"password" , password_confirmation:"password" })
#Ash.Changeset< ...>
iex(3)> |> Ash.create()
{:error,%Ash.Error.Forbidden{...}}

It wouldn’t hurt to have some of the actions on the resource, such regis-
ter_with_password and sign_in_with_password, accessible over the API. To do that, you
can remove the policy always() policy — if there are no policies in a policies block

Chapter 6. Authorization: What Can You Do? • 134

that apply to an action, it will be forbidden by default. We can replace it with a
new policy, one that will authorize calls to those actions:
06/lib/tunez/accounts/user.ex
policies do
bypassAshAuthentication.Checks.AshAuthenticationInteraction do
authorize_ifalways()
end
➤ policyaction([ :register_with_password , :sign_in_with_password ]) do
➤ authorize_ifalways()
➤ end
end
This is the most permissive type of policy check. As it says on the tin, it always
authorizes any action that meets the policy condition — any action that has
one of those two names.
Authorizing a sign-in action does not mean the sign-in will be successful!
It’s important to note the distinction between an action being
authorized (“this user is allowed to run this action”), and an action
returning a successful result (“this user provided valid credentials
and is now signed in”). It can get a little murky, especially around
authentication-related actions.
In our example, if a user attempts to sign-in with an incorrect
password, the action will now be authorized, so the sign-in action
will run... and return an authentication failure because of the
incorrect password.
With that policy in place, if you re-run the action to register a user in iex, it
will now have a very different result:
iex(1)> Tunez.Accounts.User
Tunez.Accounts.User
iex(2)> |> Ash.Changeset.for_create( :register_with_password , %{ email:
...(2)> «email» , password:"password" , password_confirmation:"password" })
#Ash.Changeset< ...>
iex(3)> |> Ash.create()
{:ok,#Tunez.Accounts.User< ...> }
This is what we want! Is that all we needed to do, to make it accessible over
the API?

Authorizing API Access for Authentication • 135

Authenticating via JSON
When we left the JSON API at the end of the previous chapter, we’d configured
a route in our Tunez.Accounts domain for the register_with_password action of the
User resource, but it didn’t quite work:
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
Now that we’ve updated the policies to authorize the action, will accessing
this API endpoint work, and successfully create a new user? We can test it
with an API client again:
It does create a user! But the response isn’t quite right. When we tested out
authentication earlier in Testing authentication actions in iex, on page 116 ,
we saw that the user data included an authentication token as part of its
metadata, to be used to authenticate future requests.
iex(11)> |> Ash.read( authorize?: false)
{:ok,[#Tunez.Accounts.User< ...> ]
iex(12)> { :ok , [user]}= v()
{:ok,[#Tunez.Accounts.User< ...> ]}
iex(13)> user.__metadata__.token
Chapter 6. Authorization: What Can You Do? • 136

"eyJhbGciOi..."
That was for sign-in, not registration, but the same principle applies — when
you register an account, you’re typically automatically signed into it.
This token needs to be included as part of the response, so API clients can
store it and send it as a request header with future requests to the API.
Tunez
API Client
I am Bob, this is my password
Yes you are, here's your auth token
Here's my auth token
Hi, Bob!
This is handled for us with AshAuthenticationPhoenix, with cookies and
sessions, but for an API the clients must handle it themselves.
In AshJsonApi, we can attach metadata to an API response^2 — this can include
any arbitrary data from anywhere. The user’s authentication token sounds
like a good fit! The metadata option for a route takes a three-argument function
that includes the data being returned in the response (the created user), and
returns a map of data to include, so we can extract the token and return it:
06/lib/tunez/accounts.ex
post :register_with_password do
route "/register"
➤ metadata fn _subject,user,_request->
➤ %{ token: user.metadata.token}
➤ end
end
And now it will work as we expect! The token gets returned, and can now be
used to authenticate subsequent responses.
The exact same process can be used for creating the sign-in route — give it
a nice URL, and add the token to the response:
06/lib/tunez/accounts.ex
base_route "/users" , Tunez.Accounts.User do

https://hexdocs.pm/ash_json_api/dsl-ashjsonapi-resource.html#json_api-routes-post-metadata
Authorizing API Access for Authentication • 137

# ...
➤ post :sign_in_with_password do
➤ route "/sign_in"
➤
➤ metadata fn _subject,user,_request ->
➤ %{ token: user.metadata.token}
➤ end
➤ end
end
Other authenticated-related actions, such as magic links or password reset-
ting, don’t make as much sense to perform over an API — they all require
following links in emails that go to the app to complete. It can be done, but
it’s a much less common use case so we’ll leave it as an exercise to the reader!
(Hint: for generic actions, such as request_password_reset_with_password, you’ll need
to use the route DSL^3 to create the API route.)

Authenticating via GraphQL
Adding support for authentication to our GraphQL API is a little bit easier
than for the JSON API, now that we’ve granted access to the actions via our
policies — some of the abstractions around metadata are already built into
the library.
To get started, extend the Tunez.Accounts.User resource with AshGraphql, using
Ash’s extend patcher:
$ mix ash.extendTunez.Accounts.Usergraphql
This will configure our GraphQL schema, domain module, and resource with
everything we need to start creating queries and mutations for actions.
AshGraphql is strict in regards to which types of actions can be defined as
mutations, and which as queries. Read actions must be queries; creates,
updates and destroys must be mutations; and generic actions can be either.
So for the two actions we want to make accessible over GraphQL — create
:register_with_password must be added as a mutation, and read :sign_in_with_password
must be a query.
To create a mutation for the register_with_password action, define a new graphql
block in the Tunez.Accounts domain module and populate it using the create
macro:^4
https://hexdocs.pm/ash_json_api/dsl-ashjsonapi-domain.html#json_api-routes-base_route-route
https://hexdocs.pm/ash_graphql/dsl-ashgraphql-domain.html#graphql-mutations-create
Chapter 6. Authorization: What Can You Do? • 138

06/lib/tunez/accounts.ex
defmodule Tunez.Accounts do
use Ash.Domain, extensions: [AshGraphql.Domain,AshJsonApi.Domain]
➤ graphql do
➤ mutations do
➤ createTunez.Accounts.User, :register_with_password , :register_with_password
➤ end
➤ end
# ...
This is exactly the same as mutations we added for creating or updating artist
and album rcerds — the type of action, the name of the resource module, the
name to use for the generated mutation, and the name of the action.
In the GraphQL playground, at http://localhost:4000/gql/playground, the new mutation
appears as part of the schema:

And that’s all that needs to be done! AshGraphql can tell that the action has
metadata, and that metadata should be exposed as part of the response. You
can test it out in the GraphQL playground, by calling the mutation with an
email, password, and password confirmation, the same way as you would on
the web registration form, and reading back the token as part of the metadata:
mutation {
registerWithPassword(input:{email: "test@example.com" , password: "mypassword" ,
passwordConfirmation: "mypassword" }) {
result{
id
email
}
Authorizing API Access for Authentication • 139

metadata{
token
}
}
}
To create a query for the sign_in_with_password action, update the graphql block in
the Tunez.Accounts domain module and add the query using the get macro:^5
06/lib/tunez/accounts.ex
defmodule Tunez.Accounts do
use Ash.Domain, extensions: [AshGraphql.Domain,AshJsonApi.Domain]
graphql do
➤ queries do
➤ get Tunez.Accounts.User, :sign_in_with_password , :sign_in_with_password
➤ end

# ...
This macro is typically for fetching records by their primary key, or id, and
this is reflected in the GraphQL playground’s schema — the query takes an
email and password as inputs, but also an id input. Not what we want! We can
disable this id input by adding identityfalse^6 to our query definition.
We can now call the query in the playground, and get either user data back,
or an authentication failure if we provided invalid credentials. The successful
response doesn’t contain the user’s authentication token, though, and we
need that!
AshGraphql has the hidden ability to generate custom types that include
metadata in them, using the type_name option^7 for a query. The default type
name is what we’ve defined in the resource — in this case, the type name :user
was automatically added to our Tunez.Accounts.User resource. If we update that
in our query options, to any other value, the metadata from the action will
now be included in the response, as a new type will be generated that can
include it. Not all actions that return users will have metadata, so the meta-
data fields can’t be added to the base user GraphQL type!
With a new type name added for this query, it can now return the user’s
authentication token as part of a successful response:
06/lib/tunez/accounts.ex
queries do
get Tunez.Accounts.User, :sign_in_with_password , :sign_in_with_password do
https://hexdocs.pm/ash_graphql/dsl-ashgraphql-domain.html#graphql-queries-get
https://hexdocs.pm/ash_graphql/dsl-ashgraphql-domain.html#graphql-queries-get-identity
https://hexdocs.pm/ash_graphql/dsl-ashgraphql-domain.html#graphql-queries-get-type_name
Chapter 6. Authorization: What Can You Do? • 140

identityfalse
➤ type_name :user_with_token
end
end
The user token returned as part of the API response can then be used to
authenticate subsequent API requests, by setting the token in an Authorization
HTTP header.

And now users can successfully sign in, register, and authenticate via both
of our APIs!
Let’s take a look back at how much code we needed to write, to implement
this new functionality:
API configuration in the Accounts domain module, to make our existing
register_with_password and sign_in_with_password User resource actions accessible
over our GraphQL and JSON APIs
A new policy in our User resource, to allow public access to the two actions
And... that’s it! With just a few lines of DSL code, we’ve got a robust authen-
tication system for two different API frameworks!
Now we can look at more general authorization, for the rest of Tunez. This
data isn’t going to secure itself!
Assigning Roles to Users
Access control — who can access what — is a massive topic. Systems to
control access to data can range from the simple (users can perform actions
based on a single role), to the more complex (users can be assigned to one or
more groups, each with its own permissions; or hold different roles within
different groups) to the very very fine-grained (users can be granted specific
permissions per piece of data, on top of everything else).
What level of access control you need heavily depends on the specific app
you’re building, and it may change over time. For Tunez right now, we don’t
Assigning Roles to Users • 141

need anything really complicated, we only want to make sure data doesn’t
get vandalized, so we’ll implement a more simple system with roles.
Each user will have an assigned role , which determines what actions they
can take and what data they can modify. We’ll have three different roles:
Basic users won’t be able to modify any artist/album data
Editors will be able to create/update a limited set of data
Admins will be able to perform any action across the app
This role will be stored in a new attribute in the Tunez.Accounts.User resource,
named role. What type of attribute should it be, though? It could be an atom,
and we could add a constraint^8 to specify that it must be one of our list of
valid role atoms:
attributes do
# ...
attribute :role , :atom do
allow_nil?false
default :user
constraints[ one_of: [ :admin , :editor , :user ]]
end
end
Ash provides a better way to handle enum-type values, though, with the
Ash.Type.Enum^9 behaviour. We can define our roles in a separate Tunez.Accounts.Role
module:
06/lib/tunez/accounts/role.ex
defmodule Tunez.Accounts.Role do
use Ash.Type.Enum, values: [ :admin , :editor , :user ]
end
And then specify that the role attribute is actually a Tunez.Accounts.Role:
06/lib/tunez/accounts/user.ex
attributes do
# ...
➤ attribute :role , Tunez.Accounts.Role do
➤ allow_nil?false
➤ default :user
➤ end
end

https://hexdocs.pm/ash/dsl-ash-resource.html#attributes-attribute-constraints
https://hexdocs.pm/ash/Ash.Type.Enum.html
Chapter 6. Authorization: What Can You Do? • 142

This has a couple of neat benefits. We can fetch a list of all of the valid roles,
with Tunez.Accounts.Role.values/0, and we can also specify human-readable values
for each role, useful if you wanted a page where you could select a role from
a dropdown list.
Generate a migration for the new role attribute, and run it:
$ mix ash.codegenadd_role_to_users
$ mix ash.migrate
The attribute is created as a text column in the database, and the default
option^10 we used is also passed through to be a default in the database. This
means that we don’t need to manually set the role for any existing users, or
any new users that sign up for accounts, they’ll all automatically have the
role user.
What about custom logic for assigning roles?
Maybe you don’t want to hardcode a default role for all users — maybe you want to
assign the ‘editor‘ role to users who register with a given email domain, for example.
You can implement this with a custom change module, similar to UpdatePreviousNames
on page 57. The wrinkle here is that users can be created either from signing up with
a password, or signing in with a magic link (which creates a new account if one doesn’t
exist for that email address). The change code would need to be used in both actions,
and support magic link sign-ins for both new and existing accounts.
We do need some way of changing an user’s role though, otherwise Tunez
will never have any editors or admins! We can add some utility actions to the
Tunez.Accounts.User resource — a read action that will allow fetching a single user
by id, and and a new update action that only allows setting the role attribute
for a given user record:
06/lib/tunez/accounts/user.ex
actions do
defaults[ :read ]
➤ update :set_role do
➤ accept[ :role ]
➤ end

# ...
10.https://hexdocs.pm/ash/dsl-ash-resource.html#attributes-attribute-default
Assigning Roles to Users • 143

Adding code interfaces for the two new actions will make them easier to run,
so we can add those within the Tunez.Accounts.User resource definition in the
Tunez.Accounts domain module.
06/lib/tunez/accounts.ex
defmodule Tunez.Accounts do
# ...
resources do
# ...
➤ resourceTunez.Accounts.User do
➤ define :set_user_role , action::set_role , args: [ :role ]
➤ define :get_user_by_id , action::read , get_by: [ :id ]
➤ end

As we will never be calling these actions from code, only running them man-
ually in an iex console, we don’t need to add a policy that will authorize them
— we can skip authorization using the authorize?:false option when we call them.
Once you’ve registered an account in your development Tunez app, you can
then change it to be an admin in iex:
iex(1)> user= Tunez.Accounts.get_user_by_id!( «uuid» , authorize?: false)
#Tunez.Accounts.User< ...>
iex(2)> Tunez.Accounts.set_user_role(user, :admin , authorize?: false)
{:ok,#Tunez.Accounts.User<role::admin, ...> }
Now that we have users with roles, we can define which roles can perform
which actions. We can do this by writing some more policies, to cover actions
in our Artist and Album resources.
Writing Policies for Artists
There are two parts we need to complete, when implementing access control
in an Ash web app:
Creating the policies for our resources, and
Updating our web interface to pass the actor to calls to our actions, as
well as niceties like hiding buttons to perform actions if the current user
doesn’t have permission to run them.
Which order you do them in is up to you, but both will need to be done.
Writing the policies first will break the web interface completely (everything
will be forbidden, without knowing who is trying to load or modify data!) but
doing it first will ensure we catch all permission-related issues when tweaking
our liveviews. We’ll write the policies first, while they’re fresh in our minds.
Chapter 6. Authorization: What Can You Do? • 144

Creating our first artist policy
To start adding policies to a resource for the first time, we first need to config-
ure it with the Ash policy authorizer. In the Tunez.Music.Artist resource, that
looks like this:
06/lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
use Ash.Resource,
otp_app::tunez ,
domain: Tunez.Music,
data_layer: AshPostgres.DataLayer,
extensions: [AshGraphql.Resource,AshJsonApi.Resource],
➤ authorizers: [Ash.Policy.Authorizer]

Testing a create action
The default behaviour in Ash is to authorize (run policy checks for) any action
in a resource that has an authorizer configured, so straight away we get for-
bidden errors when attempting to run any actions on the Tunez.Music.Artist
resource:
iex(1)> Tunez.Music.create_artist(%{ name:"New Artist" })
{:error,
%Ash.Error.Forbidden{
bread_crumbs:["Errorreturned from:Tunez.Music.Artist.create"],
changeset:"#Changeset<>",
errors:[%Ash.Error.Forbidden.Policy{...}]
}
}
There are no policies for the create action, so it is automatically forbidden.
We can add a policy for the action by adding a new policies block at the top
level of the Tunez.Music.Artist resource, and adding a sample policy that applies
to the action:
06/lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
# ...
policies do
policyaction( :create ) do
authorize_ifalways()
end
end
end
This is the most permissive type of policy check — it always authorizes the
given policy. With this policy in our resource, after recompiling we can now
create artists again:
Writing Policies for Artists • 145

iex(1)> Tunez.Music.create_artist(%{ name:"New Artist" })
{:ok,#Tunez.Music.Artist< ...> }

There are a whole set of policy checks built into Ash,^11 but the most common
ones for policy conditions are action and action_type. Our policy, as written, only
applies to the action named create, but if we wanted to use it for any action
of type create, we could use action_type(:create) instead.

Of course, we don’t always want to blanket authorize actions, as that would
defeat the purpose of authorization entirely. Let’s update the policy to only
allow admin users to create artist records, ie. actors who have their role
attribute set to “admin”:

06/lib/tunez/music/artist.ex
policies do
policyaction( :create ) do
authorize_ifactor_attribute_equals( :role , :admin )
end
end

Because our policy refers to an actor, we have to pass in the actor when
calling the action. If we don’t, or pass in nil instead, the check won’t make a
decision. If none of the checks specifically authorize the policy, it safely
defaults to being unauthorized. We can test what the action does in iex, by creating
different types of Tunez.Accounts.User structs and running the create action:

iex(2)> Tunez.Music.create_artist(%{ name:"New Artist" })
{:error,%Ash.Error.Forbidden{...}}

iex(3)> Tunez.Music.create_artist(%{ name:"New Artist" }, actor: nil)
{:error,%Ash.Error.Forbidden{...}}

iex(4)> editor= %Tunez.Accounts.User{ role::editor }
#Tunez.Accounts.User<role::editor, ...>
iex(5)> Tunez.Music.create_artist(%{ name:"New Artist" }, actor: editor)
{:error,%Ash.Error.Forbidden{...}}

iex(6)> admin= %Tunez.Accounts.User{ role::admin }
#Tunez.Accounts.User<role::admin, ...>
iex(7)> Tunez.Music.create_artist(%{ name:"New Artist" }, actor: admin)
{:ok,#Tunez.Music.Artist< ...> }

The only actor that was authorized to create the artist record was the admin
user — just as we intended.

11.https://hexdocs.pm/ash/Ash.Policy.Check.Builtins.html

Chapter 6. Authorization: What Can You Do? • 146

Filling out update and destroy policies

In a similar way, we can write policies for the update and destroy actions in the
Tunez.Music.Artist resource. Admin users should be able to perform both actions;
and we’ll also allow editors (users with role: :editor) to update records.

06/lib/tunez/music/artist.ex
policies do
# ...
policyaction( :update ) do
authorize_ifactor_attribute_equals( :role , :admin )
authorize_ifactor_attribute_equals( :role , :editor )
end
policyaction( :destroy ) do
authorize_ifactor_attribute_equals( :role , :admin )
end
end

If an editor attempts to update an artist record, the first check won’t make a
decision — their role isn’t “admin”, so the next check is looked at. This one
makes a decision to authorize, so the policy is authorized and the action will
run.

Cutting out repetitiveness with bypasses

When we have some all-powerful role like admin, it can be really repetitive to
write authorize_ifactor_attribute_equals(:role, :admin) in every. Single. Policy. It’d be
much nicer to be like, oh, these users? They’re special, just let ‘em on through.
We can do that by using a bypass.^12

With standard policies defined using policy, all applicable policies for an action
must apply. This allows for cases like the following:

policyaction_type( :update ) do
authorize_ifactor_present()
end

policyaction( :force_update ) do
authorize_ifactor_attribute_equals( :role , "admin" )
end

Our hypothetical resource has a few update-type actions that any authenticated
user can run (using the built-in actor_present policy check),^13 but also a special
force_update that only admin users can run. It’s not that the action(:force_update)
policy takes precedence over the action_type(:update) policy, it’s that both policies

12.https://hexdocs.pm/ash/dsl-ash-policy-authorizer.html#policies-bypass
13.https://hexdocs.pm/ash/Ash.Policy.Check.Builtins.html#actor_present/0

Writing Policies for Artists • 147

apply when calling the force_update action, but only one applies to other update
actions.

Bypass policies are different. If a bypass policy authorizes an action, it can
skip all other policies that apply to that action.

bypassactor_attribute_equals( :role , "admin" ) do
authorize_ifalways()
end

# If the bypasspasses,thenthe resultof thispolicydoesn'tmatter!
policyaction_type( :update ) do
forbid_ifalways()
end

We say that a bypass can skip other policies, not that it will , because it’s a
little more complicated than that — order matters when it comes to mixing
bypass policies with standard policies.

Internally, Ash converts the results of running each policy into a big boolean
expression with passing authorization being true and failing authorization
being false, which is evaluated by the SAT solver we installed earlier. Standard
policies are AND-ed into the expression, so all need to be authorized for the
action to be authorized. Bypass policies are OR-ed into the expression, so
changing the order of policies within a resource can drastically affect the
result. See the following example, where the policy results are the same, but
the order is different, leading to a different overall result:

bypass (pass)
policy (fail)
policy (pass)
pass OR (fail AND pass) pass OR fail PASS!
bypass (pass)
policy (fail)
policy (pass)
fail AND (pass OR fail) fail AND pass FAIL!
What does this mean when writing policies? Bypasses are really powerful,
and allow abstracting common authorization logic into one place. It’s possible
to encode very complicated logic, but it’s also pretty easy to make a mess or
have unintended results. We’d recommend the following guidelines:

Chapter 6. Authorization: What Can You Do? • 148

Keep all bypass policies together at the start of the policies block, and don’t
intermingle them with standard policies, and
Write naive tests for your policies that test as many combinations of per-
missions as possible, to verify that the behaviour is what you expert. More
on testing in the next chapteron page 169.
Debugging when policies fail

Policies can get complex, with multiple conditions in each policy check, mul-
tiple policy checks of different types within a policy, and as we’ve just seen,
multiple policies that apply to a single action request, including bypasses.

We can tell if authorization fails, because we get an Ash.Error.Forbidden struct
back from the action request, but we can’t necessarily see why it might fail.

Ash can display breakdowns of how policies were applied to an action request.
Similar to how we set a config option to debug authentication failures in the
last chapter, we can do the same thing for policies.^14

In your dev config in config/dev.exs, turn on policy breakdowns:

06/config/dev.exs
config :ash , :policies , show_policy_breakdowns?: true

After restarting your iex session, repeat the previous experiment by trying to
create an artist with an actor that isn’t an admin:

iex(1)> editor= %Tunez.Accounts.User{ role::editor }
#Tunez.Accounts.User< ...>
iex(2)> Tunez.Music.create_artist!(%{ name:"Oh no!" }, actor: editor)
****** (Ash.Error.Forbidden)
BreadCrumbs:

Errorreturnedfrom:Tunez.Music.Artist.create

ForbiddenError

***** forbidden:

Tunez.Music.Artist.create

PolicyBreakdown
user:%{id:nil}
Policy| [M]:
condition:action== :create
authorizeif: actor.role== :admin|✘| [M]

SAT Solverstatement:

"action== :create"and
14.https://hexdocs.pm/ash/policies.html#policy-breakdowns

Writing Policies for Artists • 149

(("action== :create"and "actor.role== :admin")
or not "action== :create")
Note that the [M]s are actually magnifying glass emojis in the terminal.

Similar output can be seen in a browser, if you attempt to visit the app
(because it’s all broken right now!) It’s a little bit verbose, but it clearly states
which policies have applied to this action call, and what the results were —
this user was not an admin, so they get a big ✘.

Filtering results in read action policies

The last actions we have to address in the Artist resource are our two read
actions — the default read action, and our custom search action.

So far we’ve only looked at checks for single records, with yes/no answers —
can the actor run this action on this record, yes or no? Read actions are built
a little differently, as they don’t start with an initial record to operate on and
they don’t modify data. Policies for read actions behave as filters — given all
of the records that the action would fetch, which ones are the actor allowed
to see?

If, for example, we had the following policy that uses a secret attribute:

policyaction_type( :read ) do
authorize_ifexpr(secret== false)
end

You can call the action as normal, via code like MyResource.read(actor: user), and
the results will only include records where the secret attribute has the value
false.

If a policy check would have different answers depending on the record being
checked (ie. it checks some property of the record, like the value of the secret
attribute) we say this is a filter check. If it depends only on the actor, or a
static value like always(), then we say it’s a simple check.

Filter checks and simple checks can be included in the same policy, eg. to
allow admins to read all records, but non-admins can only read non-secret
records:

policyaction_type( :read ) do
authorize_ifexpr(secret== false)
authorize_ifactor_attribute_equals( :role , "admin" )
end

Chapter 6. Authorization: What Can You Do? • 150

Trust, but verify!
One quirk of read policies is distinguishing between “the actor
can’t run the action” and “the actor can run the action, but all of
the results are filtered out”.
By default, all read actions are runnable and all checks are applied
as filters. If you want the whole action to be forbidden on autho-
rization failure, this can be configured in the policy using the
access_type option.^15
The following policy check would allow admin users to run it and
fetch results, but non-admin users would get an forbidden error.
policyaction( :read_banned_users ) do
access_type :strict
authorize_ifactor_attribute_equals( :role , "admin" )
end
Tunez won’t have any restrictions on reading artists, but we do need to have
policies for all actions in a resource once we start adding them, so we can
add a blanket authorize_ifalways() policy:

06/lib/tunez/music/artist.ex
policies do
# ...
policyaction_type( :read ) do
authorize_ifalways()
end
end

Removing Forbidden Actions from the UI
At the moment, the Artist resource in Tunez is secure — actions that modify
data can only be called if a) we pass in a user record as the actor and b) that
actor is authorized to run that action. So far, so good.

The web UI doesn’t reflect these changes, though. Even when not logged in
to the app, we can still see buttons and forms inviting us to create, edit, or
delete data.

15.https://hexdocs.pm/ash/policies.html#access-type

Removing Forbidden Actions from the UI • 151

We can’t actually run the actions, so clicking the buttons and submitting the
forms will return an error, but it’s not a good user experience to see them at
all. And if we are logged in, so we should have access to manage data, we still
get an error! Oops.

There are a few things we need to do, to make the UI behave correctly for any
kind of user viewing it:

Update all of our action calls to pass the current user as the actor
Update our forms to ensure we only let the current user see them if they
can submit them
And lastly, update our templates to only show buttons if the current user
is able to use them.
It sounds like a lot, but it’s only a few changes to make, spread across a few
different files. Let’s dig in!

Identifying the actor when calling actions

For a more complex app, this would be the biggest change from a functional-
ity perspective — allowing actions to be called by users who are authorized
to do things. Tunez is a lot simpler, and most of the data management is done
via forms, so this isn’t a massive change for us. The only actions we call
directly are read and destroy actions:

Tunez.Music.search_artists/2, in Tunez.Artists.IndexLive. We don’t strictly need to
pass the actor in here, as our current policies will allow the action for
everyone even if they’re not authenticated, but that could change in the
Chapter 6. Authorization: What Can You Do? • 152

future. If it does, we don’t want to forget to set the actor, so we may as
well do it now!
06/lib/tunez_web/live/artists/index_live.ex
def handle_params(params,_url,socket) do
# ...
page=
Tunez.Music.search_artists!(query_text,
page: page_params,
query: [ sort_input: sort_by],
➤ actor: socket.assigns.current_user
)

Tunez.Music.get_artist_by_id/2, in Tunez.Artists.ShowLive. Again, we don’t strictly
need it because everyone can read artist information, but like the
search_artists action, we can’t guarantee that this will always be the case in
the future. It does no harm to set the actor either, so we’ll add it.
06/lib/tunez_web/live/artists/show_live.ex
def handle_params(%{ "id" => artist_id},_session,socket) do
artist=
Tunez.Music.get_artist_by_id!(artist_id,
load: [ :albums ],
➤ actor: socket.assigns.current_user
)
Tunez.Music.get_artist_by_id/2, in Tunez.Artists.FormLive. Same as above!
06/lib/tunez_web/live/artists/form_live.ex
def mount(%{ "id" => artist_id},_session,socket) do
artist= Tunez.Music.get_artist_by_id!(artist_id,
➤ actor: socket.assigns.current_user
)
# ...
Tunez.Music.destroy_artist/2, in Tunez.Artists.ShowLive. This one we do need to pass
the actor in to make it work, as only specific types of users can delete
artists.
06/lib/tunez_web/live/artists/show_live.ex
def handle_event( "destroy-artist" , _params,socket) do
case Tunez.Music.destroy_artist(
socket.assigns.artist,
➤ actor: socket.assigns.current_user
) do
# ...
Removing Forbidden Actions from the UI • 153

Tunez.Music.destroy_album/2, in Tunez.Artists.ShowLive. We haven’t added policies
for albums yet, but it does no harm to start tweaking our templates to
support them now.
06/lib/tunez_web/live/artists/show_live.ex
def handle_event( "destroy-album" , %{ "id" => album_id},socket) do
case Tunez.Music.destroy_album(
album_id,
➤ actor: socket.assigns.current_user
) do
# ...
Tunez.Music.get_album_by_id/2, in Tunez.Albums.FormLive. We don’t technically need
authorization here either, but this is good practice for future-proofing.
06/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "id" => album_id},_session,socket) do
album= Tunez.Music.get_album_by_id!(album_id,
load: [ :artist ],
➤ actor: socket.assigns.current_user
)
# ...
Tunez.Music.get_artist_by_id/2, in Tunez.Albums.FormLive. Same as above!
06/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "artist_id" => artist_id},_session,socket) do
artist= Tunez.Music.get_artist_by_id!(artist_id,
➤ actor: socket.assigns.current_user
)
# ...
Not too onerous! Moving forward, we’ll add the actor to every action we call,
to avoid this kind of rework.
Updating forms to identify the actor
We also need to add authorization checks to forms, as we create and edit both
artists and albums via forms. There are two parts to this: setting the actor
when building the forms, and ensuring that the form is submittable.
We don’t want to show the form at all if the user wouldn’t be able to submit
it, so we need to run the submittable check before rendering, in the mount/3
functions of Tunez.Artists.FormLive:
06/lib/tunez_web/live/artists/form_live.ex
def mount(%{ "id" => artist_id},_session,socket) do
# ...
form=
Chapter 6. Authorization: What Can You Do? • 154

Tunez.Music.form_to_update_artist(
artist,
➤ actor: socket.assigns.current_user
)
➤ |> AshPhoenix.Form.ensure_can_submit!()

# ...
def mount(_params,_session,socket) do
form=
Tunez.Music.form_to_create_artist(
➤ actor: socket.assigns.current_user
)
➤ |> AshPhoenix.Form.ensure_can_submit!()

AshPhoenix.Form.ensure_can_submit!/1^16 is a neat little helper function that authorizes
the configured action and data in the form using our defined policies, to make
sure it is submittable. If the authorization fails, then the form can’t be sub-
mitted, and an exception will be raised.
We can make the same changes to the mount/3 functions in Tunez.Albums.FormLive:
06/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "id" => album_id},_session,socket) do
# ...
form=
Tunez.Music.form_to_update_album(
album,
➤ actor: socket.assigns.current_user
)
➤ |> AshPhoenix.Form.ensure_can_submit!()

# ...
def mount(%{ "artist_id" => artist_id},_session,socket) do
# ...
form=
Tunez.Music.form_to_create_album(
transform_params: fn _form,params,_context->
Map.put(params, "artist_id" , artist.id)
end ,
➤ actor: socket.assigns.current_user
)
➤ |> AshPhoenix.Form.ensure_can_submit!()

Now if you click any of the buttons that link to pages focussed on forms, when
not logged in as a user with the correct role, an exception will be raised and
you’ll get a standard Phoenix error page:
16.https://hexdocs.pm/ash_phoenix/AshPhoenix.Form.html#ensure_can_submit!/1
Removing Forbidden Actions from the UI • 155

That works well for forms — but what about entire pages? Maybe we’ve built
an admin-only area, or we’ve added an Artist version history page that only
editors can see. We can’t use the same form helpers to ensure access, but we
can prevent users from accessing what they shouldn’t.

Blocking pages from unauthorized access

When we installed AshAuthenticationPhoenix, one file that the installer cre-
ated was the TunezWeb.LiveUserAuth module, in lib/tunez_web/live_user_auth.ex. We
haven’t looked at that file yet, but we will now!

It contains several on_mount function definitions, that do different things based
on the authenticated user (or lack of) — the live_user_optional function head will
make sure there’s always a current_user set in the socket assigns, even if it’s
nil; the live_user_required function head will redirect away if there’s no user logged
in, and the live_no_user function head will redirect away if there is a user logged
in!

These are LiveView-specific helper functions,^17 that can be called at the root
level of any liveview like so:

defmodule Tunez.Accounts.ForAuthenticatedUsersOnly do
use TunezWeb, _:live_view

or :live_user_optional,or :live_no_user_
on_mount{TunezWeb.LiveUserAuth, :live_user_required }
# ...

So to block a liveview from unauthenticated users, we could drop that on_mount
call with :live_user_required in that module, and the job would be done!

We can add more function heads to the TunezWeb.LiveUserAuth module as well
for custom behaviour, such as role-based function heads.

06/lib/tunez_web/live_user_auth.ex
defmodule TunezWeb.LiveUserAuth do
# ...

17.https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#on_mount/1

Chapter 6. Authorization: What Can You Do? • 156

def on_mount([ role_required: role_required],_, _, socket) do
current_user= socket.assigns[ :current_user ]
if current_user&& current_user.role == role_required do
{ :cont , socket}
else
socket=
socket
|> Phoenix.LiveView.put_flash( :error , "Unauthorized!" )
|> Phoenix.LiveView.redirect( to: ~ p "/" )
{ :halt , socket}
end
end
end

This would allow us to write on_mount calls in a liveview like:

defmodule Tunez.Accounts.ForAdminsOnly do
use TunezWeb, :live_view
on_mount{TunezWeb.LiveUserAuth, role_required::admin }
# ...

Now we can secure all of our pages really neatly, both those that are form-
based, and those that aren’t. We still shouldn’t see any shiny tempting buttons
for things we can’t access, though, so let’s hide them if the user can’t perform
the actions.

Hiding calls to action that the actor can’t perform

There are buttons sprinkled throughout our liveviews and components —
buttons for creating, editing, and deleting artists; and for creating, updating
and deleting albums. We can use Ash’s built-in helpers to add general
authorization checks to each of them, meaning we don’t have to duplicate
any policy logic and we won’t need to update any templates if our policy rules
change.

Ash.can?

The first helper function we’ll look at is Ash.can?.^18 This is a pretty low-level
function, that takes a tuple representing the action to call and an actor, runs
the authorization checks for the action, and returns a boolean representing
whether or not the action is authorized:

iex(1)> Ash.can?({Tunez.Music.Artist, :create }, nil)
false

18.https://hexdocs.pm/ash/Ash.html#can?/3

Removing Forbidden Actions from the UI • 157

iex(2)> Ash.can?({Tunez.Music.Artist, :create }, %{ role::admin })
true
iex(3)artist= Tunez.Music.get_artist_by_id!( «uuid» )
#Tunez.Music.Artist<id: «uuid» , ...>
iex(4)> Ash.can?({artist, :update }, %{ role::user })
false
iex(5)> Ash.can?({artist, :update }, %{ role::editor })
true

The format of the action tuple looks a lot like how you would run the action
manually, as we covered in Running actions, on page 13 — building a
changeset for a create action with Ash.Changeset.for_create(Tunez.Music.Artist,:create,
...), or for an update action with Ash.Changeset.for_update(artist,:update,...).

Our liveviews and components don’t call actions like this though, we use code
interfaces for everything because they’re a lot cleaner. Ash also defines some
helper functions around authorization for code interfaces that are nicer to
read, so we’ll look at those next.

can_? code interface functions*

We call these can_*? functions because the names are dynamically generated
based on the name of the code interface. For our Tunez.Music domain, for
example, iex shows a whole set of functions with the can_ prefix:

iex(1)> Tunez.Music.can_
can_create_album/1 can_create_album/2 can_create_album/3
can_create_album?/1 can_create_album?/2 can_create_album?/3
can_create_artist/1 can_create_artist/2 can_create_artist/3
can_create_artist?/1 can_create_artist?/2 can_create_artist?/3
can_destroy_album/2 can_destroy_album/3 can_destroy_album/4
...

This list includes can_? functions for all code interfaces, even ones that don’t
have policies applied yet like Tunez.Music.destroy_album. If authorization isn’t
configured for a resource, both Ash.can? and the can_? functions will simply
return true, so we can safely update our templates to add authorization checks
for all functions without fear of breaking anything.

One important thing to note is the order of arguments to the code interface
helpers. Whereas Ash.can? always takes an action tuple and an actor (plus
options), because some of the action tuple information is now in the function
name, the first argument to a can_*? function is always the actor. If the code
interface needs extra information, like a record to operate on or params, those
come after the actor argument.

iex(4)> h Tunez.Music.can_create_artist?

Chapter 6. Authorization: What Can You Do? • 158

def can_create_artist?(actor, params_or_opts\ %{},opts\ [])
Runsauthorizationchecksfor Tunez.Music.Artist.create,returninga boolean.
See Ash.can?/3for moreinformation
iex(5)> h Tunez.Music.can_update_artist?
def can_update_artist?(actor,record,params_or_opts\ %{},opts\ [])
Runsauthorizationchecksfor Tunez.Music.Artist.update,returninga boolean.
See Ash.can?/3for moreinformation
Armed with this new knowledge, we can now update the buttons in our tem-
plates, to wrap them in HEEx conditionals to only show the buttons if the
relevant can_? function returns true. There’s one button in Tunez.Artists.IndexLive,
for creating an artist:
06/lib/tunez_web/live/artists/index_live.ex
<.* headerresponsive= {false} >
<% # ... %>
➤ <:action:if= {Tunez.Music.can_create_artist?(@current_user)} >
<. button_link [ opts ] >New Artist</. button _link >
</:action>
</. header>
Two buttons in the header of Tunez.Artists.ShowLive, for editing/deleting an artist:
06/lib/tunez_web/live/artists/show_live.ex
<. header>
<% # ... %>
➤ <:action:if= {Tunez.Music.can_destroy_artist?(@current_user, @ artist )} >
<. button_link [ opts ] >DeleteArtist</. button _link >
</:action>
➤ <:action:if= {Tunez.Music.can_update_artist?(@current_user, @ artist )} >
<. button_link [ opts ] >EditArtist</. button _link >
</:action>
</. header>
One above the album list in Tunez.Artists.ShowLive, for creating an album:
06/lib/tunez_web/live/artists/show_live.ex
<.button_linknavigate={ ~ p "/artists/#{ @artist.id }/albums/new" } kind= "primary"
➤ :if= {Tunez.Music.can_create_album?(@current_user)}>
New Album
</.button_link>
And two in the album_details function component in Tunez.Artists.ShowLive, for
editing/deleting an album:
06/lib/tunez_web/live/artists/show_live.ex
<. headerclass= "pl-4pr-2!m-0" >
<% # ... %>
➤ <:action:if= {Tunez.Music.can_destroy_album?(@current_user, @ album )} >

Removing Forbidden Actions from the UI • 159

<. button_link [ opts ]] >Delete</. button _link >
</:action>
➤ <:action:if= {Tunez.Music.can_update_album?(@current_user, @ album )} >
<. button_link [ opts ] >Edit</. button _link >
</:action>
</. header>
For these to work, you also need to update the call to the album_details function
component, to pass the current_user in:
06/lib/tunez_web/live/artists/show_live.ex

➤ <**.** album_detailsalbum= _{album}_ current_user= _{@current_user}_ />
Whew, that was fiddly. Moving forward, we’ll wrap everything in authorization checks as we write it in our templates, so we don’t have to do this kind of tweaking again. **Beware the policy check that performs queries!** Some policy checks can be devious, and require database queries to figure out if an action is authorized or not. They might reference the actor’s group membership, or a count of associated records, or data other than what you’ve loaded for the page to render. For a liveview app, if that related data isn’t loaded and stored in memory, it’ll be re-fetched to recalculate the authorization on every page render, which would be _disastrous_ for performance! You can have Ash make a best guess about authorization using data already in memory, by setting the run_queries?^19 option to Ash.can?/can_*? to false. If a decision can’t be made definitively one way or the other, Ash will use the value of the maybe_is? option — by default this is true, but you can fail closed by setting it to false. _# Authorizebasedon datain memory,defaultingto unauthorized_ Tunez.Music.can_run_complicated_action?(@current_user, _run_queries?:_ false, _maybe_is?:_ false) Everything is now in place for artist authorization — you should be able to log in and out of your Tunez dev app as users with different roles, and the app should behave as expected around managing artist data. We’ve also added
19.https://hexdocs.pm/ash/Ash.html#can?/3
Chapter 6. Authorization: What Can You Do? • 160

authorization checks around album management in our templates — but
don’t have any policies to go with them. We’ll add those now.
Writing Policies for Albums
The rules we want to implement for album management are a little different
to those for artist management. Our rules for artists could be summarized
as:
Everyone can read all artist data
Editors can update (but not create or delete) artists
Admins can perform any action on artist data
For albums, we want to implement the following:
Everyone can read all album data
Editors can create album records, or update/delete album records that
they created
Admins can perform any action on album data
It’s only a small change, but a common use case. In a issue tracker/help desk
app, users might be assigned as owners of tickets and thus have extra per-
missions for those tickets. Or a user might be recorded as the owner of an
organization, and have permissions to invite members to the organization.
The key piece of information we need that we’re not currently storing, is who
is creating each album in Tunez. Once we know that, we can write the policies
that we want.
Recording who created and last modified a resource
To meet our requirements, we only need to store who created each album,
but for a bit of fun we might take it a little bit further, and record who created
and last modified records for both artists and albums.
(It’d be pretty neat to show who last updated an artist, on their profile page!
Maybe later.)
To record this information for artists, we’ll add two new relationships to the
Tunez.Music.Artist resource, both pointing at the Tunez.Accounts.User resource — one
named created_by, and one named updated_by.
06/lib/tunez/music/artist.ex
relationships do
# ...
➤ belongs_to :created_by , Tunez.Accounts.User
➤ belongs_to :updated_by , Tunez.Accounts.User

Writing Policies for Albums • 161

end
We can do the exact same thing to the Tunez.Music.Album resource:
06/lib/tunez/music/album.ex
relationships do
# ...
➤ belongs_to :created_by , Tunez.Accounts.User
➤ belongs_to :updated_by , Tunez.Accounts.User
end
Adding these relationships means an update to the database structure, so
we need to generate a migration for the changes, and run it:
$ mix ash.codegenadd_user_links_to_artists_and_albums
$ mix ash.migrate
Because we’re now identifying the actor,on page 154 every time we submit a
form to create or modify data, we can add changes to some of our actions to
store that actor information in our new relationships. One of Ash’s built-in
change functions is relate_actor,^20 which does exactly what we want — relate
the actor to the record being saved.
We’ll do this a little bit differently than previous changes like UpdatePreviousNames,
though. Storing the actor isn’t really related to the business logic of what we
want the action to do, it’s more of a side effect. We really want to implement
something like “by the way, whenever you create or update a record, can you
also store who made the change? Cheers.” So the logic shouldn’t be restricted
to only the actions named :create and :update, it should apply to all actions of
type create and update.
We can do this with a resource-level changes block. Like validations and
preparations, changes can be added either to individual actions or to the
resource as a whole. In a resource-level changes block, we can also choose
one or more action types that the change should apply to, using the on option.^21
In the Tunez.Music.Artist resource, add a new top-level changes block and add the
changes we want to store.
06/lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
# ...
changes do
changerelate_actor( :created_by , allow_nil?: true), on: [ :create ]
changerelate_actor( :updated_by , allow_nil?: true), on: [ :create ]

20.https://hexdocs.pm/ash/Ash.Resource.Change.Builtins.html#relate_actor/2
21.https://hexdocs.pm/ash/dsl-ash-resource.html#changes-change-on
Chapter 6. Authorization: What Can You Do? • 162

changerelate_actor( :updated_by , allow_nil?: false), on: [ :update ]
end
end
The exact same thing can be added to the Tunez.Music.Album resource:
06/lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
# ...
changes do
changerelate_actor( :created_by , allow_nil?: true), on: [ :create ]
changerelate_actor( :updated_by , allow_nil?: true), on: [ :create ]
changerelate_actor( :updated_by , allow_nil?: false), on: [ :update ]
end
end
These changes mean that if we add more create or update actions to the Artist
or Album resources in future, they’ll automatically have created_by and updated_by
tracked — and we won’t have to do a thing!
Why allow_nil?:true when creating records?
So that if you want to run or re-run the seed data scripts we provide with the starter
Tunez app, they will successfully run both before and after adding these changes!
Depending on your app, you may also want to have nil values representing some kind
of "system" action, if data may be created by means other than a user specifically
submitting a form.
There’s one other change we need to make — as we discovered earlier, the
User resource is really locked-down, permission-wise. To relate the actor to
a record when updating the record, we need to be able to read the actor record
from the database, and at the moment we can’t. All reading of user data is
forbidden, unless being called internally by AshAuthentication.
To get around this, we can add another policy to the User resource, to allow
a user to read their own record:
06/lib/tunez/accounts/user.ex
policies do
# ...
➤ policyaction( :read ) do
➤ authorize_ifexpr(id== ^actor( :id ))
➤ end
end

Writing Policies for Albums • 163

This uses the ^actor expression template^22 to reference the actor calling the
action, as part of the policy condition expression. Like pinning a variable in
a match or an Ecto query, this is how we can reference outside data that isn’t
a literal value (like true or :admin) and isn’t an attribute or calculation on the
resource (like created_by_id).
And that’s all we need to do! Now whenever we call create or update (or their
code interfaces) on either an artist or an album, the user ID of the actor will
be stored in the created_by_id and/or the updated_by_id fields of the resource. You
can test it out in iex, to make sure you’ve connected the pieces properly.
iex(1)> user= Tunez.Accounts.get_user_by_id!( «uuid» , authorize?: false)
#Tunez.Accounts.User<id: «uuid» , role::admin, ...>
iex(2)> Tunez.Music.create_artist(%{ name:"Who MadeMe?" }, actor: user)
{:ok,
#Tunez.Music.Artist<
name:"WhoMadeMe?",
updated_by:#Tunez.Accounts.User<id: «uuid» , ...> ,
created_by:#Tunez.Accounts.User<id: «uuid» , ...> ,
...
>}
Filling out policies
All of the pre-requisite work has been done, the only thing left to do is write
the actual policies for albums!
As with artists, the first step is enabling Ash.Policy.Authorizer in the Tunez.Music.Album
resource:
06/lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
use Ash.Resource,
otp_app::tunez ,
domain: Tunez.Music,
data_layer: AshPostgres.DataLayer,
extensions: [AshGraphql.Resource,AshJsonApi.Resource],
➤ authorizers: [Ash.Policy.Authorizer]

This means that all of our action calls, including auto-loading albums when
loading an artist record (which uses a read action!), will now automatically
run authorization checks. And because we haven’t yet defined any policies,
they will all be forbidden by default.
We can reuse some of the policies that we wrote for artists, as the bulk of the
rules are the same. In a new policies block in the Tunez.Music.Album resource, we
22.https://hexdocs.pm/ash/expressions.html#templates
Chapter 6. Authorization: What Can You Do? • 164

can write a bypass for users with the role “admin”, as they’re allowed to run
every action. As this will be the first policy in the policies block, if it passes, all
other policies will be skipped.

06/lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
# ...
policies do
bypassactor_attribute_equals( :role , :admin ) do
authorize_ifalways()
end
end
end

We can also add an allow-all rule for reading album data — any user,
authenticated or not, should be able to see the full list of albums for any
artist.

06/lib/tunez/music/album.ex
policies do
# ...
policyaction_type( :read ) do
authorize_ifalways()
end
end

The main rules we want to look at are for editors. They’ll have limited func-
tionality — we want them to be able to create albums, and update/delete
albums if they are related to those records via the created_by relationship.

The policy for create actions is pretty straightforward, it can use the same
actor_attribute_equals built-in policy check we’ve used a few times now:

06/lib/tunez/music/album.ex
policies do
# ...
policyaction( :create ) do
authorize_ifactor_attribute_equals( :role , :editor )
end
end

If the actor calling the create action doesn’t have the role “admin” (which would
be authorized by the bypass) or “editor” (which would be authorized by this
create policy), then the action will be forbidden.

Lastly, we can write one policy that covers both the update and destroy actions,
as the rules are identical for both. If we only wanted to verify the created_by

Writing Policies for Albums • 165

relationship link, we could use the built-in relates_to_actor_via policy check,^23
like this:

policyaction([ :update , :destroy ]) do
authorize_ifrelates_to_actor_via( :created_by )
end

We could still technically use this! As only editors can create albums (ignoring
the admin bypass), then if the album was created by the actor, the actor must
be an editor! Right?? But... rules can change. Maybe in some months, a new
“creator” role will be added that can only create records. But by the checks
in this policy, they would also be authorized to update and destroy records,
if they created them. Not good. Let’s make the editor check in this policy
explicit.

We can’t combine built-in policy checks (that would be handy though!), so
we’ll have to fall back to writing an expression, like expr(published== true), to
verify both conditions in the same policy check. We end up with a policy like
the following:

06/lib/tunez/music/album.ex
policies do
# ...
policyaction_type([ :update , :destroy ]) do
authorize_ifexpr(^actor( :role ) == :editor and created_by_id== ^actor( :id ))
end
end

It’s a little verbose, but it clearly captures our requirements — updates and
deletes should be authorized if the actor’s role is “editor”, and the record was
created by the actor.

Test it out in your app! Register a new user, make it an editor with
Tunez.Accounts.set_user_role/2, and see how it behaves! As we already edited all of
the templates to add authorization checks, we don’t need to make any other
changes. Note that your editor doesn’t have access to edit any existing albums,
but if they create a new one, they can then edit that one. Perfect!

And all of our authorization policies have automatically flowed through to
our APIs. Trying to create albums or artists when not being authenticated
will now be forbidden, but when user authentication tokens are provided in
the request headers, the requests will now operate as normal. And we didn’t
need to do anything for that! We defined our policies once, in a central place,
and they apply everywhere.

23.https://hexdocs.pm/ash/Ash.Policy.Check.Builtins.html#relates_to_actor_via/2

Chapter 6. Authorization: What Can You Do? • 166

All this manual testing is getting a bit tiresome, though. We’re starting to get
more complicated logic in our app, and we can’t keep manually testing
everything. In the next chapter, we’ll dive into testing — what to test, how to
test it, and how Ash can help you get the best bang for your testing buck!

Writing Policies for Albums • 167

CHAPTER 7
