Fun With Nested Forms

In the last chapter, we learnt all about how we can test the applications we
build with Ash. The framework can do a lot for us, but at the end of the day,
we own the code we write and the apps we build. With testing tools and know-
how in our armory, we can be more confident that our apps will continue to
behave as we expect.

Now we can get back to the fun stuff: more features! Knowing which artists
released which albums is great, but albums don’t exist in a vacuum — they
have tracks on them. (You might even be listening to some tracks from your
favorite album right now as you read this.) Let’s build a resource to model a
Track, and then we can look at how to manage them.

Setting Up a Track Resource
A track is a music-related resource, so we can add it to the Tunez.Music domain
using the ash.gen.resource Mix task:

$ mix ash.gen.resourceTunez.Music.Track --extendpostgres

This will create a basic empty Track resource in lib/tunez/music/track.ex, as well
as listing it as a resource in the Tunez.Music domain. What data do we need to
store about tracks on an album? We probably care about the following:

The order of tracks on the album
The name of each track
The duration of each track, which we’ll store as a number of seconds
And finally, we need to know which album the tracks belongs to
We’ll also add an id and some timestamps, purely for informational reasons.

All of the fields will be required, so we can add them to the Tunez.Music.Track
resource and mark them all as allow_nil?false:

08/lib/tunez/music/track.ex
defmodule Tunez.Music.Track do
# ...
attributes do
uuid_primary_key :id
attribute :order , :integer do
allow_nil?false
end
attribute :name , :string do
allow_nil?false
end
attribute :duration_seconds , :integer do
allow_nil?false
constraints min: 1
end
create_timestamp :inserted_at
update_timestamp :updated_at
end
relationships do
belongs_to :album , Tunez.Music.Album do
allow_nil?false
end
end
end
The order field will be an integer that represents a track’s place in its track
list. The first track will have order 1, the second track will have order 2, and
so on.
The relationship between tracks and albums can go both ways: an album can
have many tracks, and that’s how we’ll work with them most of the time. We
can add that relationship to the Tunez.Music.Album resource as well:
08/lib/tunez/music/album.ex
relationships do
# ...
➤ has_many :tracks , Tunez.Music.Track do
➤ sort order::asc
➤ end
end
There are a lot of options that can be applied to relationships, so we can do
neat things like always sort tracks on an album by their order attribute, using
the sort^1 option of the has_many relationship.

https://hexdocs.pm/ash/dsl-ash-resource.html#relationships-has_many-sort
Chapter 8. Fun With Nested Forms • 196

Storing the track duration as a number instead of as a formatted string (eg.
“3:32”) might seem strange, but it will allow us to do some neat calculations
using the data. We can calculate the duration of a whole album by adding
up the track durations or maybe the average track duration for an artist or
album. We don’t have to show the raw number to the user, but having it will
be very useful.
Before we generate a migration for this new resource, there’s one other thing
we should add. Like we saw in chapter 2on page 53 when we created the
Album resource, albums don’t make sense without an associated artist, and
neither do tracks without their album. If an album gets deleted, all of its
tracks should be deleted, too. To do this, we can customize the reference^2 to
the albums table, in the postgres block of the Tunez.Artist.Track resource. We’ll add
an index to the foreign key as well, with index? true.
08/lib/tunez/music/track.ex
postgres do
table "tracks"
repoTunez.Repo
➤ references do
➤ reference :album , index?: true, on_delete::delete
➤ end
end
Once the resource is set up, we can generate a migration to create the database
table and run it:
$ mix ash.codegenadd_album_tracks
$ mix ash.migrate

Reading and writing track data
At the moment, the Tunez.Music.Track resource has no actions at all. So what do
we need to add? Our end goal is something that looks like the following:
https://hexdocs.pm/ash_postgres/dsl-ashpostgres-datalayer.html#postgres-references-reference
Setting Up a Track Resource • 197

On a form like this, we can edit all of the tracks of an album at once via the
form for creating or updating an album. We won’t need to manually call any
actions on the Track resource to do this — Ash will handle it for us, once
configured — but the actions still need to exist for Ash to call.

The actions we need to define will therefore be pretty similar to those we would
define for any other resource. The fact our primary interface for tracks will
be via an album doesn’t mean that we won’t also be able to manage tracks
on their own, but we won’t build a UI to do so.

On that note, we can add four actions for our basic CRUD functionality:

08/lib/tunez/music/track.ex
defmodule Tunez.Music.Track do
# ...
actions do
defaults[ :read , :destroy ]
create :create do
primary?true
accept[ :order , :name , :duration_seconds , :album_id ]
end
update :update do
primary?true
accept[ :order , :name , :duration_seconds ]
end
end
end

These actions do need to be explicitly marked with primary?true. When Ash
manages the records for us, it needs to know which actions to use. By default,
Ash will look for primary actions of the type it needs (e.g., a primary action
of type create to insert new data), so we need to define them.

“Wait! Wait!” we hear you cry. “Didn’t you say that users wouldn’t have to
deal with track durations as a number of seconds?” Yes, we did, but we’ll add
that feature after we get the basic form UI up and running.

Managing Relationships for Related Resources
We want to manage tracks via the form for managing an album, so a lot of
the code we’ll be writing in this chapter will be in the TunezWeb.Albums.FormLive
liveview module. There’s a track_inputs/1 function component already defined in
the liveview, for rendering a table of tracks for the album using Phoenix’s
standard inputs_for^3 component. This component will iterate over the data in
@form[:tracks], and render a row of fields for each item in the list.

https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#inputs_for/1
Chapter 8. Fun With Nested Forms • 198

To include the track_inputs/1 component in our form, we can render it at the
bottom of the main render/1 action, right above the Save button:
08/lib/tunez_web/live/albums/form_live.ex
<% # ... %>
<. inputfield= {form[:cover_image_url]} label= "CoverImageURL" />
➤ <. track_inputsform= {form} />

<:actions>
<% # ... %>
In a browser, if you now try to create or edit an album, you’ll see an error
from Ash telling us that we need to do a little bit more configuring first:
tracksat path[] mustbe configuredin the formto be usedwith
`inputs_for`.For example:
Thereis a relationshipcalled`tracks`on the resource`Tunez.Music.Album`.
Perhapsyou are missingan argumentwith`changemanage_relationship`in
the actionTunez.Music.Album.update?
This is a helpful error message, more so than it might first appear. Ash doesn’t
know what to do with our attempt to render forms for tracks. They’re not
something that the actions for the form, create and update on the Tunez.Music.Album
resource, know how to process.
tracks isn’t an attribute of the resource, so we can’t add it to the accept list in
the actions. They’re a relationship! To use them in the actions, we need to
add them as an argument to the actions, as the error suggests, and then
process them with the built-in manage_relationship change function.
Managing relationships with... err... manage_relationship
Using the manage_relationship^4 function is getting its own section because it’s so
flexible and powerful. If you’re ever looking to deal with relationship data in
an action, it’s likely going to be some invocation of manage_relationship, with
varying options.
The full set of options is defined in the same-named function on Ash.Changeset^5
(be warned, there are a lot of options.) The main option to pay attention to is
the type option: these are shortcuts to different behaviours depending on
whether the data provided is already related to the current record. The two
most common type values you’ll see for forms in the wild are append_and_remove
and direct_control.
https://hexdocs.pm/ash/Ash.Resource.Change.Builtins.html#manage_relationship/3
https://hexdocs.pm/ash/Ash.Changeset.html#manage_relationship/4
Managing Relationships for Related Resources • 199

Using type append_and_remove

append_and_remove is a way of saying “replace the existing data in this relation-
ship with this new data, adding and removing records where necessary”. This
typically works with IDs of existing records, either singular or as a list. A
common example of using this is with tagging. If you provide a list of tag IDs
as the argument, Ash can handle the rest.

append_and_remove can also be used for managing belongs_to relationships. In
Tunez, we’ve allowed the foreign key relationships to be written directly, such
as the artist_id attribute when creating an Album resource. This create action
on Tunez.Music.Album could also be written as follows:

create :create do
accept[ :name , :year_released , :cover_image_url ]
argument :artist_id , :uuid , allow_nil?: false
changemanage_relationship( :artist_id , :artist , type::append_and_remove )
end

This code will take the named argument (artist_id) and use it to update the
named relationship (artist), using the append_and_remove strategy.

Writing the code using manage_relationship this way does have an extra benefit.
Ash will verify that the provided artist_id belongs to a valid artist that the current
user is authorized to read , before attempting to insert the record into the
database. Depending on your app’s requirements, this could be very useful.
If you were building a form to assign a user to a user group, for example, you
wouldn’t want a malicious user to edit the form using their developer tools,
add the group ID of the secret_admin_group into it (if they knew it), and success-
fully join that group!

Using type direct_control

direct_control maps more to what we want to do on our Album form: manage
relationship data by editing all of the related records. As the name implies,
it gives us direct control over the relationship and the full data of each of the
records within it.

While append_and_remove focuses on managing the links between existing records,
direct_control is about creating and destroying the related records themselves.
If we edit an album and remove a track, that track shouldn’t be unlinked
from the album, it should be deleted.

Let’s see it in action. Following the instructions from the TunezWeb.Albums.FormLive
error message we saw previously, we can add an argument for tracks and a
manage_relationship change to the create and update actions in the Tunez.Music.Album

Chapter 8. Fun With Nested Forms • 200

resource. We’ll be submitting data for multiple tracks in a list, and each track
will be a map of attributes:
08/lib/tunez/music/album.ex
actions do
# ...
create :create do
accept[ :name , :year_released , :cover_image_url , :artist_id ]
➤ argument :tracks , { :array , :map }
➤ changemanage_relationship( :tracks , type::direct_control )
end
update :update do
accept[ :name , :year_released , :cover_image_url ]
➤ require_atomic?false
➤ argument :tracks , { :array , :map }
➤ changemanage_relationship( :tracks , type::direct_control )
end
end
Because the name of the argument and the name of the relationship to be
managed are the same (tracks), we can omit one when calling manage_relationship.
Every little bit helps!
Another mention of atomics...
Like when we implemented previous nameson page 55 for artists,
we also need to mark this action as require_atomic?false. Because Ash
needs to figure out which related records to update, which to add,
and which to delete when updating a record, calls to manage_relation-
ship in update actions currently can’t be converted into logic to be
pushed into the database.
In the future, manage_relationship will be improved to support atomic
updates for most of the option arrangements that you can provide,
but for now it requires us to set require_atomic?false.

Trying to create or edit an album should now render the form without error.
You should see an empty Tracks table with a button to add a new track (that
won’t work yet, because haven’t implemented it). Our two actions can now
manage relationship data for tracks. To prove this, in iex, you can build some
data in the shape that the Album create action expects with an existing artist_id,
and then call the action:
iex(1)> tracks= [
%{order:1, name:"TestTrack1", duration_seconds:120},
%{order:3, name:"TestTrack3", duration_seconds:150},
%{order:2, name:"TestTrack2", duration_seconds:55}
Managing Relationships for Related Resources • 201

]
[...]
iex(2)> Tunez.Music.create_album!(%{ name:"TestAlbum" , artist_id:«uuid» ,
year_released:2025,tracks:tracks},authorize?:false)
«SQL queryto createthe album»
«SQL queriesto createeachof the tracks»
#Tunez.Music.Album<
tracks:[
#Tunez.Music.Track<order:1, ...>
#Tunez.Music.Track<order:2, ...> ,
#Tunez.Music.Track<order:3, ...>
],
name:"TestAlbum",...

Note that we don’t have to provide the album_id for any of the maps of track
data — we can’t , because we’re creating a new album and it doesn’t have an
ID yet. Ash takes care of that, creating the album record first, and then adding
the new album ID to each of the tracks.
If we try to edit the album we just created from the web app, you might be
surprised that the tracks aren’t there. That’s because we haven’t loaded them.
Not loading the track data is basically the same as saying there are no tracks
at all. We can update the mount/3 function in TunezWeb.Albums.FormLive when we
load the album and artist to also load the tracks for the album.
08/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "id" => album_id},_session,socket) do
album=
Tunez.Music.get_album_by_id!(album_id,
➤ load: [ :artist , :tracks ],
actor: socket.assigns.current_user
)
# ...
And voilà, the tracks will appear on the form! You can edit the existing tracks
and save the album, and the data will be updated. All of the built-in validations
from defining constraints and allow_nil?false on the Track’s attributes will be
run. You won’t be able to save tracks without a name or with a duration less
than 1 second.

Adding and removing tracks via the form
To make the form really usable, though, we need to be able to add new tracks
and delete existing ones. The UI is already in place for it; the form has an
“Add Track” button, and each row has a little trash can button to delete it.
Chapter 8. Fun With Nested Forms • 202

Currently, the buttons send the events add-track and remove-track to the FormLive
liveview, but the event handlers don’t do anything... yet.
Adding new rows for track data
AshPhoenix provides helper functions that we can use for adding and
removing nested rows to our form, namely AshPhoenix.Form.add_form^6 and
remove_form.^7 In the add-track event handler, we can update the form reference
stored in the socket and add a form at the specified path , or layer of nesting:
08/lib/tunez_web/live/albums/form_live.ex
def handle_event( "add-track" , _params,socket) do
➤ socket=
➤ update(socket, :form , fn form->
➤ AshPhoenix.Form.add_form(form, :tracks )
➤ end )

{ :noreply , socket}
end
If you’re more familiar with the conventional Phoenix method of adding form
inputs using a hidden checkbox,^8 AshPhoenix supports that as well.^9 It’s a
little less obvious as to what’s going on, though, which is why we’d always
opt for the more direct event handler way.
We can make our new form rows more user-friendly by auto-populating the
order field. By introspecting the form data using AshPhoenix.Form.value,^10 we can
count the tracks and set the params for the new form with the new value:
08/lib/tunez_web/live/albums/form_live.ex
def handle_event( "add-track" , _params,socket) do
socket=
update(socket, :form , fn form->
➤ order= length(AshPhoenix.Form.value(form, :tracks ) || []) + 1
➤ AshPhoenix.Form.add_form(form, :tracks , params: %{ order: order})
end )
{ :noreply , socket}
end

Removing existing rows of track data
Ooops, we pressed the “Add Track” button one too many times! Abort, abort!
https://hexdocs.pm/ash_phoenix/AshPhoenix.Form.html#add_form/3
https://hexdocs.pm/ash_phoenix/AshPhoenix.Form.html#remove_form/3
https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html#inputs_for/1-dynamically-adding-and-removing-
inputs
https://hexdocs.pm/ash_phoenix/nested-forms.html#the-add-checkbox
10.https://hexdocs.pm/ash_phoenix/AshPhoenix.Form.html#value/2
Managing Relationships for Related Resources • 203

We can implement the event handler for removing a track form in a similar
way to adding a track form. The only real difference is we need to know which
track to remove. The button for each row therefore has a phx-value-path attribute
on it to pass the name of the current form to the event handler as the path
parameter:
08/lib/tunez_web/live/albums/form_live.ex

➤ <**.** button_linkphx-click= _"remove-track"_ phx-value-path= _{track_form.name}_ ➤ kind= _"error"_ size= _"xs"_ inverse ➤ > <**.** iconname= _"hero-trash"_ class= _"size-5"_ /> This path will be something like form[tracks][2] if we clicked the delete button for the third track in the list (zero-indexed). That path can be passed directly to AshPhoenix.Form.remove_form to update the form and delete the selected row. **08/lib/tunez_web/live/albums/form_live.ex** ➤ **def** handle_event( _"remove-track"_ , %{ _"path"_ => path},socket) **do** ➤ socket= ➤ update(socket, _:form_ , **fn** form-> ➤ AshPhoenix.Form.remove_form(form,path) ➤ **end** )
{ :noreply , socket}
end
AshPhoenix also supports the checkbox method for deleting forms,^11 as well,
if that’s more your style.
And that’s it for the basic usability of our track forms! AshPhoenix provides
a really nice API for working with forms, making most of what we need to do
in our views straightforward.
What about policies?!
If you spotted that we didn’t write any policies for our new Track resource,
gold star for you! (Gold star even if you didn’t. You’ve earned it for getting this
far!)
Tunez is secure, authorization-wise, as it is right now, but there’s no guarantee
that it will stay thay way. We’re not currently running any actions manually
for Tracks, so they’re inheriting policies from the context they’re called in.
That could change in the future though: we might add a form for managing
11.https://hexdocs.pm/ash_phoenix/nested-forms.html#using-the-_drop_-checkbox
Chapter 8. Fun With Nested Forms • 204

individual tracks, and without specific policies on the Track resource, it would
be wide open.
We can codify a version of our implicit rule of tracks inheriting policies from
their parent album with an accessing_from^12 policy check:
08/lib/tunez/music/track.ex
defmodule Tunez.Music.Track do
use Ash.Resource,
otp_app::tunez ,
domain: Tunez.Music,
data_layer: AshPostgres.DataLayer,
➤ authorizers: [Ash.Policy.Authorizer]

➤ policies do
➤ policyalways() do
➤ authorize_ifaccessing_from(Tunez.Music.Album, :tracks )
➤ end
➤ end

This can be read as “if tracks are being read/created/updated/deleted through
a :tracks relationship on the Tunez.Music.Album resource, then the request is
authorized”. Reading track lists via a load statement to show on the artist
profile? A-OK. Ash will run authorization checks for all of the loaded resources
— the artist, the albums, and the tracks — and if they all pass, the artist
profile will be rendered.
Updating a single album with an included list of track data? Policies will be
checked for both the album and the tracks, and the track policy will always
pass in this scenario.
Fetching an individual track record in iex, via its ID? Nope, it wouldn’t be
allowed by this policy. Hmmm... that doesn’t sound right. We could add
another line to the policy:
08/lib/tunez/music/track.ex
policyalways() do
authorize_ifaccessing_from(Tunez.Music.Album, :tracks )
➤ authorize_ifaction_type( :read )
end
This looks different than the policies we wrote in chapter 6. Those policies
used action_type in the policy condition , not in individual checks, but both ways
will work; a check is a check. This could also have been written as two separate
policies:
policies do

12.https://hexdocs.pm/ash/Ash.Policy.Check.Builtins.html#accessing_from/2
Managing Relationships for Related Resources • 205

policyaccessing_from(Tunez.Music.Album, :tracks ) do
authorize_ifalways()
end
policyaction_type( :read ) do
authorize_ifalways()
end
end
Our initial version is much more succinct, though, and more readable.
Testing these policies is a little trickier than those in our Artist/Album
resources. We don’t have code interfaces for the Track actions, and we have
to test them through the album resource. This is a good candidate for using
seeds to generate test data to clearly separate creating the data from testing
what we can do with it.
There are a few tests in the test/tunez/music/track_test.exs file to cover these new
policies — you’ll also need to uncomment the track() generator function in the
Tunez.Generator module.
Reorder All of the Tracks!!!
Now that we can add tracks to an album, we can display nicely-formatted
track lists for each album on the artist’s profile page. Currently we have a
“track data coming soon” placeholder display coming from the track_details
function component in TunezWeb.Artists.ShowLive. This is because when the
track_details function component is rendered at the bottom of the album_details
function component, the provided tracks is a hardcoded empty list.
08/lib/tunez_web/live/artists/show_live.ex
<. headerclass= "pl-3pr-2!m-0" >
<% # ... %>
</. header>
➤ <. track_detailstracks= {[]} />

We can put the real tracks for the album in there. First, we need to load the tracks when we load album data, up in the handle_params/3 function, in TunezWeb.Artists.ShowLive. We already have :albums as a single item in the list of data to load, so to load tracks for each of the albums, we can turn it into a keyword list: **08/lib/tunez_web/live/artists/show_live.ex defmodule** TunezWeb.Artists.ShowLive **do** _# ..._ **def** handle_params(%{ _"id"_ => artist_id},_url,socket) **do**
Chapter 8. Fun With Nested Forms • 206

artist=
Tunez.Music.get_artist_by_id!(artist_id,
➤ load: [ albums: [ :tracks ]],
actor: socket.assigns.current_user
)
# ...
Because we’ve added a default sort for the tracks relationship, we’ll always get
tracks in the correct order, ordered by order. Then we can replace the hardcoded
empty list in the album_details function component with a reference to the real
tracks, loaded on the @album struct.
08/lib/tunez_web/live/artists/show_live.ex
<. track_detailstracks= {@album.tracks} />
Depending on the kinds of data you’ve been entering while testing, you might
now see something like the following when looking at your test album:

This isn’t great. We don’t have any validations to make sure that the track
numbers entered are a sequential list, with no duplicates, or anything!
But do we really want to write validations for that, to put the onus on the
user to enter the right numbers? It would be better if we could automatically
order them, based on the data in the form. The first track in the list would
be ordered as track 1, the second track will be track 2, etc. That way, there
would be no chance of mistakes.
Automatic track numbering
This automatic numbering can be done with a tweak to our manage_relationship
call, in the create and update actions in the Tunez.Music.Album resource. The
order_is_key option^13 will do what we want: take the position of the record in
the list, and set it as the value of the attribute we specify.
08/lib/tunez/music/album.ex
create :create do
# ...
13.https://hexdocs.pm/ash/Ash.Changeset.html#manage_relationship/4
Reorder All of the Tracks!!! • 207

changemanage_relationship( :tracks , type::direct_control ,
order_is_key::order )
end
update :update do
# ...
changemanage_relationship( :tracks , type::direct_control ,
order_is_key::order )
end
With this change, we don’t really want to let users edit the track order on the
form anymore. As the reordering is only done when submitting the form, it
would be weird to let them set a number only to change it later. For now,
remove the order field from its table cell in the track_inputs function component
in TunezWeb.Albums.FormLive, but leave the empty table cell — we’ll reuse it in a
moment.
08/lib/tunez_web/live/albums/form_live.ex
<. inputs_for:let= {track_form} field= {@form[:tracks]} >

➤ Because there’s no order input anymore, we don’t need the code we wrote to pre-populate numbers when the “Add Track” button is pressed. You can revert the add-track event handler function, and remove setting the order param: **08/lib/tunez_web/live/albums/form_live.ex** update(socket, _:form_ , **fn** form-> ➤ AshPhoenix.Form.add_form(form, _:tracks_ ) **end** ) Now when editing an album, the form will look odd with the missing field, but saving it will set the order attribute on each track to the index of the record in the list. There is one tiny caveat: the list starts from _zero_ , as our automatic database indexing starts from zero. No one counts tracks from zero! We _could_ update our track list display to add one to the order field, but this doesn’t fix the real problem. Any other views of track data, such as in our APIs, would use the zero-offset value, and be off by one. To solve this, we can keep our zero-indexed order field, but we won’t expose it anywhere. Instead, we can separate the concepts of ordering and numbering, and add a calcula- tion for the _number_ to display in the UI.
Ordering, numbering, what’s the difference?
We’re programmers, so we’re used to counting things starting at zero, but
most people aren’t. When we talk about music, or any list of items, we usually
Chapter 8. Fun With Nested Forms • 208

index things starting at one. We even said when we created the order attribute,
that the first track would have order 1, etc... and then we didn’t actually do
that. We’ll fix that.
In our Tunez.Music.Track resource, add a top-level block for calculations, and define
a new calculation:
08/lib/tunez/music/track.ex
defmodule Tunez.Music.Track do
# ...
➤ calculations do
➤ calculate :number , :integer , expr(order+ 1)
➤ end
end
This uses the same expression^14 syntax we’ve seen when writing filters, poli-
cies, and calculations in the past, to add a new number calculation. It’s a
pretty simple one. It increments the order attribute to make it one-indexed.
Now in TunezWeb.Artists.ShowLive, we can load the nested number calculation for
tracks:
08/lib/tunez_web/live/artists/show_live.ex
def handle_params(%{ "id" => artist_id},_url,socket) do
artist=
Tunez.Music.get_artist_by_id!(artist_id,
➤ load: [ albums: [ tracks: [ :number ]]],
actor: socket.assigns.current_user
)
And use the number atribute when rendering track details, in the track_details
function component:
08/lib/tunez_web/live/artists/show_live.ex

➤ {String.pad_leading("#{track.number}",2, "0")}. Perfect! Everything is now in place for the last set of seed data to be imported for Tunez: tracks for all of the seeded albums. You can run the following on the command line: **$ mix run priv/repo/seeds/08-tracks.exs** You can also uncomment the last line of the mix seed alias, in the aliases/0 function in mix.exs:
14.https://hexdocs.pm/ash/expressions.html
Reorder All of the Tracks!!! • 209

08/mix.exs
defp aliases do
[
setup: [ "deps.get" , "ash.setup" , "assets.setup" , "assets.build" , ...],
"ecto.setup" : [ "ecto.create" , "ecto.migrate" ],
➤ seed: [
➤ "run priv/repo/seeds/01-artists.exs" ,
➤ "run priv/repo/seeds/02-albums.exs" ,
➤ "run priv/repo/seeds/08-tracks.exs"
➤ ],
# ...
You can run mix seed at any time to fully reset the sample artist, album, and
track data in your database. Now, each album will have a full set of tracks.
Tunez is looking good!

Drag n’ drop sorting goodness
We have this awesome form: we can add and remove tracks, and everything
works well. Managing the order of the tracks is still an issue, though. What
if we make a mistake in data entry, and forget track 2? We’d have to remove
all the later tracks, and then re-add them after putting track 2 in. It’d be
better if we could drag and drop tracks to reorder the list as necessary.
Okay, so our example is a little bit contrived, reordering track lists isn’t
something that needs to be done often. But reordering lists in general is
something that comes up in apps all the time — in checklists or todo lists,
in your GitHub project board, in your top 5 favorite Zombie Kittens!! albums.
So let’s add it in.
AshPhoenix broadly supports two ways of reordering records in a form —
stepping single items up or down the list or reordering the whole list based
on a new order. Both would work for what we want our form to do, but in our
experience, the latter is a bit more common and definitely more flexible. Select
many things from across multiple lists and move them all to a certain spot
in one list? We can do it.
Integrating a SortableJS hook
Interactive functionality like drag and drop generally means integrating a
JavaScript library. There are quite a few choices out there, such as Drag-
Chapter 8. Fun With Nested Forms • 210

gable,^15 Interact.js,^16 Pragmatic drag and drop,^17 or you can even build your
own using the HTML drag and drop API. We prefer SortableJS.^18
To that end, we’ve already set a Phoenix phx-hook up on the tracks table, in
the track_inputs component in TunezWeb.Albums.FormLive, that has a basic
SortableJS implementation:
08/lib/tunez_web/live/albums/form_live.ex
➤ <tbodyphx-hook= "trackSort" id= "trackSort" >
<. inputs_for:let= {track_form} field= {@form[:tracks]} >

➤ ➤ This SortableJS setup is defined in assets/js/trackSort.js. It takes the element that the hook is defined on, makes its children tr elements draggable, and when a drag takes place, pushes a reorder-tracks event to our liveview with the list of data-ids from the draggable elements. Note that in our form above, we’ve also added an icon where the order number input previously sat, to act as a drag _handle_. This is what you click to drag the rows around and reorder them. With the handle added to the form, you should now be able to drag the rows around by their handles to reorder them. When you drop a row in its new position, your Phoenix server logs will show you that an event was received from the callback defined in the JavaScript hook: [debug]HANDLEEVENT"reorder-tracks"in TunezWeb.Albums.FormLive Parameters:%{"order"=> ["0","1","3","4","5","2","6",...]} [debug]Repliedin 433μs This order is the order we’ve requested that the tracks be ordered in, e.g., in this example, from dragging the third item (index 2) to be placed in the sixth position. We can use AshPhoenix’s sort_forms/3^19 function in that reorder-tracks event handler to reorder the tracks on the form based on the new order.
15.https://shopify.github.io/draggable/
16.https://interactjs.io/
17.https://atlassian.design/components/pragmatic-drag-and-drop/about
18.https://sortablejs.github.io/Sortable/
19.https://hexdocs.pm/ash_phoenix/AshPhoenix.Form.html#sort_forms/3
Reorder All of the Tracks!!! • 211

08/lib/tunez_web/live/albums/form_live.ex
def handle_event( "reorder-tracks" , %{ "order" => order},socket) do
socket= update(socket, :form , fn form->
AshPhoenix.Form.sort_forms(form,[ :tracks ], order)
end )
{ :noreply , socket}
end

Give it a try — drag and drop tracks, save the album, and the changed order
will be saved. The order (and therefore the number) of each track will be recalcu-
lated correctly, and everything is awesome!

Automatic Conversions Between Seconds and Minutes
As we suggested earlier, we don’t really want to show a track duration as a
number of seconds to users — and that’s any users, whether they’re reading
the data on the artist’s profile page or editing track data via a form. Users
should be able to enter durations of tracks as a string like “3:13”, and then
Tunez should convert that to a number of seconds before saving it to the
database.

Calculating the minutes and seconds of a track

We already have a lot of track data in the database stored in seconds, so the
first step would be to be able to convert it to a minutes-and-seconds format
for display.

We’ve seen calculations written inline with expressions, such as when we
added a number calculation for tracks earlier. Like changes, calculations can
also be written using anonymous functions or extracted out to separate cal-
culation modules for reuse. A duration calculation for our Track resource using
an anonymous function is written as follows:

calculations do
# ...
calculate :duration , :string , fn tracks,context->
# Codeto calculatedurationfor eachtrackin the listof tracks
end
end

The main difference here is that a calculation function always receives a list
of records to calculate data for. Even if you’re fetching a record by primary
key and loading a calculation on the result so there will only ever be one
record, the function will still receive a list.

Chapter 8. Fun With Nested Forms • 212

The same behaviour occurs if we define a separate calculation module instead,
a module that uses Ash.Resource.Calculation^20 and implements the calculate/3 call-
back:
08/lib/tunez/music/calculations/seconds_to_minutes.ex
defmodule Tunez.Music.Calculations.SecondsToMinutes do
use Ash.Resource.Calculation
def calculate(tracks,_opts,_context) do
# Codeto calculatedurationfor eachtrackin the listof tracks
end
end
This module can then be used as the calculation implementation in the
Tunez.Music.Track resource:
08/lib/tunez/music/track.ex
calculations do
calculate :number , :integer , expr(order+ 1)
➤ calculate :duration , :string , Tunez.Music.Calculations.SecondsToMinutes
end
The calculate/3 function in the calculation module can iterate over the tracks
and generate nicely-formatted strings representing the number of minutes
and seconds of each track. This function should also always return a list,
where each item of the list is the value of the calculation for the corresponding
record in the input list.
08/lib/tunez/music/calculations/seconds_to_minutes.ex
def calculate(tracks,_opts,_context) do
tracks
|> Enum.map( fn %{ duration_seconds: duration}->
seconds=
rem(duration,60)
|> Integer.to_string()
|> String.pad_leading(2, "0" )
"#{ div(duration,60) }:#{ seconds }"
end )
end
We would always err on the side of using separate modules to write logic in,
instead of anonymous functions. Separate modules allow you to define calcu-
lation dependencies using the load/3 callback, document the functionality
using describe/1, or even add an alternative implementation of the calculation
that can run in the database using expression/2.
An alternative implementation — When would that be useful??

20.https://hexdocs.pm/ash/Ash.Resource.Calculation.html
Automatic Conversions Between Seconds and Minutes • 213

Two implementations for every calculation

The way Ash handles calculations is remarkable. Calculations written using
Ash’s expression syntax can be run either in the database or in code. If we
had a calculation on the Album resource like

calculate :description , :string , expr(name<> " :: " <> year_released)

This could be run in the database using SQL, if the calculation is loaded at
the same time as the data:

iex(1)> Tunez.Music.get_album_by_id!( «uuid» , load: [ :description ])
SELECTa0."id", «the otheralbumfields» , (a0."name"::text|| ($1 ||
a0."year_released"::bigint))::text::textFROM"albums"AS a0 WHERE
(a0."id"::uuid= $3::uuid)ORDERBY a0."year_released"DESC[" :: ",
«uuid» ]
#Tunez.Music.Album<description:"Chronicles :: 2022", ...>

It can also be run in code using Elixir, if the calculation is loaded on an album
already in memory, using Ash.load. By default, Ash will always try to fetch the
value from the database to ensure it’s up to date, but you can force Ash to
use the data in memory and run the calculation in memory using the
reuse_values?:true^21 option:

iex(2)> album= Tunez.Music.get_album_by_id!( «uuid» )
SELECTa0."id",a0."name",a0."cover_image_url",a0."created_by_id",...
#Tunez.Music.Album<description:#Ash.NotLoaded< ...> , ...>
iex(3)> Ash.load!(album, :description , reuse_values?: true)
#Tunez.Music.Album<description:"Chronicles :: 2022", ...>

Why does this matter? Imagine if, instead of doing a quick string manipulation
for our calculation, we were doing something really complicated for every
track on an album, and we were loading a lot of records at once, such as a
band with a huge discography. We’d be running calculations in a big loop
that would be slow and inefficient. The database is generally a much more
optimized place for running logic with its query planning and indexing;
nearly anything that we can push into the database, we should.

Why are we talking about this now? Because writing calculations in Elixir
using calculate/3 is really useful, but it’s not the optimal approach. And our
calculation for converting a number of seconds to minutes-and-seconds can
be written using an expression, instead of using Elixir code. It’s not an
entirely portable expression though, it uses a database fragment to call
PostgreSQL’s to_char^22 number formatting function.

21.https://hexdocs.pm/ash/Ash.html#load/3
22.https://www.postgresql.org/docs/current/functions-formatting.html

Chapter 8. Fun With Nested Forms • 214

To use an expression in a calculation module, instead of defining a calculate/3
function, we can use the expression/2 callback function:

08/lib/tunez/music/calculations/seconds_to_minutes.ex
defmodule Tunez.Music.Calculations.SecondsToMinutes do
use Ash.Resource.Calculation
def expression(_opts,_context) do
expr(
fragment( "? / 60 || to_char(?* interval'1s',':SS')" ,
duration_seconds,duration_seconds)
)
end
end

This takes the duration_seconds column, converts it to a time, and then formats
it. It works pretty well. You can test it in iex by loading a single track and the
duration calculation on it:

iex(7)> Ash.get!(Tunez.Music.Track, «uuid» , load: [ :duration ])
SELECTt0."id",t0."name",t0."duration_seconds",t0."inserted_at",
t0."updated_at",t0."album_id",t0."order", (t0."duration_seconds"::bigint
/ 60 || to_char(t0."duration_seconds"::bigint ***** interval'1s',':SS'))::text
FROM"tracks"AS t0 WHERE(t0."id"::uuid = $1::uuid)LIMIT$2 [ «uuid» , 2]
#Tunez.Music.Track<duration:"5:04",duration_seconds:304, ...>

Calculations like this are a good candidate for testing!
There’s a test in Tunez for this calculation, covering various
durations and verifying the result, in test/tunez/music/calculations/sec-
onds_to_minutes_test.exs. This test proved invaluable, because our own
initial implementation of the expression didn’t properly account
for tracks over one hour long!
This expression is pretty short, and could be dropped back into our
Tunez.Music.Track resource, but keeping it in the module has one distinct benefit
— we can reuse it!

Updating the track list with formatted durations

We can also use our SecondsToMinutes calculation module to generate durations
for entire albums, with the help of an aggregate. Way way back in Relationship
Calculations as Aggregates, on page 82, we learnt how to write aggregates to
perform calculations on relationship data, and Ash provides a sum aggregate
type^23 for, you guessed it, summing up data from related records.

23.https://hexdocs.pm/ash/aggregates.html#aggregate-types

Automatic Conversions Between Seconds and Minutes • 215

So to generate the duration of an album, we can add an aggregate in our
Album resource to add up the duration_seconds of all of its tracks, and then use
the SecondsToMinutes calculation to format it in a nice way. Woo!
08/lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
# ...
aggregates do
sum :duration_seconds , :tracks , :duration_seconds
end
calculations do
calculate :duration , :string , Tunez.Music.Calculations.SecondsToMinutes
end
end
Now that we have nicely-formatted durations for an album and its tracks, we
can update the track list on the artist profile to show them. In
Tunez.Artists.ShowLive, we can load the duration for each album and track:
08/lib/tunez_web/live/artists/show_live.ex
def handle_params(%{ "id" => artist_id},_url,socket) do
artist=
Tunez.Music.get_artist_by_id!(artist_id,
➤ load: [ albums: [ :duration , tracks: [ :number , :duration ]]],
actor: socket.assigns.current_user
)
The album_details function component can be updated to include the duration
of the album:
08/lib/tunez_web/live/artists/show_live.ex
<. headerclass= "pl-3pr-2!m-0" >
<. h2>
{@album.name}({@album.year_released})
➤ <span:if= {@album.duration} class= "text-base" >({@album.duration})
</. h2>
And the track_details function component can be updated to use the duration field
instead of duration_seconds.
08/lib/tunez_web/live/artists/show_live.ex

_<% # ... %>_ ➤ {track.duration} And it looks _awesome_!
Chapter 8. Fun With Nested Forms • 216

There’s only one last thing we need to make better: the Album form, so users
can enter human-readable durations, instead of seconds.
Calculating the seconds of a track
At the moment, the actions in the Tunez.Music.Track resource will accept data
for the duration_seconds attribute, in both the create and update actions, and save
it to the database. Instead of passing in the attribute data directly, we can
pass in the formatted version of the duration as an argument, and then set
up a change module to process that argument. To prevent the change running
when no duration argument is provided, use the only_when_valid? option when
configuring the change.
Again, the update action needs to also be marked with require_atomic?:false because
we’ll be writing non-expression code in our change, that can’t be pushed down
into the database.
08/lib/tunez/music/track.ex
actions do
# ...
create :create do
primary?true
➤ accept[ :order , :name , :album_id ]
➤ argument :duration , :string , allow_nil?: false
➤ changeTunez.Music.Changes.MinutesToSeconds, only_when_valid?: true
end
update :update do
primary?true
➤ accept[ :order , :name ]
➤ require_atomic?false
➤ argument :duration , :string , allow_nil?: false
➤ changeTunez.Music.Changes.MinutesToSeconds, only_when_valid?: true
end
end
After we define our MinutesToSeconds change module, this means that we can
call the actions with a map of data, including duration, and the outside world

Automatic Conversions Between Seconds and Minutes • 217

doesn’t need to know anything about the internal representation or storage
of the data.

Now we need to implement the MinutesToSeconds change module, which should
be in a new file at lib/tunez/music/changes/minutes_to_seconds.ex. Like the UpdatePrevi-
ousNames module we created for artists in Defining a change module, on page
57, this will be a separate module that uses Ash.Resource.Change,^24 and defines
a change/3 action:

08/lib/tunez/music/changes/minutes_to_seconds.ex
defmodule Tunez.Music.Changes.MinutesToSeconds do
use Ash.Resource.Change
def change(changeset,_opts,_context) do
end
end

This change function can have any Elixir code in it, so we can extract the
duration argument from the provided changeset, validate the format, and convert
it to a number:

08/lib/tunez/music/changes/minutes_to_seconds.ex
def change(changeset,_opts,_context) do
{ :ok , duration}= Ash.Changeset.fetch_argument(changeset, :duration )
if String.match?(duration, ~r/^\d+:\d{2}$/ ) do
changeset
|> Ash.Changeset.change_attribute( :duration_seconds , to_seconds(duration))
else
changeset
|> Ash.Changeset.add_error( field::duration , message:"use MM:SSformat" )
end
end

defp to_seconds(duration) do
[minutes,seconds]= String.split(duration, ":" , parts: 2)
String.to_integer(minutes)* 60 + String.to_integer(seconds)
end

You can test this new change out in iex by building a changeset to create a
track. You don’t need to submit it or even make sure it’s valid, but you’ll see
the conversion:

iex(4)> Tunez.Music.Track
Tunez.Music.Track
iex(5)> |> Ash.Changeset.for_create( :create , %{ name:"Test" , duration:"02:12" })
#Ash.Changeset<
attributes:%{name:"Test",duration_seconds:132},
arguments:%{duration:"02:12"},

24.https://hexdocs.pm/ash/Ash.Resource.Change.html

Chapter 8. Fun With Nested Forms • 218

...
Invalid values will report the “use MM:SS format” error, and missing values
will report that the field is required.
The very very last thing left to do is to update our Album form to use the
duration attribute of tracks, instead of duration_seconds. For existing tracks, this
will calculate the formatted value and display it, and then convert it back to
seconds on save. The UI is none the wiser about how the data is stored!
08/lib/tunez_web/live/albums/form_live.ex
def mount(%{ "id" => album_id},_session,socket) do
album= Tunez.Music.get_album_by_id!(album_id,
➤ load: [ :artist , tracks: [ :duration ]])
# ...
08/lib/tunez_web/live/albums/form_live.ex
<. inputs_for:let= {track_form} field= {@form[:tracks]} >

_<% # ... %>_ ➤ Duration ➤ <**.** inputfield= _{track_form[:duration]}_ />
Adding Track Data to API Responses
We can’t forget about our API users; they’d like to be able to see track infor-
mation for albums, too!
To support the Track resource in the APIs, you can use the ash.extend Mix task
to add the extensions and the basic configuration:
$ mix ash.extendTunez.Music.Track json_api
$ mix ash.extendTunez.Music.Track graphql
Because we’ll always be reading or updating tracks in the context of an album,
we don’t need to add any JSON API endpoints or GraphQL queries or muta-
tions for them: the existing album endpoints will be good enough for what we
need.
We do, however, need to mark relationships and attributes as public?:true if we
want them to be readable over the API. This includes the tracks relationship
in the Tunez.Music.Album resource:
08/lib/tunez/music/album.ex
relationships do
# ...
has_many :tracks , Tunez.Music.Track do
Adding Track Data to API Responses • 219

sort order::asc
➤ public?true
end
# ...
And the attributes that we want to show for each track, in the Tunez.Music.Track
resource. This doesn’t have to include our internal order or duration_seconds
attributes!
08/lib/tunez/music/track.ex
attributes do
# ...
attribute :name , :string do
allow_nil?false
➤ public?true
end
# ...
end
calculations do
calculate :number , :integer , expr(order+ 1) do
➤ public?true
end
calculate :duration , :string , Tunez.Music.Calculations.SecondsToMinutes do
➤ public?true
end
end
This is all we need to do for GraphQL. As you only fetch the fields you specify,
consumers of the API can automatically fetch tracks of an album, and can
read all, some, or none of the track attributes if they want to. You may want
to disable automatic filterability and sortability with derive_filter?false and
derive_sort?false in the Track resource, but that’s about it.

Special treatment for the JSON API
Our JSON API needs a little more work, though. To allow tracks to be
included when reading an album, we need to manually configure that with
the includes option in the Tunez.Music.Album resource:
08/lib/tunez/music/album.ex
defmodule Tunez.Music.Album do
# ..
json_api do
type "album"
➤ includes[ :tracks ]
end

Chapter 8. Fun With Nested Forms • 220

This will allow users to add the include=tracks query parameter to their requests
to Album-related endpoints, and the track data will be included. If you want
to allow tracks to be includable when reading artists , e.g., when searching or
fetching an artist by ID, that includes option must be set separately as part of
the Tunez.Music.Artistjson_api configuration.
08/lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
# ...
json_api do
type "artist"
➤ includes albums: [ :tracks ]
derive_filter?false
end
With this config, users can request either albums to be included for an artist
with include=albums in the query string, or albums with tracks with
include=albums.tracks. Neat!
As we learned in What data gets included in API responses?, on page 94, by
default only public attributes will be fetched and returned via the JSON API.
This isn’t great for tracks, because only the name is a public attribute — duration
and number are both calculations! For tracks, it would make more sense to
configure the default_fields^25 that are always returned for every response, this
way we can include the attributes and calculations we want.
08/lib/tunez/music/track.ex
json_api do
type "track"
➤ default_fields[ :number , :name , :duration ]
end
Now our API users also have a good experience! They can access and manage
track data for albums, just like web UI users can.
We covered a lot in this chapter, and there are so many little fiddly things
about forms to make them just right. It’ll take practice getting used to, espe-
cially if you want to build forms with different UIs such as adding/removing
tags, but the principles will stay the same.
In our next and final chapter, we’ll tie everything together that we’ve done so
far and build one major new end-to-end feature. We’ll consider how to manage
relationships a bit differently so that a user can follow their favorite artists.

25.https://hexdocs.pm/ash_json_api/dsl-ashjsonapi-resource.html#json_api-default_fields
Adding Track Data to API Responses • 221

We’ll also build a notification system so that users can find out when new
albums are added for their favorite artists. We’ll see you there!

Chapter 8. Fun With Nested Forms • 222

CHAPTER 9
