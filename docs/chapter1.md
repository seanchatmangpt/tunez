# Building Our First Resource

Hello! You’ve arrived! Welcome!!

In this very first chapter, we’ll start from scratch and work our way up. We’ll
set up the starter `Tunez` application, install `Ash`, and build our first resource
(as the chapter title suggests!). We’ll define attributes, set up actions, and
connect to a database, all while seeing firsthand how Ash’s declarative prin-
ciples simplify the process. By the end, you’ll have a working resource fully
integrated with the Phoenix frontend — and the confidence to take the next
step.

## Getting the Ball Rolling

Throughout this book, we’ll build `Tunez`, a music database app. Think of it
as a lightweight Spotify, without actually playing music — users can browse
a catalog of artists and albums, follow their favorites, and receive notifications
when new albums are released. On the management side, we’ll implement a
role-based access system with customizable permissions, and create APIs
that allow users to integrate `Tunez` data into their own apps.

But `Tunez` is more than just an app — it’s your gateway to mastering Ash’s
essential building blocks. By building `Tunez` step by step, you’ll gain hands-
on experience with resources, relationships, authentication, authorization,
APIs, and more. Each feature we build will teach you foundational skills you
can apply to any project, giving you the toolkit and know-how to tackle larger,
more complex applications with the same techniques. `Tunez` may be small,
but the lessons you’ll learn here will have a big impact on your development
workflow.

A demo version of the final Tunez app can be seen here:

[https://tunez.sevenseacat.net/](https://tunez.sevenseacat.net/)

## Setting up your development environment

One of the (many) great things about the Elixir ecosystem is that we get a lot
of great new functionality with every new version of Elixir, but nothing gets
taken away (at worst, it gets deprecated). So while it would be awesome to
always use the latest and greatest versions of everything, sometimes that’s
not possible, and that’s okay! Our apps will still work with most recent ver-
sions of Elixir, Erlang, and PostgreSQL.

To work through this book, you’ll need at least:

*   `Elixir 1.15`
*   `Erlang 26.0`
*   `PostgreSQL 14.0`

Any newer version will also be just fine!

To install these dependencies, we’d recommend a tool like `asdf`^1 or `mise`.^2

We’ve built an initial version of the `Tunez` app, for you to use as a starting
point. To follow along with this book, clone the app from the following repos-
itory:

[https://github.com/sevenseacat/tunez](https://github.com/sevenseacat/tunez)

If you’re using `asdf`, once you’ve cloned the app, you can run `asdf install` from
the project folder to get all the language dependencies set up. The `.tool-versions`
file in the app lists slightly newer versions than the dependencies listed above,
but you can use any versions you prefer as long as they meet the minimum
requirements.

Follow the setup instructions in the app `README`, including `mix setup`, to make
sure everything is good to go. If you can run `mix phx.server` without errors and
see a styled homepage with some sample artist data, you’re ready to begin!

> The code for each chapter can also be found in the `Tunez` repo on
> GitHub, in branches named after the end of the chapter, e.g. the
> app at the end of chapter 1 can be found at [https://github.com/sevenseacat/tunez/tree/end-of-chapter-1](https://github.com/sevenseacat/tunez/tree/end-of-chapter-1).

[1]: https://asdf-vm.com/
[2]: https://mise.jdx.dev/

Welcome to Ash!

Before we can start using Ash in Tunez, we’ll need to install it and configure
it within the app. Tunez is a blank slate — it has a lot of the views and tem-
plate logic, but no way of storing or reading data. This is where Ash comes
in — it will be our main tool for building out the domain model layer of the
app, the code responsible for reading and writing data from the database,
and implementing our app’s business logic.

To install Ash, we’ll use the Igniter^3 toolkit, which is already installed as a
development dependency in Tunez. Igniter gives library authors tools to write
smarter code generators, including installers, and we’ll see that here with the
igniter.install Mix task.

Run mix igniter.installash in the tunez folder, and it will patch the mix.exs file with
the new package:

$ mix igniter.installash
compile✔

Update:mix.exs

...|
34 34 | defpdepsdo
35 35 | [
36 + | {:ash,"~> 3.0"},
36 37 | {:phoenix,"~> 1.7.14"},
37 38 | {:phoenix_ecto,"~> 4.5"},
...|

Thesedependenciesshouldbe installedbeforecontinuing.Modifymix.exs
and install?[Y/n]

Confirm the change, and Igniter will install and compile the latest version of
the ash package. This will trigger Ash’s own installation Mix task, which will
add Ash-specific formatting configuration in .formatter.exs and config/config.exs.
The output is a little too long to print here, but we’ll get consistent code for-
matting and section ordering across all of the Ash-related modules we’ll write
over the course of the project.

Starting a new app and want to use Igniter and Ash?
Much like the phx_new package is used to generate new Phoenix
projects, Igniter has a companion igniter_new package for generating
projects. You can install it with:
$ mix archive.installhex igniter_new
https://hexdocs.pm/igniter/
Getting the Ball Rolling • 3

Starting a new app and want to use Igniter and Ash?
This gives access to the igniter.new^4 Mix task, which is very powerful.
It can also combine with phx.new so you can use Igniter to scaffold
Phoenix apps that come pre-installed with any package you like
(and will also pre-install Igniter). For example, a Phoenix app with
Ash and ErrorTracker:
$ mix igniter.newyour_new_app_name--withphx.new\
--installash,error_tracker
Installing igniter_new also gives access to the igniter.install Mix task,
so you don’t even need to add Igniter to your project to use it! You
can also add Ash and/or Igniter to the mix.exs file of any existing
app, to get access to all of its goodies.
The Ash ecosystem is made up of many different packages for integrations
with external libraries and services, allowing us to pick and choose only the
dependencies we need. As we’re building an app that will talk to a PostgreSQL
database, we’ll want the PostgreSQL Ash integration. We can use mixigniter.install
to add it to Tunez as well:

$ mix igniter.installash_postgres

You may see a warning at this point about uncommitted changes detected in
your project. Igniter will warn you if your app has changes that haven’t been
committed into Git. This is to prevent accidental data loss if you’ve made code
changes that Igniter might undo or overwrite. All we’ve done so far is install
Ash so it’s fine to continue, but in the future, if you see this message, you
may want to back out and commit your code first, just in case.

Confirm the change to our mix.exs file, and the package will be downloaded
and installed. After completion, this will:

Add and fetch the ash_postgres Hex package (in mix.exs and mix.lock)
Add code auto-formatting for the new dependency (in .formatter.exs and
config/config.exs)
Update the database Tunez.Repo module to use Ash, instead of Ecto (in
lib/tunez/repo.ex). This also includes a list of PostgreSQL extensions to be
installed and enabled by default
Generate our first migration to set up the ash-functions pseudo-extension
listed in the Tunez.Repo module (in priv/repo/migrations/install_ash-
functions_extension.exs)
https://hexdocs.pm/igniter_new/Mix.Tasks.Igniter.New.html
Chapter 1. Building Our First Resource • 4

Generate an extension config file so Ash can keep track of which Post-
greSQL extensions have been installed (in priv/resource_snapshots/repo/exten-
sions.json)
You’ll also see a notice from AshPostgres. It has inferred the version of Post-
greSQL you’re running, and configured that in Tunez.Repo.min_pg_version/0.

And now we’re good to go and can start building!

Resources and domains

In Ash, the central concept is the resource. Resources are domain model
objects, the nouns that our app revolves around — they typically (but not
always!) contain some kind of data and define some actions that can be taken
on that data.

Related resources are grouped together into domains^5 — context boundaries
where we can define configuration and functionality that will be shared across
all connected resources. This is also where we’ll define the interfaces that the
rest of the app uses to communicate with the domain model, much like a
Phoenix context does.

Domains also provide an integration point for extensions. Some extensions,
such as AshAdmin^6 for automatic admin panels, can be enabled or disabled
on a per-domain basis, instead of needing to be configured for every resource
within the domain.

What does this mean for Tunez? Over the course of the book, we’ll define
several different domains for the distinct ideas within the app such as Music
and Accounts; and each domain will have a collection of resources such as
Album, Artist, Track, User, and Notification.

Each resource will define a set of attributes — data that maps to keys of the
resource’s struct. An Artist resource will read/modify records in the form of
Artist structs, and each attribute of the resource will be a key in that struct.
The resources will also define relationships — links to other resources — as
well as actions, validations, pubsub configuration and more.

Do I need multiple domains in my app?
Technically you don’t need multiple domains. For small apps, you can get away with
defining a single domain and putting all of your resources in it, but we want to be
https://hexdocs.pm/ash/domains.html
https://github.com/ash-project/ash_admin
Getting the Ball Rolling • 5

really clear about keeping closely-related resources like Album and Artist away from
other closely-related resources such as User and Notification.
In some scenarios, we might even want to have resources with the same name, but
different meanings. A Member or a Group resource could represent very different things
in a music-related or a user-related context!
We’ve just thrown a lot of words and concepts at you — some may be familiar
to you from other frameworks, others may not. We’ll go over each of them as
they become relevant to the app, including lots of other resources that can
help you out, as well.

Generating the Artist resource

The first resource we’ll create is for an Artist. It’s the most important resource
for anything music-related in Tunez, that other resources such as albums
will link back to. The resource will store information about an artist’s name
and biography — important so users can know who they’re looking at!

To create our Artist resource, we’ll use generators to get basic domain and
resource modules. We’ll generate the database migration to add a database
table for storage for our resource, and then we can start fleshing out actions
to be taken on our resource.

We’ll start off with generating our modules. Ash comes with Igniter generators
to create domains and resources for you. We’ll use them to save some time,
but you could just as well create the necessary files yourself. First we’ll gen-
erate the Music domain:

$ mix ash.gen.domainTunez.Music

This will create a domain module in lib/tunez/music.ex, as well as adding config-
uration to load the domain in config/config.exs. The domain module is pretty
empty right now:

01/lib/tunez/music.ex
defmodule Tunez.Music do
use Ash.Domain, otp_app::tunez
resources do
end
end

We don’t need to add anything to this domain yet — for now it’s only a
bucket to put resources in. As we create more resources relating to music,

Chapter 1. Building Our First Resource • 6

we’ll be adding them to the resources block here. (If you use the resource gen-
erator, this will be done for you.)

Now that we have a domain, we can create the resource. The basic resource
generator will create a nearly-empty Ash resource, so we can step through it
and look through the parts. Run the following in your terminal:

$ mix ash.gen.resourceTunez.Music.Artist--extendpostgres

This will generate a new resource module named Tunez.Music.Artist that extends
PostgreSQL, and automatically add it as a resource in the Tunez.Music domain.

The code for the generated resource is in lib/tunez/music/artist.ex:

01/lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
use Ash.Resource, otp_app::tunez , domain: Tunez.Music,
data_layer: AshPostgres.DataLayer
postgres do
table "artists"
repoTunez.Repo
end
end

Let’s break down this generated code piece by piece, because this is our first
introduction to Ash’s domain-specific language (DSL).

Because we specified --extend postgres when calling the generator, the resource
will be configured with PostgreSQL as its data store for reading from and
writing to via AshPostgres.DataLayer. Each Artist struct will be persisted as a row
in an artist-related database table.

This specific data layer is configured using the postgres code block. The mini-
mum information we need is the repo and table name, but there is a lot of
other behaviour that can be configured^7 as well.

Ash has several different data layers built in using storage such
as Mnesia^8 and ETS.^9 More can be added via external packages
like we added for PostgreSQL, such as SQLite^10 or CubDB.^11 Some
of these external packages aren’t as fully-featured as the Post-
greSQL package, but they’re pretty usable!
https://hexdocs.pm/ash_postgres/dsl-ashpostgres-datalayer.html
https://hexdocs.pm/ash/dsl-ash-datalayer-mnesia.html
https://hexdocs.pm/ash/dsl-ash-datalayer-ets.html
10.https://hexdocs.pm/ash_sqlite/
11.https://hexdocs.pm/ash_cubdb/
Getting the Ball Rolling • 7

To add attributes to our resource, add another block in the resource named
attributes. Because we’re using PostgreSQL, each attribute we define will be a
column in the underlying database table. Ash provides macros we can call
to define different types of attributes,^12 so let’s add some attributes to our
resource.

A primary key will be critical to identify our artists, so we can call uuid_prima-
ry_key to create a autogenerated UUID primary key. Some timestamp fields
would be useful, so we know when records are inserted and updated, and we
can use create_timestamp and update_timestamp for those. Specifically for artists,
we also know we want to store their name and a short biography , and they’ll
both be string values. They can be added to the attributes block using the attribute
macro.

01/lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
# ...
attributes do
uuid_primary_key :id
attribute :name , :string do
allow_nil?false
end
attribute :biography , :string
create_timestamp :inserted_at
update_timestamp :updated_at
end
end

And that’s all the code we need to write to add attributes to our resource!

There’s a rich set of configuration options for attributes. You can
read more about them in the attribute DSL documentation.^13 We’ve
used one here, allow_nil?, but there are many more available.
You can also pass extra options like --uuid-primary-key id to the
ash.gen.resource generator^14 to generate attribute-related code (and
more!) if you prefer.
Right now our resource is only a module. We’ve configured a database table
for it, but that database table doesn’t yet exist. To change that, we can use

12.https://hexdocs.pm/ash/dsl-ash-resource.html#attributes
13.https://hexdocs.pm/ash/dsl-ash-resource.html#attributes-attribute
14.https://hexdocs.pm/ash/Mix.Tasks.Ash.Gen.Resource.html

Chapter 1. Building Our First Resource • 8

another generator. This one we’ll get pretty familiar with over the course of
the book.

Auto-generating database migrations

If you’ve used Ecto for working with databases before, you’ll be familiar with
the pattern of creating or updating a schema module, then generating a blank
migration and populating it with commands to mirror that schema. It can be
a little bit repetitive, and has the possibility of your schema and your database
getting out of sync. If someone updates the database structure but doesn’t
update the schema module, or vice versa, you can get some tricky and hard-
to-debug issues.

Ash side-steps these kinds of issues by generating complete migrations for
you based on your resource definitions. This is our first example of Ash’s
philosophy of “model your domain, derive the rest”. Your resources are the
source of truth for what your app should be and how it should behave, and
everything else is derived from that.

What does this mean in practice? Every time you run the ash.codegen mix task,
Ash (via AshPostgres) will:

Create snapshots of your current resources
Compare them with the previous snapshots (if they exist)
And finally, generate deltas of the changes to go into the new migration.
This is data-layer agnostic: any data layer can provide its own implementation
for what to do when ash.codegen is run. Because we’re using AshPostgres, which
is backed by Ecto, we get Ecto migrations.

Now we have an Artist resource with some attributes, so we can generate a
migration for it using the mix task:

$ mix ash.codegencreate_artists

The create_artists argument given here will become the name of the
generated migration module, eg. Tunez.Repo.Migrations.CreateArtists. This
can be anything, but it’s a good idea to describe what the migration
will actually do.
Running the ash.codegen task will create a few files:

A snapshot file for our Artist resource, in priv/resource_snapshots/repo/artists/[times-
tamp].json. This is a JSON representation of our resource as it exists right
now.
Getting the Ball Rolling • 9

A migration for our Artist resource, in priv/repo/migrations/[timestamp]_cre-
ate_artists.ex. This contains the schema differences that Ash has detected
between our current snapshot which was just created, and the previous
snapshot (which in this case, is empty).
This migration contains the Ecto commands to set up the database table for
our Artist resource, with the fields we added for a primary key, timestamps,
name and biography:

01/priv/repo/migrations/[timestamp]_create_artists.exs
def up do
createtable( :artists , primary_key: false) do
add :id , :uuid , null: false, default: fragment( "gen_random_uuid()" ),
primary_key: true
add :name , :text , null: false
add :biography , :text
add :inserted_at , :utc_datetime_usec ,
null: false,
default: fragment( "(now()AT TIMEZONE'utc')" )
add :updated_at , :utc_datetime_usec ,
null: false,
default: fragment( "(now()AT TIMEZONE'utc')" )
end
end

This looks a lot like what you would write if you were setting up a database
table for a pure Ecto schema — but we didn’t have to write it. We don’t have
to worry about keeping the database structure in sync manually. We can run
mix ash.codegen every time we change anything database-related, and Ash will
figure out what needs to be changed and create the migration for us.

This is the first time we’ve touched the database, but the database will already
have been created when running mix setup earlier. To run the migration we
generated, you can use Ash’s ash.migrate Mix task:

$ mix ash.migrate
Gettingextensionsin currentproject...
Runningmigrationfor AshPostgres.DataLayer...

[timestamp][info]== Running[timestamp]Tunez.Repo.Migrations
.InstallAshFunctionsExtension[version][timestamp].up/0forward
«truncatedSQL output»
[info]== Migrated[timestamp]in 0.0s

[timestamp][info]== Running[timestamp]Tunez.Repo.Migrations
.CreateArtists.up/0forward
[timestamp][info]createtableartists
[timestamp][info]== Migrated[timestamp]in 0.0s

Chapter 1. Building Our First Resource • 10

Now we have a database table, ready to store Artist data!

To roll back a migration, Ash also provides an ash.rollback Mix task,
as well as ash.setup, ash.reset, and so on. These are more powerful
than their Ecto equivalents — any Ash extension can set up their
own functionality for each task. For example, AshPostgres provides
an interactive UI to select how many migrations to roll back when
running ash.rollback.
Note that if you roll back and then delete a migration to re-generate
it, you’ll also need to delete the snapshots that were created with
the migration.
How do we actually use the resource to read or write data into our database,
though? We’ll need to define some actions on our resource.

Oh, CRUD! — Defining Basic Actions
An action describes an operation that can be performed for a given resource;
it is the verb to a resource’s noun. Actions can be loosely broken down into
four types:

Creating new persisted records (rows in the database table);
Reading one or more existing records;
Updating an existing record; and
Destroying (deleting) an existing record.
These four types of actions are very common in web applications, and are
often shortened to the acronym CRUD.

Ash also supports generic actions for any action that doesn’t fit
into any of those four categories. We won’t be covering those in
this book, but you can read the online documentation^15 about
them.
With a bit of creativity, we can use these four basic action types to describe
almost any kind of action we might want to perform in an app.

Registering for an account? That’s a type of create action on a User resource.

Searching for products to purchase? That sounds like a read action on a Product
resource.

15.https://hexdocs.pm/ash/generic-actions.html

Oh, CRUD! — Defining Basic Actions • 11

Publishing a blog post? It could be a create action if the user is writing the
post from scratch, or an update action if they’re publishing an existing saved
draft.

In Tunez, we’ll have functionality for users to list artists and view details of
a specific artist (both read actions), create and update artist records (via forms),
and also destroy artist records; so we’ll want to use all four types of actions.
This is a great time to learn how to define and run actions using Ash, with
some practical examples.

In our Artist resource, we can add an empty block for actions, and then start
filling it out with what we want to be able to do:

01/lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
# ...
actions do
end
end

Let’s start with creating records with a create action, so we have some data to
use when testing out other types of actions.

Defining a create action

Actions are defined by adding them to the actions block in a resource. At their
most basic, they require a type (one of the four mentioned earlier — create,
read, update and destroy), and a name. The name can be any atom you like, but
should describe what the action is actually supposed to do. It’s common to
give the action the same name as the action type, until you know you need
something different.

01/lib/tunez/music/artist.ex
actions do
create :create do
end
end

To create an Artist record, we need to provide the data to be stored — in this
case, the name and biography attributes, in a map. (The other attributes, such
as timestamps, will be automatically managed by Ash.) We call these the
attributes that the action accepts , and can list them in the action with the
accept macro.

01/lib/tunez/music/artist.ex
actions do
create :create do

Chapter 1. Building Our First Resource • 12

accept[ :name , :biography ]
end
end

And that’s actually all we need to do to create the most basic create action.
Ash knows that the core of what a create action should do is create a data
layer record from provided data, so that’s exactly what it will do when we run
it.

Running actions

There are two basic ways we can run actions: the generic query/changeset
method, and the more direct code interface method. We can test them both
out in an iex session:

$ iex -S mix

Creating records via a changeset

If you’ve used Ecto before, this pattern may be familiar to you:

Create a changeset (a set of data changes to apply to the resource)
Pass that changeset to Ash for processing
In code, this might look like the following:

Tunez.Music.Artist
|> Ash.Changeset.for_create( :create , %{
name:"Valkyrie'sFury" ,
biography:"A powermetalbandhailingfromTallinn,Estonia"
})
|> Ash.create()

We specify the action that the changeset should be created for, with the data
that we want to save. When we pipe that changeset into Ash, it will handle
running all of the validations and creating the record in the database.

iex(1)> Tunez.Music.Artist
|> Ash.Changeset.for_create(:create,%{
name:"Valkyrie'sFury",
biography:"A powermetalbandhailingfromTallinn,Estonia"
})
|> Ash.create()
{:ok,
#Tunez.Music.Artist<
meta:#Ecto.Schema.Metadata<:loaded,"artists">,
id: [uuid],
name:"Valkyrie'sFury",
biography:"A powermetalbandhailingfromTallinn,Estonia",
...

}

Oh, CRUD! — Defining Basic Actions • 13

The record is inserted into the database, and then returned as part of an :ok
tuple. You can verify this in your database client of choice, for example, using
psqltunez_dev in your terminal to connect using the inbuilt command-line client:

tunez_dev=#select* fromartists;
-[ RECORD1 ]----------------------------------------------
id | [uuid]
name | Valkyrie'sFury
biography | A powermetalbandhailingfromTallinn,Estonia
inserted_at| [now]
updated_at | [now]

What happens if we submit invalid data, such as an Artist without a name?

iex(2)> Tunez.Music.Artist
|> Ash.Changeset.for_create(:create,%{name:""})
|> Ash.create()
{:error,
%Ash.Error.Invalid{
bread_crumbs:["Errorreturnedfrom:Tunez.Music.Artist.create"],
changeset:#Ash.Changeset< ...> ,
errors:[
%Ash.Error.Changes.Required{
field::name,
type::attribute,
resource:Tunez.Music.Artist,
...

The record isn’t inserted into the database, and we get an error record back
telling us what the issue is: the name is required. Later on in this chapter,
we’ll see how these returned errors are used when we integrate the actions
into our web interface.

Like a lot of other Elixir libraries, most Ash functions return data in :ok and
:error tuples. This is handy because it lets you easily pattern match on the
result, to handle the different scenarios. To raise an error instead of returning
an error tuple, you can use the bang version of a function ending in an
exclamation mark, ie. Ash.create! instead of Ash.create.

Creating records via a code interface

If you’re familiar with Ruby on Rails or ActiveRecord, this pattern may be
more familiar to you. It allows us to skip the step of manually creating a
changeset, and lets us call the action directly as a function.

Code interfaces can be defined on either a domain module or on a resource
directly. We’d generally recommend defining them on domains, similar to
Phoenix contexts, because it lets the domain act as a solid boundary with the

Chapter 1. Building Our First Resource • 14

rest of your application. With all your resources listed in your domain, it also
gives a great overview of all your functionality in one place.

To enable this, we can use Ash’s define macro when including the Artist
resource in our Tunez.Music domain:

01/lib/tunez/music.ex
resources do
resourceTunez.Music.Artist do
define :create_artist , action::create
end
end

This will connect our domain function create_artist, to the create action of the
resource. Once you’ve done this, if you recompile within iex the new function
will now be available, complete with auto-generated documentation:

iex(2)> h Tunez.Music.create_artist

def create_artist(params_or_opts\\ %{},opts\\ [])
Callsthe createactionon Tunez.Music.Artist.

Inputs
name
biography
You can call it like any other function, with the data to be inserted into the
database:

iex(7)> Tunez.Music.create_artist(%{
name:"Valkyrie'sFury",
biography:"A powermetalbandhailingfromTallinn,Estonia"
})
{:ok,#Tunez.Music.Artist< ...> }

When would I use changesets instead of code interfaces, or vice versa?
Under the hood, the code interface is creating a changeset and passing it to the
domain, but that repetitive logic is hidden away. So there’s no real functional benefit,
but the code interface is easier to use and more readable.
Where the changeset method shines is around forms on the page — we’ll see shortly
how AshPhoenix provides a thin layer over the top of changesets to allow all of
Phoenix’s existing form helpers to work seamlessly with Ash changesets instead of
Ecto changesets.
We’ve provided some sample content for you to play around with — there’s a
mix seed alias defined in the aliases/0 function in the Tunez app’s mix.exs file. It

Oh, CRUD! — Defining Basic Actions • 15

has three lines for three different seed files, all commented out. You can
uncomment the first line:
01/mix.exs
defp aliases do
[
setup: [ "deps.get" , "ash.setup" , "assets.setup" , "assets.build" , ...],
"ecto.setup" : [ "ecto.create" , "ecto.migrate" ],
➤ seed: [
➤ "run priv/repo/seeds/01-artists.exs" ,
➤ # "runpriv/repo/seeds/02-albums.exs",
➤ # "runpriv/repo/seeds/08-tracks.exs"
➤ ],
# ...
You can now run mix seed, and it will import a list of sample (fake) artist data
into your database. There are other seed files listed in the function as well
but we’ll mention those when we get to them! (The chapter numbers in the
filenames are a bit of a giveaway...)
$ mix seed
Now that we have some data in our database, we can look at other types of
actions.

Defining a read action
In the same way we defined the create action on the Artist resource, we can
define a read action by adding it to the actions block. We’ll add just one extra
option: we’ll define it as a primary action.
01/lib/tunez/music/artist.ex
actions do
# ...
read :read do
primary?true
end
end
A resource can have one of each of the four action types (create, read, update
and destroy) marked as the primary action of that type. These are used by Ash
behind the scenes when actions aren’t or can’t be specified. We’ll cover these
in a little bit more detail later.
To be able to call the read action as a function, add it as a code interface in
the domain just like we did with create.
01/lib/tunez/music.ex
resourceTunez.Music.Artist do
# ...
Chapter 1. Building Our First Resource • 16

define :read_artists , action::read
end

What does a read action do? As the name suggests, it will read data from our
data layer based on any parameters we provide. We haven’t defined any
parameters in our action, so when we call the action, we should expect it to
return all the records in the database.

iex(1)> Tunez.Music.read_artists()
{:ok,
[
#Tunez.Music.Artist< ...> ,
#Tunez.Music.Artist< ...> ,
...

While actions that modify data use changesets under the hood, read actions
use queries. If we do want to provide some parameters to the action, such as
filtering or sorting, we need to modify the query when we run the action. This
can be done either as part of the action definition (we’ll learn about that in
Designing a search action, on page 61!), or inline when we call the action.

Manually reading records via a query

While this isn’t something you’ll do a lot of when building applications, it’s
still a good way of seeing how Ash builds up queries piece by piece.

There are a few steps to the process:

Creating a basic query from the action we want to run
Piping the query through other functions to add any extra parameters we
want, and then
Passing the final query to Ash for processing.
In iex you can test this out step by step, starting from the basic resource, and
creating the query:

iex(2)> Tunez.Music.Artist
Tunez.Music.Artist
iex(3)> |> Ash.Query.for_read( :read )
#Ash.Queryresource:Tunez.Music.Artist

Then you can pipe that query into Ash’s query functions like sort and limit. The
query keeps getting the extra conditions added to it, but it isn’t yet being run
in the database.

iex(4)> |> Ash.Query.sort( name::asc )
#Ash.Queryresource:Tunez.Music.Artist,sort:[name::asc]
iex(5)> |> Ash.Query.limit(1)
#Ash.Queryresource:Tunez.Music.Artist,sort:[name::asc],limit:1

Oh, CRUD! — Defining Basic Actions • 17

Then when it’s time to go, Ash can call it and return you the data you
requested, with all conditions applied:

iex(6)> |> Ash.read()
[debug]QUERYOK source="artists"db=3.4msqueue=1.2msidle=1863.7ms
SELECTa0."id",a0."name",a0."biography",a0."inserted_at",a0."updated_at"
FROM"artists"AS a0 ORDERBY a0."name"LIMIT$1 [1]
{:ok,[#Tunez.Music.Artist< ...> ]}

For a full list of the query functions Ash provides, you can check out the
documentation.^16 Note that to use any of the functions that use special syntax
like filter, you’ll need to require Ash.Query in your iex session first.

Reading a single record by primary key

One very common requirement is to be able to read a single record by its
primary key. We’re building a music app, so we’ll be building a page where
we can view an artist’s profile, and we’ll want an easy way to fetch that single
Artist record for display.

We have a basic read action already, and we could write another read action
that applies a filter to only fetch the data by an ID we provide, but Ash provides
a simpler way.

A neat feature of code interfaces is that we can automatically apply a filter
for any attribute of a resource, that we expect to return at most one result.
Looking up records by primary key is a perfect use case for this, because
they’re guaranteed to be unique!

To use this feature, we can add another code interface for the same read action,
but adding the get_by option^17 for the primary key, an attribute named :id:

01/lib/tunez/music.ex
resourceTunez.Music.Artist do
# ...
define :get_artist_by_id , action::read , get_by::id
end

Adding this code interface defines a new function on our domain:

iex(4)> h Tunez.Music.get_artist_by_id

def get_artist_by_id(id,params_or_opts\\ %{},opts\\ [])
Callsthe readactionon Tunez.Music.Artist.

16.https://hexdocs.pm/ash/Ash.Query.html
17.https://hexdocs.pm/ash/dsl-ash-domain.html#resources-resource-define-get_by

Chapter 1. Building Our First Resource • 18

Copy the ID from any of the records you loaded when testing the read action,
and you’ll see that this new function does exactly what we hoped — return
the single record that has that ID.

iex(3)> Tunez.Music.get_artist_by_id( "an-artist-id" )
[debug]QUERYOK source="artists"db=0.3msqueue=0.4msidle=331.4ms
SELECTa0."id",a0."name",a0."biography",a0."inserted_at",a0."updated_at"
FROM"artists"AS a0 WHERE(a0."id"::uuid= $1::uuid)
["an-artist-id"]
{:ok,#Tunez.Music.Artist<id:"an-artist-id", ...> }

Perfect! We’ll be using that very soon.

Defining an update action

A basic update action is conceptually very similar to a create action. The main
difference is that instead of building a new record with some provided data
and saving it into the database, we provide an existing record to be updated
with the data and saved.

Let’s add the basic action and code interface definition:

01/lib/tunez/music/artist.ex
actions do
# ...
update :update do
accept[ :name , :biography ]
end
end

01/lib/tunez/music.ex
resourceTunez.Music.Artist do
# ...
define :update_artist , action::update
end

How would we call this new action? First we need a record to be updated.
You can use the read action you defined earlier to find one, or if you’ve been
testing the get_artist_by_id function we just wrote, you might have one right
there.

iex(3)> artist= Tunez.Music.get_artist_by_id!( "an-artist-id" )
#Tunez.Music.Artist<id:"an-artist-id", ...>

Now we can either use the code interface we added or create a changeset and
apply it, like we did for create.

iex(4)> # Via the codeinterface
iex(5)> Tunez.Music.update_artist(artist,%{ name:"Hello" })
[debug]QUERYOK source="artists"db=1.4ms

Oh, CRUD! — Defining Basic Actions • 19

UPDATE"artists"AS a0 SET "name"= $1, "updated_at"= $2 WHERE
(a0."id"= $3) RETURNINGa0."name",a0."updated_at",a0."id"["Hello",
[now],"an-artist-id"]
{:ok,#Tunez.Music.Artist<id:"an-artist-id",name:"Hello", ...> }

iex(6)> # Or via a changeset
iex(7)> artist
|> Ash.Changeset.for_update(:update,%{name:"World"})
|> Ash.update()
«an almost-identicalSQL statement»
{:ok,#Tunez.Music.Artist<id:"an-artist-id",name:"World", ...> }

Like create actions, we get either an :ok tuple with the updated record, or an
:error tuple with an error record back.

Defining a destroy action

The last type of core action that Ash provides are destroy actions — when we
want to get rid of data, delete it from our database and memories. Like update
actions, they work on existing data records, so we need to provide a record
when we call a destroy action... but that’s the only thing we need to provide.
Ash can do the rest!

You might be able to guess by now, how to implement a destroy action in our
resource:

01/lib/tunez/music/artist.ex
actions do
# ...
destroy :destroy do
end
end

01/lib/tunez/music.ex
resourceTunez.Music.Artist do
# ...
define :destroy_artist , action::destroy
end

This will allow us to call the action, either by creating a changeset and sub-
mitting it or calling the action directly.

iex(3)> artist= Tunez.Music.get_artist_by_id!( "the-artist-id" )
{:ok,#Tunez.Music.Artist<id:"an-artist-id", ...> }

iex(4)> # Via the codeinterface
iex(5)> Tunez.Music.destroy_artist(artist)
[debug]QUERYOK source="artists"db=0.3ms
DELETEFROM"artists"AS a0 WHERE(a0."id"= $1) ["the-artist-id"]
:ok

iex(6)> # Or via a changeset

Chapter 1. Building Our First Resource • 20

iex(7)> artist
|> Ash.Changeset.for_destroy(:destroy)
|> Ash.destroy()
[debug]QUERYOK source="artists"db=1.1ms
DELETEFROM"artists"AS a0 WHERE(a0."id"= $1) ["the-artist-id"]
:ok

And with that, we have a solid explanation of the four main types of actions
we can define in our resources.

Let’s take a bit to let this really sink in. By creating a resource and adding a
few lines of code to describe its attributes and what actions we can take on
it, we now have:

A database table to store records in
Secure functions we can call to read and write data to the database (no
storing any attributes that aren’t explicitly allowed!)
Database-level validations to ensure that data is present
Automatic type-casting of attributes before they get stored
We didn’t have to write any functions that query the database, or update our
database schema when we added new attributes to the resource, or manually
cast attributes. A lot of the boilerplate we would typically need to write has
been taken care of for us because Ash handles translating what our resource
should do into how it should be done. This is a pattern we’ll see a lot!

Default actions

Now that you’ve learned about the different types of actions and how to define
them in your resources, we can let you in on a little secret...

You don’t actually have to define empty actions like this for CRUD actions.

You know how we said that Ash knows that the main purpose of a create action
is to take the data and save it to the data layer? This is what we call the
default implementation for a create action. Ash provides default implementa-
tions for all four action types, and if you want to use these implementations
without any customization, you can use the defaults macro in your actions block:

01/lib/tunez/music/artist.ex
actions do
defaults[ :create , :read , :update , :destroy ]
end

We still need the code interface definitions if we want to be able to call the
actions as functions, but we can cut out the empty actions to save time and
space. This also marks all four actions as primary?true, as a handy side-effect.

Oh, CRUD! — Defining Basic Actions • 21

But what about the accept definitions that we added to the create and update
actions, the list of attributes to save? We can define default values for that
list, with the default_accept^18 macro. This default list will then apply to all create
and update actions unless specified otherwise (as part of the action definition).

So the actions for our whole resource as it stands right now could be written
in a few short lines of code:

01/lib/tunez/music/artist.ex
actions do
defaults[ :create , :read , :update , :destroy ]
default_accept[ :name , :biography ]
end

That is a lot of functionality packed into those four lines!

Which version of the code you write is up to you — we would generally err on
the side of explicitly defining actions with the attributes they accept, as you’ll
need to convert them whenever you need to add business logic to your actions
anyway. For quick prototyping though, the shorthand can’t be beat.
Whichever way you go, it’s critical to know what your code is doing for you,
under the hood — generating a full CRUD interface to your resource, allowing
you to manage your data.

Integrating Actions into LiveViews
We’ve talked a lot about Tunez the web app, but we haven’t even looked at
the app in an actual browser yet. Now that we have a fully-functioning
resource, let’s integrate it into the web interface so we can see the actions in,
well, action!

Listing artists

In the app folder, you can start the Phoenix webserver with the following
command in your terminal:

$ mix phx.server
[info]RunningTunezWeb.EndpointwithBandit1.6.7at 127.0.0.1:4000(http)
[info]AccessTunezWeb.Endpointat http://localhost:4000
[watch]buildfinished,watchingfor changes...

Rebuilding...

Donein [time]ms.

18.https://hexdocs.pm/ash/dsl-ash-resource.html#actions-default_accept

Chapter 1. Building Our First Resource • 22

Once you see that the build is ready to go, you can open a web browser at
http://localhost:4000 and see what we’ve got to work with.

The app homepage is the artist catalog, listing all of the Artists in the app.
In the code, this catalog is rendered by the TunezWeb.Artists.IndexLive module, in
lib/tunez_web/live/artists/index_live.ex.

We’re not going to go into a lot of detail about Phoenix and Phoenix
LiveView, apart from where we need to to ensure that our app is
secure. If you need a refresher course (or want to learn them for
the first time!), we can recommend reading through Programming
Phoenix 1.4 [TV19] and Programming Phoenix LiveView [TD24].
If you’re more of a video person, you can’t go past Pragmatic Stu-
dio’s Phoenix LiveView course.^19
In the IndexLive module, we have some hardcoded maps of artist data defined
in the handle_params/3 function:

01/lib/tunez_web/live/artists/index_live.ex
def handle_params(_params,_url,socket) do
artists= [
%{ id: "test-artist-1" , name:"TestArtist1" },
%{ id: "test-artist-2" , name:"TestArtist2" },
%{ id: "test-artist-3" , name:"TestArtist3" },
]
socket=
socket

19.https://pragmaticstudio.com/courses/phoenix-liveview

Integrating Actions into LiveViews • 23

|> assign( :artists , artists)
{ :noreply , socket}
end

These are what are iterated over in the render/1 function, using a function
component to render an artist “card” for each artist — the image placeholders
and names we can see in the browser.

01/lib/tunez_web/live/artists/index_live.ex

<**.** artist_cardartist= _{artist}_ />
Earlier in Defining a read action, on page 16, we defined a code interface
function on the Tunez.Music domain for reading records from the database. It
returns Artist structs that have a name key, just like the hardcoded data does.
So to load real data from the database, we can replace the hardcoded data
with a call to the read action.

01/lib/tunez_web/live/artists/index_live.ex
def handle_params(_params,_url,socket) do
artists= Tunez.Music.read_artists!()
# ...

And that’s it! The page should reload in your browser when you save the
changes to the liveview, and you should be seeing the names of the seed
artists and the test artists you created, rendered on the page.

Each of the placeholder images and names links to a separate profile page,
where you can view details of a specific artist, and we’ll connect that up next.

Viewing an artist profile

Clicking on the name of one of the artists will bring you to their profile page.
This liveview is defined in TunezWeb.Artists.ShowLive, which you can verify by
checking the logs of the web server in your terminal:

[debug]MOUNTTunezWeb.Artists.ShowLive
Parameters:%{"id"=> "[theartistUUID]"}

Inside that module, in lib/tunez_web/live/artists/show_live.ex, you’ll again see some
hardcoded artist data defined in the handle_params/3 function and added to the
socket.

01/lib/tunez_web/live/artists/show_live.ex
def handle_params(_params,_url,socket) do
artist= %{
id: "test-artist-1" ,
name:"ArtistName" ,

Chapter 1. Building Our First Resource • 24

biography:«somesamplebiographycontent»
}
# ...
Earlier in Reading a single record by primary key, on page 18, we defined a
get_artist_by_id code interface function on the Tunez.Music domain, that reads a
single Artist record from the database by its id attribute. The URL for the
profile page contains the ID of the Artist to show on the page, and the terminal
logs showed that the ID is available as part of the params. So we can replace
the hardcoded data with a call to get_artist_by_id, after first using pattern
matching to get the ID from the params.

01/lib/tunez_web/live/artists/show_live.ex
def handle_params(%{ "id" => artist_id},_url,socket) do
artist= Tunez.Music.get_artist_by_id!(artist_id)
# ...

After saving the changes to the liveview, the page should refresh and you
should see the correct data for the artist you’re viewing the profile of.

Creating artists with AshPhoenix.Form

To create and edit Artist data, we’ll have to learn how to handle forms and
form data with Ash.

If we were building our app directly on Phoenix contexts using Ecto, we would
have a schema module that would define the attributes for an Artist. The
schema module would also define a changeset function to parse and validate
data from forms before the context module would attempt to insert or update
it in the database. If the data validation fails, the liveview (or a template) can
take the resulting changeset with errors on it and use it to show the user
what they need to fix.

In code, the changeset function might look something like this:

defmodule Tunez.Music.Artist do
def changeset(artist,attrs) do
artist
|> cast(attrs,[ :name , :biography ])
|> validate_required([ :name ])
end

And the context module that uses it might look like this:

defmodule Tunez.Music do
def create_artist(attrs\ %{}) do
%Artist{}
|> Artist.changeset(attrs)
|> Repo.insert()

Integrating Actions into LiveViews • 25

end
We can use a similar pattern with Ash, but we need a slightly different
abstraction.

We have our Artist resource defined with attributes, similar to an Ecto schema.
It has actions to create and update data, replacing the context part as well. What
we’re missing is the integration with our UI, a way to take the errors returned
if the create action fails and show them to the user — and this is where Ash-
Phoenix comes in.

Hello, AshPhoenix

As the name suggests, AshPhoenix is a core Ash library to make it much nicer
to work with Ash in the context of a Phoenix application. We’ll use it a few
times over the course of building Tunez, but its main purpose is form integra-
tion.

Like AshPostgres and Ash itself, we can use mixigniter.install to install AshPhoenix
in a terminal:

$ mix igniter.installash_phoenix

Confirm the addition of AshPhoenix to your mix.exs file, and the package will
be installed and we can start using it straight away.

A form for an action

Our Artist resource has a create action that accepts data for name and biography
attributes. Our web interface will reflect this exactly — we’ll have a form with
a text field to enter a name, and a textarea to enter a biography.

We can tell AshPhoenix that what we want is a form to match the inputs for
our create action, or more simply, a form for our create action. AshPhoenix will
return an AshPhoenix.Form struct, and provides a set of intuitively-named func-
tions for interacting with it. We can validate our form, we can submit our
form, we can add and remove forms (for nested form data!) and more.

In an iex session, we can get familiar with using AshPhoenix.Form:

iex(1)> form= AshPhoenix.Form.for_create(Tunez.Music.Artist, :create )
#AshPhoenix.Form<
resource:Tunez.Music.Artist,
action::create,
type::create,
params:%{},
source:#Ash.Changeset<
domain:Tunez.Music,
action_type::create,

Chapter 1. Building Our First Resource • 26

action::create,
attributes:%{},
...
An AshPhoenix.Form wraps an Ash.Changeset, which behaves similarly to an
Ecto.Changeset. This allows the AshPhoenix form to be a drop-in replacement
for an Ecto.Changeset, when calling the function components that Phoenix gen-
erates for dealing with forms. Let’s keep testing.
iex(2)> AshPhoenix.Form.validate(form,%{ name:"BestBandEver" })
#AshPhoenix.Form<
resource:Tunez.Music.Artist,
action::create,
type::create,
params:%{name:"BestBandEver"},
source:#Ash.Changeset<
domain:Tunez.Music,
action_type::create,
action::create,
attributes:%{name:"BestBandEver"},
relationships:%{},
errors:[],
data:#Tunez.Music.Artist< ...>
➤ valid?:true

,
...
If we call AshPhoenix.Form.validate with valid data for an Artist, the changeset in
the form is now valid. In a liveview, this is what we would call in a phx-change
event handler, to make sure our form in-memory stays up-to-date with the
latest data. Similarly, we can call AshPhoenix.Form.submit on the form in a phx-
submit event handler.
iex(5)> AshPhoenix.Form.submit(form, params: %{ name:"BestBandEver" })
[debug]QUERYOK source="artists"db=6.3ms
INSERTINTO"artists"("id","name","inserted_at","updated_at")VALUES
($1,$2,$3,$4)RETURNING"updated_at","inserted_at","biography","name","id"
[[uuid],"BestBandEver",[timestamp],[timestamp]]
↳AshPostgres.DataLayer.bulk_create/3,at: lib/data_layer.ex:1900
{:ok,
#Tunez.Music.Artist<
meta:#Ecto.Schema.Metadata<:loaded,"artists">,
id: [uuid],
name:"BestBandEver",
...
And it works! We get back a form-ready version of the return value of the
action. If we had called submit with invalid data, we would get back an {:error,
%AshPhoenix.Form{}} tuple back instead.

Integrating Actions into LiveViews • 27

Using the AshPhoenix domain extension
We’ve defined code interface functions like Tunez.Music.read_artists for all of the
actions in the Artist resource and used those code interfaces in our liveviews.
It might feel a bit odd to now revert back to using action names directly when
generating forms. And if the names of the code interface function and the
action are really different, it could get a bit confusing!
AshPhoenix provides a solution for this, with a domain extension. If we add
the AshPhoenix extension to the Tunez.Music domain module, it will define some
new functions on the domain around form generation.
In the Tunez.Music module in lib/tunez/music.ex, add a new extensions option to the
use Ash.Domain line:
01/lib/tunez/music.ex
defmodule Tunez.Music do
➤ use Ash.Domain, otp_app::tunez , extensions: [AshPhoenix]

# ...
Now, instead of calling AshPhoenix.Form.for_create(Tunez.Music.Artist,:create), we can
use a new function Tunez.Music.form_to_create_artist. This works for any code
interface function, even for read actions, by prefixing form_to_ to the function
name.
iex(5)> AshPhoenix.Form.for_create(Tunez.Music.Artist, :create )
#AshPhoenix.Form<resource:Tunez.Music.Artist,action::create, ...>
iex(6)> Tunez.Music.form_to_create_artist()
#AshPhoenix.Form<resource:Tunez.Music.Artist,action::create, ...>
The result is the same — you get an AshPhoenix.Form struct to validate and
submit, as before — but the way you get it is a lot more consistent with other
function calls.
Integrating a form into a liveview
The liveview for creating an Artist is the TunezWeb.Artists.FormLive module, located
in lib/tunez_web/live/artists/form_live.ex. In the browser, you can view it by clicking
the New Artist button on the artist catalog, or visiting /artists/new.
Chapter 1. Building Our First Resource • 28

It looks good, but it’s totally non-functional right now. We can use what we’ve
learned so far about AshPhoenix.Form to make it work as we would expect.
It starts from the top — we want to build our initial form in the mount/3 func-
tion. Currently form is defined as an empty map, just to get the form to render.
We can replace it with a function call to create the form, like we did in iex:
01/lib/tunez_web/live/artists/form_live.ex
def mount(_params,_session,socket) do
➤ form= Tunez.Music.form_to_create_artist()

socket=
socket
|> assign( :form , to_form(form))
# ...
The form has a phx-change event handler attached that will fire after every pause
in typing on the form. This will send the “validate” event to the liveview,
handled by the handle_event/3 function head with the first argument “validate”.
01/lib/tunez_web/live/artists/form_live.ex
def handle_event( "validate" , %{ "form" => _form_data},socket) do
{ :noreply , socket}
end
It doesn’t currently do anything, but we know we need to update the form in
the socket with the data from the form.
01/lib/tunez_web/live/artists/form_live.ex
def handle_event( "validate" , %{ "form" => form_data},socket) do
socket=
Integrating Actions into LiveViews • 29

update(socket, :form , fn form->
AshPhoenix.Form.validate(form,form_data)
end )
{ :noreply , socket}
end

Lastly, we need to deal with form submission. The form has a phx-submit event
handler attached that will fire when the user presses the Save button (or
presses Enter). This will send the “save” event to the liveview. The event
handler currently doesn’t do anything either (we told you the form was non-
functional!) but we can add code to submit the form with the form data.

We also need to handle the response after submission, handling both the
success and failure cases. If the user submits invalid data then we want to
show errors, otherwise we can go to the newly-added artist’s profile page and
display a success message.

01/lib/tunez_web/live/artists/form_live.ex
def handle_event( "save" , %{ "form" => form_data},socket) do
case AshPhoenix.Form.submit(socket.assigns.form, params: form_data) do
{ :ok , artist}->
socket=
socket
|> put_flash( :info , "Artistsavedsuccessfully" )
|> push_navigate( to: ~ p "/artists/#{ artist }" )
{ :noreply , socket}
{ :error , form}->
socket=
socket
|> put_flash( :error , "Couldnot saveartistdata" )
|> assign( :form , form)
{ :noreply , socket}
end
end

Give it a try! Submit some invalid data, see the validation errors, correct the
data, and submit the form again. It works great!

But what happens if you make a typo when entering data? No-one wants to
read about Metlalica, do they? We need some way of editing artist records,
and updating any necessary information.

Updating artists with the same code

When we set up the update actions in our Artist resource in Defining an update
action, on page 19, we noted that it was pretty similar to the create action and

Chapter 1. Building Our First Resource • 30

that the only real difference for update is that we need to provide the record
being updated. The rest of the flow — providing data to be saved, saving it to
the database — is exactly the same.

In addition, the web interface for editing an artist should be exactly the same
as for creating an artist. The only difference will be that the form for editing
has the artist data pre-populated on it, so that it can be modified, and the
form for creating will be totally blank.

We can actually use the same TunezWeb.Artists.FormLive liveview module for both
creating and updating records. The routes are already set up for this: clicking
the Edit Artist button on the profile page will take you to that liveview.

[debug]MOUNTTunezWeb.Artists.FormLive
Parameters:%{"id"=> "[theartistUUID]"}

This won’t be the case for all resources, all the time. You may need
very different interfaces for creating and updating data. A lot of
the time, though, this can be a neat way of building out function-
ality very quickly, and it can be changed later if your needs change.
The FormLive liveview will need to have different forms, depending on if an artist
is being created or updated. Everything else can be the same because we still
want to validate the data on keystroke, submit the form on form submission,
and perform the same actions after submission.

As we build the form for create in the mount/3 function, we can add another
mount/3 function head specifically for update, which sets form in the socket to a
form built for a different action.

01/lib/tunez_web/live/artists/form_live.ex
def mount(%{ "id" => artist_id},_session,socket) do
artist= Tunez.Music.get_artist_by_id!(artist_id)
form= Tunez.Music.form_to_update_artist(artist)
socket=
socket
|> assign( :form , to_form(form))
|> assign( :page_title , "UpdateArtist" )
{ :ok , socket}
end

def mount(_params,_session,socket) do
form= Tunez.Music.form_to_create_artist()
# ...

This new function head (which has to come before the existing function head!)
is differentiated by having an artist id in the params, just like the ShowLive

Integrating Actions into LiveViews • 31

module did when we viewed the artist profile. It sets up the form specifically
for the update action of the resource, using the loaded Artist record as the first
argument. It also sets a different page title, and... that’s all that has to change!
Everything else should keep behaving exactly the same.

Save the liveview and test it out in your browser. You should now to be able
to click Edit Artist, update the artist’s details, save, and see the changes
reflected back in their profile.

Deleting artist data

The last action we need to integrate is the destroy_artist code interface function
for removing records from the database. In the UI, this is done from a button
at the top of the artist profile page, next to the edit button. The button,
located in the template for TunezWeb.Artists.ShowLive, will send the “destroy-artist”
event when pressed.

01/lib/tunez_web/live/artists/show_live.ex
<. button_linkkind= "error" inversephx-click= "destroy-artist"
data-confirm= {"Are you sureyou wantto delete #{@ artist. name }?"} >
DeleteArtist
</. button _link >

We’ve already loaded the artist record from the database when rendering the
page, and stored it in socket.assigns, so you can fetch it out again and attempt
to delete it with the Tunez.Music.destroy_artist function. The error return value
would probably never be seen in practice, but just in case, we’ll show the
user a nice message anyway.

01/lib/tunez_web/live/artists/show_live.ex
def handle_event( "destroy-artist" , _params,socket) do
case Tunez.Music.destroy_artist(socket.assigns.artist) do
:ok ->
socket=
socket
|> put_flash( :info , "Artistdeletedsuccessfully" )
|> push_navigate( to: ~ p "/" )
{ :noreply , socket}
{ :error , error}->
Logger.info( "Couldnot deleteartist'#{ socket.assigns.artist.id }':
#{ inspect(error) }" )
socket=
socket
|> put_flash( :error , "Couldnot deleteartist" )
{ :noreply , socket}
end

Chapter 1. Building Our First Resource • 32

end

There are lots of different stylistic ways that this type of code could be written,
but this is typically the way we would write it. If things go wrong, we want
errors logged as to what happened, and we always want users to get feedback
about what’s going on.

Looking to generate user interfaces in a new app quickly?
Phoenix LiveView provides a phx.gen.live Mix task for scaffolding
schema modules, contexts, and liveviews with a basic CRUD user
interface, in one command. We’ve already covered building
resources, but if you’d like an equivalent AshPhoenix helper for
creating liveviews, you can use the ash_phoenix.gen.live Mix task.
And that’s it! We’ve set up Ash in the Tunez app, and implemented a full
CRUD interface for our first resource — and we haven’t had to write very
much code to do it.

We’ve learned a bit about the declarative nature of Ash. We didn’t need to
write functions that accepted parameters, processed them, saved the records,
etc — we haven’t needed to write any functions at all. We declared what our
resource should look like, where data should be stored, and what our actions
should do. Ash has handled the actual implementations for us.

We’ve also seen how AshPhoenix provides a tidy Form pattern for integration
with web forms, allowing for a really streamlined integration with very little
code.

In the next chapter, we’ll look at building a second resource and how the two
can be integrated together!

Integrating Actions into LiveViews • 33

CHAPTER 2
