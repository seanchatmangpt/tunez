Extending Resources with Business Logic

In the first chapter, we learned how to set up Ash within our Phoenix app,
created our first resource for Artists within a domain, and built out a full web
interface so that we could create, read, update and delete Artist records. This
would be a great starting point for any application, to pick your most core
domain model concept and build it out.

Now we can start fleshing out the domain model for Tunez a little bit more,
because one resource does not a full application make. Having multiple
resources, and connecting them together, will allow us to do things like
querying and filtering based on related data. So, in the real world, artists
release albums, right? Let’s build a second resource representing an Album
with a more complex structure, link them together, and learn some other
handy features of working with declarative resources.

Resources and Relationships
Like we generated our Artist resource, we can start by using Ash’s generators
to create our basic Album resource. It’s music-related, so it should also be
part of the Tunez.Music domain:

$ mix ash.gen.resourceTunez.Music.Album --extendpostgres

This will generate the resource file in lib/tunez/music/album.ex, as well as adding
the new resource to the list of resources in the Tunez.Music domain module.

The next step, just like when we built our first resource, is to consider what
kinds of attributes our new resource needs. What information should we
record about an Album? Right now we probably care about:

The artist who released the album
The album name
The year the album was released
And an image of the album cover. That’ll make Tunez look really nice!
Ash has a lot of inbuilt data types,^1 that can let you model just about anything.
If we were building a resource for a product in a clothing store, we might want
attributes for things like the item size, colour, brand name, and price. A listing
on a real estate app might want to store the property address, the number of
bedrooms and bathrooms, and the property size.

If none of the inbuilt data types cover what you need, you can also
create custom or composite data types.^2 These can neatly wrap
logic around discrete units of data, such as phone numbers, URLs,
or latitude/longitude co-ordinates.
In the attributes block of the Album resource, we can start adding our new
attributes:

02/lib/tunez/music/album.ex
attributes do
uuid_primary_key :id
attribute :name , :string do
allow_nil?false
end
attribute :year_released , :integer do
allow_nil?false
end
attribute :cover_image_url , :string
create_timestamp :inserted_at
update_timestamp :updated_at
end

The name and year_released attributes will be required, but the cover_image_url will
be optional. We might not have a high-quality photo on hand for every album,
but we can add them in later when we get them.

We haven’t added any field to represent the artist though — and that’s because
it’s not going to be just a normal attribute. It’s going to be a relationship.

Defining Relationships

Relationships, also known as associations , are how we describe connections
between resources in Ash. There are a couple of different relationship types

https://hexdocs.pm/ash/Ash.Type.html#module-built-in-types
https://hexdocs.pm/ash/Ash.Type.html#module-defining-custom-types
Chapter 2. Extending Resources with Business Logic • 36

we can choose from, based on the numbers of resources involved on each
side:

has_many relationships relate one resource to many other resources. These
are really common — a User can have many Posts, or a Book can have
many Chapters. These don’t store any data on the one side of the relation-
ship, but each of the items on the many side will have a reference back
to the one.
belongs_to relationships relate one resource to one parent/containing
resource. They’re usually the inverse of a has_many — in the examples
above, the resource on the many side would typically belong to the one
resource. A Chapter belongs to a Book, and a Post belongs to a User. The
resource belonging to another will have a reference to the related resource,
eg. a Chapter will have a book_id attribute, referencing the id field of the
Book resource.
has_one relationships are less common, but are similar to belongs_to relation-
ships. They relate one resource to one other resource, but differ in which
end of the relationship holds the reference to the related record. For a
has_one relationship, the related resource will have the reference. A common
example of a has_one relationship is Users and Profiles — a User could
have one Profile, but the Profile resource is what holds a user_id attribute.
many_to_many relationships, as the name suggests, relate many resources to
many other resources. These are where you have two pools of different
objects, and can link any two resources between the pools. Tags are a
really common example — a Post can have many Tags applied to it, and
a Tag can also apply to many different Posts.
In our case, we’ll be using belongs_to and has_many relationships — an Artist
has_many albums, and an Album belongs_to an artist.

In code, we define these in a separate top-level relationships block in each
resource. In the Artist resource, we can add a relationship with Albums:

02/lib/tunez/music/artist.ex
relationships do
has_many :albums , Tunez.Music.Album
end

And in the Album resource, a relationship back to the Artist resource:

02/lib/tunez/music/album.ex
relationships do
belongs_to :artist , Tunez.Music.Artist do
allow_nil?false

Resources and Relationships • 37

end
end
Now that our resource is set up, we can generate a database migration for it,
using the ash.codegen mix task.
$ mix ash.codegencreate_albums
This will generate a new Ecto migration in priv/repo/migrations/[timestamp]_cre-
ate_albums.exs to create the albums table in the database, including a foreign key
representing the relationship — this will link an artist_id field on the albums
table to the id field on artists table. A snapshot JSON file will also be created,
representing the current state of the Album resource.
The migration doesn’t contain a function call to create a database index for
the foreign key, though, and PostgreSQL doesn’t create indexes for foreign
keys by default. PostgreSQL’s behaviour may be surprising, but makes sense
when you consider that maintaining an index is extra overhead that you might
not get any benefit from.
To tell Ash to create an index for the foreign key, you can customize the refer-
ence of the relationship, as part of the postgres block in the resource.
02/lib/tunez/music/album.ex
postgres do
# ...
➤ references do
➤ reference :artist , index?: true
➤ end
end
This changes the database, so you’ll need to codegen another migration for
it (or delete the CreateAlbums migration and snapshot that we just generated,
and generate them again).
If you’re happy with the migrations, run them:
$ mix ash.migrate
And now we can start adding functionality. A lot of this will seem pretty
familiar from building out the Artist interface, so we’ll cover it quickly. There
are a few new interesting parts, however, due to the added relationship, so
let’s dig right in.

Album actions
If we look at an Artist’s profile page in the app, we can see a list of their
albums, so we’re going to need some kind of read action on the Album resource,
Chapter 2. Extending Resources with Business Logic • 38

to read the data to display. There’s also a button to add a new album, at the
top of the album list, so we’ll need a create action; and each album has Edit
and Delete buttons next to the title, so we’ll write some update and destroy
actions as well.

We can add those to the Album resource pretty quickly:

02/lib/tunez/music/album.ex
actions do
defaults[ :read , :destroy ]
create :create do
accept[ :name , :year_released , :cover_image_url , :artist_id ]
end
update :update do
accept[ :name , :year_released , :cover_image_url ]
end
end

We don’t have any customizations to make to the default implementation of
read or destroy, so we can define those as default actions. You might be thinking,
but won’t we need to customize the read action, to only show albums for a
specific artist? We actually don’t! When we load an artist’s albums on their
profile page, which we’ll see how to do shortly, we won’t be calling this action
directly — we’ll be asking Ash to load the albums through the albums relation-
ship on the Artist resource, which will automatically apply the correct filter.

We do have tweaks for the create and update actions, though — for the accept
list, of attributes that can be set when calling those actions. When creating
a record, it makes sense to need to set the artist_id for an album, otherwise it
won’t be set at all! When updating an album, though, does it really need to
be changeable? Can we see ourselves creating an album via the wrong artist
profile and then needing to change it later? It seems unlikely, so we don’t
need to accept the artist_id attribute in the update action.

We’ll also add code interface definitions for our actions, to make them easier
to use in an iex console, and easier to read in our liveviews. Again, these go
in our Tunez.Music domain module, with the resource definition.

02/lib/tunez/music.ex
resources do
# ...
resourceTunez.Music.Album do
define :create_album , action::create
define :get_album_by_id , action::read , get_by::id
define :update_album , action::update
define :destroy_album , action::destroy
end

Resources and Relationships • 39

end
Similar to artists, we’ve provided some sample album content for you to play
around with. To import it, you can run the following on the command line:
$ mix run priv/repo/seeds/02-albums.exs
This will populate a handful of albums for each of the sample artists we
seeded in code on page 16.
You can also uncomment the second seed file in the mix seed alias, in the
aliases function in mix.exs:
02/mix.exs
defp aliases do
[
setup: [ "deps.get" , "ash.setup" , "assets.setup" , "assets.build" , ...],
"ecto.setup" : [ "ecto.create" , "ecto.migrate" ],
➤ seed: [
➤ "run priv/repo/seeds/01-artists.exs" ,
➤ "run priv/repo/seeds/02-albums.exs" ,
➤ # "runpriv/repo/seeds/08-tracks.exs"
➤ ],
# ...
Now you can run mix seed at any time, to reset the artist and album data in
your database. And now we can start connecting the pieces, to view and
manage the album data in our liveviews.

Creating and updating albums
Our Artist page has a button on it to add a new album for that artist. This
links to the TunezWeb.Albums.FormLive liveview module, and renders a form tem-
plate similar to the artist form, with text fields for entering data. We can use
AshPhoenix to make this template functional, the same way we did for artists.
First, we construct a new form for the Album.create action, in mount/3:
02/lib/tunez_web/live/albums/form_live.ex
def mount(_params,_session,socket) do
➤ form= Tunez.Music.form_to_create_album()

socket=
socket
|> assign( :form , to_form(form))
...
We validate the form data and update the form in the liveview’s state, in the
“validate” handle_event/3 event handler:
Chapter 2. Extending Resources with Business Logic • 40

02/lib/tunez_web/live/albums/form_live.ex
def handle_event( "validate" , %{ "form" => form_data},socket) do
socket=
update(socket, :form , fn form->
AshPhoenix.Form.validate(form,form_data)
end )
{ :noreply , socket}
end

We submit the form in the “save” handle_event/3 event handler, and process the
return value:

02/lib/tunez_web/live/albums/form_live.ex
def handle_event( "save" , %{ "form" => form_data},socket) do
case AshPhoenix.Form.submit(socket.assigns.form, params: form_data) do
{ :ok , album}->
socket=
socket
|> put_flash( :info , "Albumsavedsuccessfully" )
|> push_navigate( to: ~ p "/artists/#{ album.artist_id }" )
{ :noreply , socket}
{ :error , form}->
socket=
socket
|> put_flash( :error , "Couldnot savealbumdata" )
|> assign( :form , form)
{ :noreply , socket}
end
end

And finally, we add another function head for mount/3, so we can differentiate
between viewing the form to add an album, and viewing the form to edit an
album, based on whether or not album_id is present in the params:

02/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "id" => album_id},_session,socket) do
album= Tunez.Music.get_album_by_id!(album_id)
form= Tunez.Music.form_to_update_album(album)
socket=
socket
|> assign( :form , to_form(form))
|> assign( :page_title , "UpdateAlbum" )
{ :ok , socket}
end

def mount(params,_session,socket) do
form= Tunez.Music.form_to_create_album()
...

Resources and Relationships • 41

If this was a bit too fast, there is a much more thorough rundown on how
this code works in Creating artists with AshPhoenix.Form, on page 25.
Using artist data on the album form
There’s one thing missing from this form, that will stop it from working as we
expect to manage Album records — there’s no mention at all of the Artist that
the album should belong to. There’s a field to enter an artist on the form, but
it’s disabled.
We do know which artist the album should belong to, though. We clicked the
button to add an album on a specific artist page, the album should be for
that artist! In the server logs in your terminal, you’ll see that we do have the
artist ID as part of the params to the FormLive liveview:
[debug]MOUNTTunezWeb.Albums.FormLive
Parameters:%{"artist_id"=> "an-artist-id"}
We can use this ID to load the artist record, show the artist details on the
form, and relate the artist to the album in the form.
In the second mount/3 function head, for the create action, we can load the artist
record using Music.get_artist_by_id, like we do on the artist profile page. The artist
can be assigned to the socket alongside the form.
02/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "artist_id" => artist_id},_session,socket) do
➤ artist= Tunez.Music.get_artist_by_id!(artist_id)
form= Tunez.Music.form_to_create_album()
socket=
socket
|> assign( :form , to_form(form))
➤ |> assign( :artist , artist)
...
In the first mount/3 function head, for the update action, we have the artist ID
stored on the album record we load. We can use it to load the Artist record
in a similar way:
02/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "id" => album_id},_session,socket) do
album= Tunez.Music.get_album_by_id!(album_id)
➤ artist= Tunez.Music.get_artist_by_id!(album.artist_id)
form= Tunez.Music.form_to_update_album(album)
socket=
socket
|> assign( :form , to_form(form))
➤ |> assign( :artist , artist)

Chapter 2. Extending Resources with Business Logic • 42

...
Now that we have an artist record assigned in the liveview, we can show the
artist name in the disabled field, in render/3:

02/lib/tunez_web/live/albums/form_live.ex
<. inputname= "artist_id" value= {@artist.name} label= "Artist" disabled/>

This doesn’t actually add the artist info to the form params, though, so we’ll
still get an error when submitting the form for a new album, even if all of the
data is valid. There are two ways we can address this: we could manually
update the form data before submitting the form, adding the artist_id from the
artist record already in the socket.

def handle_event( "save" , %{ "form" => form_data},socket) do
form_data= Map.put(form_data, "artist_id" , socket.assigns.artist.id)
...

This is easy to reason about, but feels messy. This code also runs when
submitting the form for both creating and updating an album, and the update
action on our Album resource specifically does not accept an artist_id attribute.
Submitting the form won’t raise an error — AshPhoenix throws away any
data that won’t be accepted by the underlying action — but it’s a sign that
we’re probably doing things wrong.

Instead, we can add a hook when we build the form for creating an album,
that will update the changeset pre-validation. It’s a similar idea, but because
it will only be configured on the create form, not the update form, it makes more
sense. AshPhoenix’s form builder functions support a number of options^3 to
configure how the form behaves, and one that we can use here is trans-
form_params. It accepts a function that will be called with the form and the
params just before the action is run, and there we can make sure the artist_id
is set to the value we want.

In the mount/3 function for the create action, add the transform_params option to
set the artist_id attribute:

https://hexdocs.pm/ash_phoenix/AshPhoenix.Form.html#for_create/3
Resources and Relationships • 43

02/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "artist_id" => artist_id},_session,socket) do
artist= Tunez.Music.get_artist_by_id!(artist_id)
form=
Tunez.Music.form_to_create_album(
➤ transform_params: fn _form,params,_context->
➤ Map.put(params, "artist_id" , artist.id)
➤ end
)
...
This is a common pattern to use when you want to provide data to an action
via a form, but it shouldn’t be editable by the user. If we were creating product
variants for the clothing store, for example a type of T-shirt that comes in
size M in black, we wouldn’t want the user to be able to set the parent product
ID manually. Even if they’re being sneaky in their browser and adding form
fields and populating them with data they shouldn’t be editing, we overwrite
them with the correct values, so nothing nefarious can happen. And now our
TunezWeb.Album.FormLive form should work properly, for creating album data.

Loading Related Resource Data
On the profile page for an Artist in TunezWeb.Artists.ShowLive, we want to show a
list of albums released by that artist. It’s currently populated with placeholder
data:
Chapter 2. Extending Resources with Business Logic • 44

And this data is defined in the handle_params/3 callback:

02/lib/tunez_web/live/artists/show_live.ex
def handle_params(%{ "id" => artist_id},_url,socket) do
artist= Tunez.Music.get_artist_by_id!(artist_id)
albums= [
%{
id: "test-album-1" ,
name:"TestAlbum" ,
year_released: 2023,
cover_image_url: nil
}
]
socket=
socket
|> assign( :artist , artist)
|> assign( :albums , albums)
|> assign( :page_title , artist.name)
{ :noreply , socket}
end

The Edit button for the album will still take you to the form we just built, but
it will error because the album ID doesn’t match a valid album in the database!

Because we’ve defined albums as a relationship in our Artist resource, we can
automatically load the data in that relationship, similar to an Ecto preload. All
actions support an extra argument of options , and one of the options for read
actions^4 is load — a list of relationships we want to load alongside the
requested data. This will use the read action we defined on the Album resource,
but include the correct filter to only load albums for the artist specified.

By default, loading relationship data with load will use the primary
read action of the target resource. As we added a primary read action
to the Artist resource, first by manually setting primary?true inside
the action and then changing it to a default action (which is pri-
mary by default), this works out of the box.
If we wanted to use a different action for reading data, this can be
configured with the read_action option^5 on the relationship.
We can update our call to get_artist_by_id! to include loading the albums relation-
ship, and remove the hardcoded albums:

https://hexdocs.pm/ash/Ash.html#read/2
https://hexdocs.pm/ash/dsl-ash-resource.html#relationships-has_many-read_action
Loading Related Resource Data • 45

02/lib/tunez_web/live/artists/show_live.ex
def handle_params(%{ "id" => artist_id},_url,socket) do
artist= Tunez.Music.get_artist_by_id!(artist_id, load: [ :albums ])
socket=
socket
|> assign( :artist , artist)
|> assign( :page_title , artist.name)
{ :noreply , socket}
end
We do also need to update a little bit of the template, as it referred to the
@albums assign (which is now deleted). In the render/1 function, we iterate over
the @albums and render album details for each:
02/lib/tunez_web/live/artists/show_live.ex

<**.** album_detailsalbum= _{album}_ />
This can be updated to render albums from the @artist instead: **02/lib/tunez_web/live/artists/show_live.ex**
<**.** album_detailsalbum= _{album}_ />
Now when we view the profile page for one of our sample artists, we should be able to see their actual albums, complete with album covers. Neat! We can use load to simplify how we loaded the artist for the album on the Album edit form, as well. Instead of making a second request to load the artist after loading the album, we can combine them into one call: **02/lib/tunez_web/live/albums/form_live.ex def** mount(%{ _"id"_ => album_id},_session,socket) **do** ➤ album= Tunez.Music.get_album_by_id!(album_id, _load:_ [ _:artist_ ]) form= Tunez.Music.form_to_update_album(album) socket= socket |> assign( _:form_ , to_form(form)) ➤ |> assign( _:artist_ , album.artist) ... The album data on the artist profile looks a little bit funny though — the albums aren’t in any kind of order on the page. We should probably show them in chronological order, with the most recent album release listed first.
Chapter 2. Extending Resources with Business Logic • 46

We can do this by defining a sort for the album relationship, using the sort
option^6 on the :albums relationship iin Tunez.Music.Artist.
02/lib/tunez/music/artist.ex
relationships do
has_many :albums , Tunez.Music.Album do
➤ sort year_released::desc
end
end
This takes a list of fields to sort by, and will sort in ascending order by default.
To flip the order, you can use a keyword list instead, with the field names as
keys and either :asc or :desc as the value for each key, just like Ecto.
Now if we reload an artist’s profile, we should see the albums being displayed
in chronological order, most recent first. That’s much more informative!

Structured Data with Validations and Identities
Tunez can now accept form data that should be more structured, instead of
just text. We’re also looking at data in a smaller scope. Instead of “any artist
in the world that ever was”, which is a massive data set; we’re looking at
albums for any individual artist, which is a much smaller and well-defined
list.
Let’s set some stricter rules for this data, for better data integrity.
Consistent data with validations
With Albums, we need users to enter a valid year for an Album’s year_released
attribute, instead of any old integer; and a valid-looking image URL for the
cover_image_url attribute. We can enforce these rules with validations.
Any defined validations are checked when calling an action, before the core
functionality (eg. saving or deleting) is run; and if any of the validations fail,
the action will abort and return an error. We’ve seen implicit cases of this
already, when we declared that some attributes were allow_nil?false — as well
as setting the database field for the attribute to be non-nullable, Ash also
validates that the value is present before it even gets to the database.
We can add our own validations to our resources, either for an individual
action or globally for the entire resource, much like preparations. In our case,
we want to ensure that the data is valid at all times, so we can add global
validations by adding a new top-level validations block in the Album resource:
https://hexdocs.pm/ash/dsl-ash-resource.html#relationships-has_many-sort
Structured Data with Validations and Identities • 47

02/lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
# ...
validations do
# Validationswillgo in here
end
end

We’ll add two validations to this block, one for year_released, and one for cov-
er_image_url. Ash provides a lot of built-in validations,^7 and two of them are
relevant here: numericality and match.

For year_released, we want to validate that the user enters a number between,
say, 1950 (arbitrarily-chosen number!) and next year (to allow for albums
that have been announced but not released), but we should only validate the
field if the user has actually entered data. This could be written like so:

02/lib/tunez/music/album.ex
validations do
validatenumericality( :year_released ,
greater_than: 1950,
less_than_or_equal_to: &MODULE.next_year/0
),
where: [present( :year_released )],
message:"mustbe between 1950 and nextyear"
end

Ash will accept any zero-arity (no-argument) function reference here. The
next_year function doesn’t exist, so we can add it to the very end of the the
Album module:

02/lib/tunez/music/album.ex
def next_year, do : Date.utc_today().year + 1

Note that this validation isn’t 100% foolproof — if our favorite band from New
Zealand is releasing an album on January 1 in the year after next, we might
not be able to add that album to Tunez just yet. That’s a bit of an edge case
outside the scope of this book though!

For cover_image_url, we’ll add a regular expression to make sure user enters
what looks like an image URL. This isn’t comprehensive by any means — in
a real-world app, we’d likely be implementing a fully-featured file uploader,
verifying that the uploaded files were valid images, etc. — but for our use
case, it’ll solve copy-paste mistakes, or entering nonsense.

https://hexdocs.pm/ash/Ash.Resource.Validation.Builtins.html
Chapter 2. Extending Resources with Business Logic • 48

02/lib/tunez/music/album.ex
validations do
# ...
validatematch( :cover_image_url ,
~ r "(^https://|/images/).+(.png|.jpg)$"
),
where: [changing( :cover_image_url )],
message:"muststartwithhttps://or /images/"
end

For a little optimization, we’ll also add a check that only runs the validation
if the value is changing , using the changing/1^8 function in the where condition
of the validation.

We don’t need to do anything to integrate these validations into Album actions,
or into the forms in our views. Because they’re global validations, they apply
for every action, and because the forms in our liveviews are built for actions,
they will automatically be included. Entering invalid data in the album form
will now show validation errors to our users, letting them know what to fix:

Unique data with identities

There’s one last feature we can add, for a better user experience on this form.
Some artists have a lot of albums, and it would be nice if we could ensure
that duplicate albums don’t accidentally get entered. Maintaining data
integrity, especially with user-editable data, is important — you wouldn’t see
Wikipedia allowing multiple pages with the same name, for example, they
have to be disambiguated in some way. We want Tunez to be an accurate
canonical list of artist and album data.

Tunez will consider an album to be a duplicate if it has the same name as
another album by the same artist, ie. the combination of name and artist_id

https://hexdocs.pm/ash/Ash.Resource.Validation.Builtins.html#changing/1
Structured Data with Validations and Identities • 49

should be unique for every album in the database. (We’ll assume that separate
versions of albums with the same name get suffixes attached, like “Remas-
tered” or “Live” or “Taylor’s Version”.) For ensuring this uniqueness, we can
use an identity on our resource.

Ash defines an identity^9 as any attribute, or combination of attributes, that
can uniquely identify a record. A primary key is a natural and automatically-
generated identity, but our data may lend itself to other identities as well.

To add the new identity to our resource, add a new top-level identities block to
the Album resource. An identity has a name, and a list of attributes that
make up that identity. We can also specify a message to display on identity
violations:

02/lib/tunez/music/album.ex
identities do
identity :unique_album_names_per_artist , [ :name , :artist_id ],
message:"alreadyexistsfor this artist"
end

The way identities are handled depends on the data layer being used. Because
we’re using AshPostgres, the identity will be handled at the database level as
a unique index on the two database fields, albums.name and albums.artist_id.

To create the index in the database, we can generate migrations after adding
the identity to the Album resource:

$ mix ash.codegenadd_unique_album_names_per_artist

This is the first time we’ve modified a resource and then generated migrations,
so it’s worth taking a bit of a closer look.

Like the previous times we’ve generated migrations, AshPostgres has generated
a snapshot file representing the current state of the Album resource. It also
created a new migration, which has all of the differences between the last
snapshot from when we created the resource, and the brand-new snapshot:

02/priv/repo/migrations/[timestamp]_add_unique_album_names_per_artist.exs
def up do
createunique_index( :albums , [ :name , :artist_id ],
name:"albums_unique_album_names_per_artist_index"
)
end

def down do
drop_if_existsunique_index( :albums , [ :name , :artist_id ],
name:"albums_unique_album_names_per_artist_index"

https://hexdocs.pm/ash/identities.html
Chapter 2. Extending Resources with Business Logic • 50

)
end

Ash correctly worked out that the only difference that required database
changes was the new identity, so it created the correct migration to add and
remove the unique index we need. Awesome!

Run the migration generated:

$ mix ash.migrate

And now we can test out the changes on the album form. Create an album
with a specific name, and then try to create another one for the same artist
with the same name — you should get a validation error on the name field,
with the message we specified for the identity.

Deleting All of the Things
We’ll round out the CRUD interface for Albums with the destroy action. We
might not need to invoke it too much while using Tunez, but keeping our data
clean and accurate is always an important priority.

While building the Album resource, we’ve also accidentally introduced a bug
around Artist deletion, so we should address that as well.

Deleting album data

Deleting albums is done from the artist’s profile page, TunezWeb.Artists.ShowLive,
via a button next to the name of the album.

Clicking the icon will send the “destroy-album” event to the liveview. In the
event handler, we can fetch the album record from the list of albums we
already have in memory, and then delete it. It’s a little bit verbose, but it saves
another round trip to the database to look up the album record. Like with
artists, we also need to handle both the success and error cases:

02/lib/tunez_web/live/artists/show_live.ex
def handle_event( "destroy-album" , %{ "id" => album_id},socket) do
case Tunez.Music.destroy_album(album_id) do
:ok ->
socket=
socket
|> update( :artist , fn artist->
Map.update!(artist, :albums , fn albums->
Enum.reject(albums,&(&1.id == album_id))
end )
end )
|> put_flash( :info , "Albumdeletedsuccessfully" )

Deleting All of the Things • 51

{ :noreply , socket}
{ :error , error}->
Logger.info( "Couldnot deletealbum'#{ album_id }': #{ inspect(error) }" )
socket=
socket
|> put_flash( :error , "Couldnot deletealbum" )
{ :noreply , socket}
end
end

We’ve almost finished the initial implementation for albums! There’s a bug
in our Album implementation though — if you try to delete an artist that has
albums, you’ll see what we mean. We’ll fix that now!

Cascading deletes with AshPostgres

When we defined our Album resource, we added a belongs_to relationship to
relate it to Artists:

02/lib/tunez/music/album.ex
relationships do
belongs_to :artist , Tunez.Music.Artist do
allow_nil?false
end
end

When we generated the migration for this resource in Defining Relationships,
on page 36, it created a foreign key in the database, linking the artist_id field
on the albums table to the id field on the artists table:

02/priv/repo/migrations/[timestamp]_create_albums.exs
def up do
createtable( :albums , primary_key: false) do
# ...
add :artist_id ,
references( :artists ,
column::id ,
name:"albums_artist_id_fkey" ,
type::uuid ,
prefix:"public"
)
end
end

What we didn’t define, however, was what should happen with this foreign
key value when artists are deleted — if there are three albums with artist_id=
"abc123", and artist abc123 is deleted, what happens to those albums?

Chapter 2. Extending Resources with Business Logic • 52

The default behaviour, as we’ve seen, is to prevent the deletion from happen-
ing. This is verified by looking at the server logs when you try to delete one
of the artists that this affects:
[info]Couldnot deleteartist' «uuid» ': %Ash.Error.Invalid{bread_crumbs:
["Errorreturnedfrom:Tunez.Music.Artist.destroy"], changeset:"#Changeset<>",
errors:[%Ash.Error.Changes.InvalidAttribute{field::id,message:"wouldleave
recordsbehind",private_vars:[constraint::foreign,constraint_name:
"albums_artist_id_fkey"],...
Because an album doesn’t make sense without an artist (we can say the
albums are dependent on the artist), we should delete all of an artist’s albums
when we delete an artist. There are two ways we can go about this, each with
its own pros and cons:
We can delete the dependent records in code — in the destroy action for
an artist, we can call the destroy action on all of the artist’s albums as well.
It’s very explicit what’s going on, but it can be really slow (relatively
speaking). Sometimes it’s a necessary evil though, if you need to run
business logic in each of the dependent destroy actions.
Or we can delete the dependent records in the database, by specifying
the ON DELETE behaviour^10 of the foreign key that raised the error. This is
super-fast, but it can be a little unexpected if you don’t know it’s happen-
ing. You don’t get the chance to run any business logic in your app’s code
— but if you don’t need to, this is easily the preferred option.
Which one you use really depends on the requirements of the app you’re
building, and as the requirements of your app change, you might need to
change the behaviour. For now we’ll go with the quick ONDELETE option, which
is to delete the dependent records in the database (option 2).
AshPostgres lets us specify the ON DELETE behaviour for a foreign key by con-
figuring a custom reference in the postgres block^11 of our resource. This goes on
the resource that has the foreign key, ie. in this case, the Tunez.Music.Album
resource:
02/lib/tunez/music/album.ex
postgres do
# ...
references do
➤ reference :artist , index?: true, on_delete::delete
end
10.https://www.postgresql.org/docs/16/sql-createtable.html#SQL-CREATETABLE-PARMS-REFERENCES
11.https://hexdocs.pm/ash_postgres/dsl-ashpostgres-datalayer.html#postgres-references
Deleting All of the Things • 53

end

This will make a structural change to our database, so we need to generate
migrations and run them:

$ mix ash.codegenconfigure_reference_for_album_artist_id
$ mix ash.migrate

This will generate a migration that modifies the existing foreign key, setting
on_delete::delete_all. Running the migration sets the ON DELETE clause on the
artist_id field:

tunez_dev=#\d albums
«definitionof the columnsand indexes of the table»
Foreign-keyconstraints:
"albums_artist_id_fkey"FOREIGNKEY (artist_id)REFERENCES
artists(id)ON DELETECASCADE

And now we can delete artists again, even if they have albums; no error occurs
and no data is left behind.

Our albums are really shaping up! They’re not complete — we’ll look at adding
track listings in Chapter 8, Fun With Nested Forms, on page 195 — but for
now they’re pretty good, so we can step back and revisit our artist form.

What if we needed to make changes to the data we call an action with, before
saving it into the data layer? The UI in our form might not exactly match the
attributes we want to store, or we might need to format the data, or condition-
ally set attributes based on other attributes. We can look at making these
kinds of modifications with changes.

Changing Data Within Actions
We’ve been using some built-in changes already in Tunez, without even real-
izing it, for inserted_at and updated_at timestamps on our resources. We didn’t
write any code for them, but Ash takes care of setting them to the current
time. Both timestamps are set when calling any create action, and updated_at
is set when calling any update action.

Like preparations and validations, changes can be defined at both the top-
level of a resource, or at an individual action level. The implementation for
timestamps could look like this:

changes do
changeset_attribute( :inserted_at , &DateTime.utc_now/0), on: [ :create ]
changeset_attribute( :updated_at , &DateTime.utc_now/0)
end

Chapter 2. Extending Resources with Business Logic • 54

By default, global changes will run on any create or update action,
which is why we wouldn’t have to specify an action type for
:updated_at above. They can be run on destroy actions, but only when
opting-in by specifying on: [:destroy] on the change.
There’s quite a few built-in changes^12 you can use in your resources, or you
can add your own, either inline or with a custom module. We’ll go through
what it looks like to build one inline, and then how it can be extracted to a
module for re-use.

Defining an inline change

Over time, artists go through phases, and sometimes change their names
after re-branding, lawsuits, or lineup changes. Let’s track updates to an
artist’s name over time, by keeping a list of all of the previous values that the
name field has had, with a new change function.

This list will be stored in a new attribute, called previous_names, so we can add
it as an attribute in the Artist resource. It’ll be a list, or array , of the previous
names, and default to an empty list for new artists:

02/lib/tunez/music/artist.ex
attributes do
# ...
attribute :previous_names , { :array , :string } do
default[]
end
# ...
end

Generate a migration to add the new attribute to the database, and run it:

$ mix ash.codegenadd_previous_names_to_artists
$ mix ash.migrate

We only need to run this change when the Artist form is submitted to update
an Artist, so we can add the change within the update action. (If your Artist
resource is using defaults to define it’s actions, you’ll need to remove :update
from that list and define the action separately.) The change macro can take a
few different forms of arguments, the simplest being a two-argument anony-
mous function that takes and returns an Ash.Changeset:

02/lib/tunez/music/artist.ex
actions do
# ...

12.https://hexdocs.pm/ash/Ash.Resource.Change.Builtins.html

Changing Data Within Actions • 55

update :update do
accept[ :name , :biography ]
change fn changeset,_context->
changeset
end
end
end

We can make any changes to the changeset we want, including deleting data,
changing relationships, adding errors, and more. In this way, changes could
be thought of as more general versions of validations — if we set an error
message in the changeset, it will stop the action from taking place and return
the error to the user.

In our anonymous function, we can use some of the functions from
Ash.Changeset^13 to read both the old and new name values from the changeset,
and update the previous_names attribute where applicable:

02/lib/tunez/music/artist.ex
change fn changeset,_context->
new_name= Ash.Changeset.get_attribute(changeset, :name )
previous_name= Ash.Changeset.get_data(changeset, :name )
previous_names= Ash.Changeset.get_data(changeset, :previous_names )
names=
[previous_name| previous_names]
|> Enum.uniq()
|> Enum.reject( fn name-> name== new_name end )
Ash.Changeset.change_attribute(changeset, :previous_names , names)
end

Like actions, the change macro also accepts an optional second argument of
options for the change. Because we only need to update previous_names if the
name field is actually being modified, we can add a changing/1^14 validation for
the change function with a where check:

02/lib/tunez/music/artist.ex
change fn changeset,_context->
# ...
end ,
where: [changing( :name )]

If the validation fails, the change function is skipped, and the previous names
won’t be updated. That’ll save a few CPU cycles!

13.https://hexdocs.pm/ash/Ash.Changeset.html
14.https://hexdocs.pm/ash/Ash.Resource.Validation.Builtins.html#changing/1

Chapter 2. Extending Resources with Business Logic • 56

There’s one other small change we need to make, for this change function to
work. By default, Ash will try to do as much work as possible in the data
layer instead of in memory, via a concept called atomics. Because we’ve written
our change functionality as imperative code, instead of in a data-layer-com-
patible way, we’ll need to disable atomics for this update action with the
require_atomic?^15 option.

02/lib/tunez/music/artist.ex
update :update do
require_atomic?false
# ...
end

We’ll dig into atomics, and how to write changes atomically, later in the (as
yet) unwritten content.

Defining a change module

The inline version of the previous_names change works, but it’s a bit long and
imperative, smack-bang in the middle of our declarative resource. Imagine if
we had a complex resource with a lot of attributes and changes, it’d be really
hard to navigate and handle! And what if we wanted to apply this same record-
previous-values logic to something else, like users who can change their
usernames? We can extract the logic out into a change module.

A change module is a standalone module that uses Ash.Resource.Change.^16 Its
main access point is the change/3 function, which has a similar function signa-
ture as the anonymous change function we defined earlier, but with an added
second opts argument. We can move the content of the anonymous change
function, and insert it directly into a new change/3 function in a new change
module:

02/lib/tunez/music/changes/update_previous_names.ex
defmodule Tunez.Music.Changes.UpdatePreviousNames do
use Ash.Resource.Change
def change(changeset,_opts,_context) do
# The codepreviouslyin the body of the anonymouschangefunction
end
end

And update the change call in the update action to point to the new module
instead:

15.https://hexdocs.pm/ash/dsl-ash-resource.html#actions-update-require_atomic?
16.https://hexdocs.pm/ash/Ash.Resource.Change.html

Changing Data Within Actions • 57

02/lib/tunez/music/artist.ex
update :update do
require_atomic?false
accept[ :name , :biography ]
➤ changeTunez.Music.Changes.UpdatePreviousNames, where: [changing( :name )]
end
A shorter and easier-to-read resource isn’t the only reason to extract changes
into their own modules. Change modules have a performance benefit during
development, by breaking compile-time dependencies between the resources
and the code in the change functions. This makes recompiling code after
changes more performant! Change modules can also define their own options
and interface, and validate their usage at compile time. To reuse the current
UpdatePreviousNames module, we might want to make the field names configurable
instead of hardcoded to name and previous_names, and have a flag for allowing
duplicate values or not.
Details on configuring and validating the interface for change modules using
the Spark^17 library are a bit too much to go into here, but built-in changes like
Ash.Resource.Change.SetAttribute^18 are a great way to see how they can be imple-
mented.

Changes run more often than you might think!
It’s really important to note that changes aren’t only run when actions are
called. When forms are tied to actions, like our update action is tied to the
Artist edit form in the web interface, the pre-persistence steps like validations
and changes are run multiple times:
When building the initial form
During any authorization checks (covered in Introducing Policies, on page
131 )
On every validation of the form
And when actually submitting the form or calling the action.
Because of this, changes that are time-consuming, or have side effects such
as calling external APIs, should be wrapped in hooks such as Ash.Change-
set.before_action or Ash.Changeset.after_action — these will only be called immediately
before or after the action is run.
If we wanted to do this for the UpdatePreviousNames change module, it would look
like this:
17.https://hexdocs.pm/spark/
18.https://github.com/ash-project/ash/blob/main/lib/ash/resource/change/set_attribute.ex
Chapter 2. Extending Resources with Business Logic • 58

def change(changeset,_opts,_context) do
Ash.Changeset.before_action(changeset, fn changeset->
# The codepreviouslyin the body of the function
# It can stilluse any `opts`or `context`passedin to the top-level
# changefunction,as well.
end )
end
The anonymous function set as the before_action would only run once — when
the form is submitted — but it would still have the power to set errors on the
changeset to prevent the changes from being saved, if necessary.
Setting attributes in a ‘before_action‘ hook will bypass validations!
It’s super-important to note that a function defined as a before_action
will only run right before save — after validations of the action
have been run.
As such, it’s possible to get your data into an invalid state in the
database. If you validate that an album’s year_released must be in
the past, but then call Ash.Changeset.change_attribute(changeset,
:year_released,2050) in your before_action function, that year 2050 will
happily be saved into the database. Ash will show a warning at
runtime if you do this, which is helpful.
If you want to force any validation to run after before_action hooks,
you can use the before_action?^19 option on the validation, eg.
validatenumericality( :year_released , ...), before_action?: true
Or if you simply want to silence the warning because you’re fine
with skipping the validation, replace your call to change_attribute
with force_change_attribute instead.
Rendering the previous names in the UI
To finish this feature off, we can show any previous names that an artist has
had, on their profile page.
In TunezWeb.Artists.ShowLive, we can add the names printed out, as part of the

block in the render/1 function: **02/lib/tunez_web/live/artists/show_live.ex** <**.** header> <**.** h1>... ➤ <:subtitle:if= _{@artist.previous_names_ **!= []}** > ➤ formerlyknownas: {Enum.join(@artist.previous_names,", ")}
19.https://hexdocs.pm/ash/dsl-ash-resource.html#validations-validate-before_action?
Changing Data Within Actions • 59

➤ </:subtitle>
...
</. header>

And now our real Artist pages, complete with their real Album listings, are
complete! We’ve learnt about the tools Ash provides for relating resources
together, and how we can work with related data for efficent data loading,
preparations, and data integrity. These are core building blocks, that you can
use when building out your own applications and we’ll be using more of in
the future as well.
And we still haven’t needed to write a lot of code — the small snippets we’ve
written, like validations and changes, have been very targeted and specific,
but have been usable throughout the whole app, from seeding data in the
database to rendering errors in the UI.
We’re only scratching the surface though — in the next chapter, we’ll make
the Artist catalog really useful, giving users the ability to search, sort, and
page through artists, using more of Ash’s built-in functionality. We’ll also see
how we can use calculations and aggregates to perform some sophisticated
queries, without even breaking a sweat. This is where things will really get
interesting!
Chapter 2. Extending Resources with Business Logic • 60

CHAPTER 3
