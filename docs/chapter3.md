Creating a Better Search UI

In the previous chapter, we learned how we can link resources together with
relationships, and use validations, preparations and changes to implement
business logic within resource actions. With this new knowledge, we could
build out a fairly comprehensive data model if we wished. We could make
resources for everything from tracks on albums, band members, record labels,
anything we wanted, and also make a reasonable CRUD interface for it all.
We’ve covered a lot!

But we’re definitely missing some business logic, and UI polish. If we had a
whole lot of artists in the app, it would become difficult to use. The artist
catalog is just one big list of cards — there’s no way to search or sort data,
and we definitely don’t need the whole list at all times. Let’s look at making
this catalog a lot more user-friendly, using query filtering, sorting, and pagi-
nation.

Custom Actions with Arguments
To improve discoverability, we can add search to the Artist catalog, to allow
users to look up artists by name.

What might it ideally look like, if we were designing the interface for this
function? It’d be great to be able to call it like:

iex> Tunez.Music.search_artists( "fur" )
{:ok,[%Tunez.Music.Artist{name:"Valkyrie'sFury"},...]}

Can we do it? Yes we can!

Designing a search action

A search action will be reading existing data from the database, so we can
add a new read action to the Artist resource to perform this new search.

03/lib/tunez/music/artist.ex
actions do
# ...
➤ read :search do
➤ end
end
When we covered read actions in Defining a read action, on page 16, we
mentioned that Ash will read data from the data layer based on parameters
we provide, which can be done as part of the action definition. Our search
action will support one such parameter for now, the text to match names on,
via an argument to the action.
03/lib/tunez/music/artist.ex
actions do
# ...
read :search do
➤ argument :query , :ci_string do
➤ constraints allow_empty?: true
➤ default ""
➤ end
end
end
Arguments can be anything from scalar values like integers or booleans, to
structured maps, to resource structs. In our case, we’ll be accepting a case-
insensitive string (or ci_string ), to allow for case-insensitive searching. This
argument can then be used in a filter , to add conditions to the query, limiting
the records returned to only those that match the condition.
03/lib/tunez/music/artist.ex
actions do
# ...
read :search do
argument :query , :ci_string do
# ...
end

➤ filterexpr(contains(name,^arg( :query )))
end
end
Whoa! There’s a lot of new stuff in single line of code. Let’s break it down a
bit.

Chapter 3. Creating a Better Search UI • 62

Filters with expressions

Filters are the where-clauses of our queries, allowing us to only fetch the
records that match our query. They use a special SQL-like syntax, inspired
by Ecto, but are much more expressive.

In iex you can test out different filters by running some queries inline. You’ll
need to run require Ash.Query first:

iex(1)>require Ash.Query
Ash.Query
iex(2)> Ash.Query.filter(Tunez.Music.Album,year_released== 2024)
#Ash.Query<resource:Tunez.Music.Album,
filter:#Ash.Filter<year_released== 2024>>
iex(3)> |> Ash.read()
[debug]QUERYOK source="albums"db=0.8msqueue=0.8msidle=1138.7ms
SELECTa0."id",a0."name",a0."year_released",a0."cover_image_url",
a0."inserted_at",a0."updated_at",a0."artist_id"FROM"albums"AS a0
WHERE(a0."year_released"::bigint= $1::bigint)ORDERBY
a0."year_released"DESC[2024]
{:ok,[%Tunez.Music.Album{year_released:2024,...},...]}

Filters aren’t just limited to equality checking — they can use any of the
expression syntax^1 including operators and functions. All of the expression
syntax listed is data-layer-agnostic, and because we’re using AshPostgres, is
converted into SQL when we run the query.

Unlike running a filter with Ash.Query.filter, whenever we refer to expressions
elsewhere, we need to wrap the body of the filter in a call to expr. The reasons
for this are historical — the Ash.Query.filter function predates other usages of
expressions, so this will likely be changed in a future version of Ash for con-
sistency — so it’s something to keep in mind.

Inside our filter, we can use the contains/2 expression function, which is a
substring checker. It checks to see if the first argument, in our case a reference
to the name attribute of our resource, contains the second argument, which
is a reference to the query argument to the action!

If we were using a similar filter in pure Elixir, to filter a list of structs by a
case-insensitive string search, it might look like:

def search(query)
query= String.downcase(query)
load_all_artists()
|> Enum.filter( fn %{ name: name}->
name

https://hexdocs.pm/ash/expressions.html
Custom Actions with Arguments • 63

|> String.downcase()
|> String.contains?(query)
end )
end

search( "test" )

But because we’re using AshPostgres, it will be converted to use the ilike^2
function in PostgreSQL.

iex(4)> Tunez.Music.Artist
Tunez.Music.Artist
iex(5)> |> Ash.Query.for_read( :search , %{ query:"co" })
#Ash.Query<
resource:Tunez.Music.Artist,
arguments:%{query:#Ash.CiString<"co">},
filter:#Ash.Filter<contains(name,#Ash.CiString<"co">)>

iex(6)> |> Ash.read()
SELECTa0."id",a0."name",a0."biography",a0."inserted_at",
a0."previous_names",a0."updated_at"FROM"artists"AS a0 WHERE
(a0."name"::textILIKE$1) ["%co%"]
{:ok,[#Tunez.Music.Artist<name:"CrystalCove", ...> , ...]}

Which does exactly what we want — a case-insensitive substring match on
the column contents, based on the string we provide.

Speeding things up with custom database indexes

Using an ilike query naively over a massive data set isn’t exactly performant
— it’ll run a sequential scan over every record in the table. As more and more
artists get added, the search would get slower and slower. To make this query
more efficient, we can add a custom database index called a GIN index^3 on
the name column.

AshPostgres supports the creation of custom indexes^4 like a GIN index. To
create a GIN index specifically, we first need to enable the PostgreSQL pg_trgm
extension.^5 AshPostgres handles enabling and disabling PostgreSQL exten-
sions, via the installed_extensions^6 function in the Tunez.Repo module. By default
it only includes ash-functions, so we can add pg_trgm to this list:

03/lib/tunez/repo.ex
defmodule Tunez.Repo do

https://www.postgresql.org/docs/current/functions-matching.html#FUNCTIONS-LIKE
https://pganalyze.com/blog/gin-index#indexing-like-searches-with-trigrams-and-gin_trgm_ops
https://hexdocs.pm/ash_postgres/dsl-ashpostgres-datalayer.html#postgres-custom_indexes
https://www.postgresql.org/docs/current/pgtrgm.html
https://hexdocs.pm/ash_postgres/AshPostgres.Repo.html#module-installed-extensions
Chapter 3. Creating a Better Search UI • 64

use AshPostgres.Repo, otp_app::tunez
def installed_extensions do
# Add extensionshere,and the migrationgeneratorwillinstallthem.
➤ [ "ash-functions" , "pg_trgm" ]
end
Then we can add the index to the postgres block of our Artist resource:
03/lib/tunez/music/artist.ex
postgres do
table "artists"
repoTunez.Repo
custom_indexes do
index "namegin_trgm_ops" , name:"artists_name_gin_index" , using:"GIN"
end
end
Generally, AshPostgres will be able to generate the names of indexes by itself
from the fields, but because we’re creating a custom index we have to specify
a valid name.
Lastly, generate and run the migration to update the database with the new
extension and index.
$ mix ash.codegenadd_gin_index_for_artist_name_search
$ mix ash.migrate
What kind of performance benefits do we actually get for this? We ran some
tests, by inserting a million records with various names into our Artists table
using the faker library. Without the index, searching for a word like “snow”
(which returns 3,041 results in our data set) takes about 150ms. The following
output is from running EXPLAIN ANALYZE^7 on the generated SQL query, in Post-
greSQL:
Gather (cost=1000.00..23725.43rows=10101width=131)(actual
time=0.633..150.672rows=3041loops=1)
WorkersPlanned: 2
WorkersLaunched: 2
-> ParallelSeq Scanon artistsa0 (cost=0.00..21715.33rows=4209
width=131)(actualtime=0.570..136.405rows=1014loops=3)
Filter:(name~~* '%snow%'::text)
RowsRemovedby Filter: 332320
PlanningTime:0.351ms
ExecutionTime:150.789ms
After adding the index and re-running the query with EXPLAINANALYZE, however,
the numbers look a lot different:

https://www.postgresql.org/docs/current/using-explain.html#USING-EXPLAIN
Custom Actions with Arguments • 65

BitmapHeapScanon artistsa0 (cost=118.28..15299.90rows=10101
width=131)(actualtime=1.571..13.443rows=3041loops=1)
RecheckCond:(name* '%snow%'::text)
HeapBlocks:exact=2759
-> BitmapIndexScanon artists_name_idx (cost=0.00..115.76rows=10101
width=0)(actualtime=1.104..1.105 rows=3041loops=1)
IndexCond:(name* '%snow%'::text)
PlanningTime:0.397ms
ExecutionTime:14.691ms

That’s a huge saving, the query now only takes about 10% of the time! It
might not seem like such a big deal when we’re talking about milliseconds,
but for every artist query being run, it all adds up. Faster responses lead to
happier users and less server load. Everybody wins!

Integrating search into the UI

Now that we have the first version of our search action built, we can make the
tidy interface we imagined and integrate it into the Artist catalog.

A code interface with arguments

We previously imagined a search function API like:

iex> Tunez.Music.search_artists( "fur" )
{:ok,[%Tunez.Music.Artist{name:"Valkyrie'sFury"},...]}

We can create a new code interface in our domain for this, one that supports
passing arguments to the action.

03/lib/tunez/music.ex
resourceTunez.Music.Artist do
# ...
define :search_artists , action::search , args: [ :query ]
end

Defining a list of arguments with names that match the arguments defined
in our function makes that link that we’re after — the first parameter passed
when calling the Tunez.Music.search_artists function will now be assigned to the
query argument in the action.

You can verify that this link has been made by checking out the function
signature in iex:

iex(1)> h Tunez.Music.search_artists

def search_artists(query,params_or_opts\\ %{},opts\\ [])
Callsthe searchactionon Tunez.Music.Artist.

Chapter 3. Creating a Better Search UI • 66

Any action arguments not listed in the args list on the code interface will be
placed into the next argument, the map of params. If we didn’t specify args:
[:query], we would need to call the search function like this:
Tunez.Music.search_artists(%{ query:"fur" })
Which works, but isn’t anywhere near as nice!
Searching from the catalog
In the Artist catalog, searches should be repeatable and sharable, and we’ll
achieve this by making the searched-for text part of the query string, in the
page URL. If a user visits a URL like http://localhost:4000/?q=test, Tunez should
run a search for the string “test” and show only the matching results.
We currently read the list of artists to display in the handle_params/3 function
definition, in Tunez.Artists.IndexLive:
03/lib/tunez_web/live/artists/index_live.ex
def handle_params(_params,_url,socket) do
artists= Tunez.Music.read_artists!()
socket=
socket
|> assign( :artists , artists)
# ...
If the params to the page (from the page route/query string) contain a q value,
we can read it out and call our new search_artists function instead:
03/lib/tunez_web/live/artists/index_live.ex
def handle_params(params,_url,socket) do
query_text= Map.get(params, "q" , "" )
artists= Tunez.Music.search_artists!(query_text)
socket=
socket
|> assign( :query_text , query_text)
|> assign( :artists , artists)
# ...
Of course, users don’t search by editing the URL — they search by typing
text in a search box. We can add another action slot to the .header component
in the render/3 function of IndexLive, to render a search box function component.
03/lib/tunez_web/live/artists/index_live.ex
<. headerresponsive= {false} >
<. h1>Artists</. h1>
➤ <:action>
➤ <. search_boxquery= {@query_text} method= "get"
➤ data-role= "artist-search" phx-submit= "search" />

Custom Actions with Arguments • 67

➤ </:action>
<:action>
<. button_link
# ...
When a user types something in the box and presses Enter to submit, the
“search” event will be sent to the liveview. The logic for this has already been
implemented:
03/lib/tunez_web/live/artists/index_live.ex
def handle_event( "search" , %{ "query" => query},socket) do
params= remove_empty(%{ q: query})
{ :noreply , push_patch(socket, to: ~ p "/?#{ params }" )}
end
The event handler takes the entered text and patches the liveview — updating
the URL with the new query string and calling handle_params/3 with the new
params, which then re-runs the search and will re-render the catalog.

That’s really neat! There’s another big thing we can add, to make the artist
catalog more awesome — the ability to sort the artists on the page. We’ll start
with some basic sorts, like sorting them alphabetically or by most recently
updated, and then later in the chapter we’ll look at some really amazing ones.
Dynamically Sorting Artists
Our searching functionality is fairly limited — Tunez doesn’t have a concept
of “best match” when searching text, artists either match or they don’t. To
help users potentially surface what they want to see more easily, we’ll let
them sort their search results. Maybe they want to see most recently added
artists listed first? Maybe they want to see artists that have released the most
albums listed first? (oops that’s a bit of a spoiler!) Let’s dig in.
Chapter 3. Creating a Better Search UI • 68

Letting users set a sort method
We’ll start from the UI layer — how can users select a sort method? Usually
it’s by a dropdown of sort options at the top of the page, so we’ll drop one
next to the search box. In Tunez.Artists.IndexLive, we can add another action to
the actions list in the header function component:
03/lib/tunez_web/live/artists/index_live.ex
<. headerresponsive= {false} >
<. h1>Artists</. h1>
➤ <:action><. sort_changerselected= {@sort_by} /></:action>
<:action>

...
The @sort_by assign doesn’t yet exist, but it will store a string defining what
kind of sort we want to perform. We can add this to the list of assigns, in
handle_params/3:
03/lib/tunez_web/live/artists/index_live.ex
def handle_params(params,_url,socket) do
➤ sort_by= nil
# ...
socket=
socket
➤ |> assign( :sort_by , sort_by)
|> assign( :query_text , query_text)
# ...
The actual sort_changer function component has already been defined further
down in the liveview — it reads a set of option tuples for the sort methods
we’ll support, with internal and display representations, and embeds them
into a form, with a phx-change event handler.
03/lib/tunez_web/live/artists/index_live.ex
defp sort_options do
[
{ "recentlyupdated" , "updated_at" },
{ "recentlyadded" , "inserted_at" },
{ "name" , "name" }
]
end
When the user selects a sort option, the “change-sort” event will be sent to
the liveview. The handle_event/3 function head for this event looks pretty similar
to the function head for the “search” event, right below it, except we now have
an extra sort_by parameter in the query string. Let’s add sort_by to the params
list in “search” event handler as well, by reading it from the socket assigns.

Dynamically Sorting Artists • 69

This will let users search then sort, or sort then search, and the result will
be the same because both parameters will always be part of the URL.
03/lib/tunez_web/live/artists/index_live.ex
def handle_event( "change-sort" , %{ "sort_by" => sort_by},socket) do
params= remove_empty(%{ q: socket.assigns.query_text, sort_by: sort_by})
{ :noreply , push_patch(socket, to: ~ p "/?#{ params }" )}
end
def handle_event( "search" , %{ "query" => query},socket) do
➤ params= remove_empty(%{ q: query, sort_by: socket.assigns.sort_by})
{ :noreply , push_patch(socket, to: ~ p "/?#{ params }" )}
end
Test it out in your browser — now changing the sort dropdown should navigate
to a URL with the sort method in the query string, like http://localhost:4000/
?q=the&sort_by=name.
Now that we have the sort method in the query string, we can read it when
the page loads just like we read pagination parameters, in handle_params/3. We’ll
do some validation to make sure that it’s a valid option from the list of options,
and then store it in the socket like before.
03/lib/tunez_web/live/artists/index_live.ex
def handle_params(params,_url,socket) do
➤ sort_by= Map.get(params, "sort_by" ) |> validate_sort_by()
# ...
socket=
# ...
That’s the full loop of what we need to implement from a UI perspective — we
have a default sort method defined, the user can change the selected value,
that value gets reflected back to them in the URL and on the page. Now we
can look at how to use that value, to change the way the data is returned
when our user runs a search.

The base query for a read action
When we run any read action on a resource, we always have to start from
some base, onto which we can build a query and start layering extras like
filters, loads and so on. We’ve seen examples of this throughout the book, all
the way back to our very first example of how to run a read action:
➤ iex(2)> Tunez.Music.Artist
➤ Tunez.Music.Artist
➤ iex(3)> |> Ash.Query.for_read( :read )
➤ #Ash.Queryresource:Tunez.Music.Artist
iex(4)> |> Ash.Query.sort( name::asc )
#Ash.Queryresource:Tunez.Music.Artist,sort:[name::asc]

Chapter 3. Creating a Better Search UI • 70

iex(5)> |> Ash.Query.limit(1)
#Ash.Queryresource:Tunez.Music.Artist,sort:[name::asc],limit:1
iex(6)> |> Ash.read()
[debug]QUERYOK source="artists"db=3.4msqueue=1.2msidle=1863.7ms
SELECTa0."id",a0."name",a0."biography",a0."inserted_at",a0."updated_at"
FROM"artists"AS a0 ORDERBY a0."name"LIMIT$1 [1]
{:ok,[#Tunez.Music.Artist< ...> ]}

The core thing needed to create a query for a read action is knowing which
resource needs to be read. By default this is what Ash does when we call a
read action, or a code interface that points to a read action — it uses the
resource module itself as the base and builds the query from there.

We can change this though. We can pass in our own hand-rolled query when
calling a code interface for a read action, or pass a list of options to be used
with the resource module when constructing the base query, and these will
be used instead.

We mentioned earlier in Loading Related Resource Data, on page 44 that
every action can take an optional set of arguments, but it’s worth reiterating.
These don’t have to be defined as arguments to the action, they’re added at
the end, and they can radically change the behaviour of the action. For code
interfaces for read actions, this list of options^8 includes the query option, and
that’s what we’ll use to provide a query in the form of a keyword list.

The query keyword list can include any of the opts that Ash.Query.build/3^9 supports,
and in our case we’re interested in setting a sort order, so we’ll pick sort_input.

Using sort_input for succinct yet expressive sorting

A few of you are probably already wondering, sort_input, when sort is right there?
What’s the difference? Both could be used for our purposes, but one is much
more useful than the other when sorts come from query string input.

sort is the traditional way of specifying a sort order with field names and sort
directions, eg. to order records alphabetically by name, A to Z, you would
specify [name::asc]. To order alphabetically by name and then by newest created
record first (to consistently sort artists that have the same name), you would
specify [name::asc,inserted_at::desc]. Which is fine, this works, you can test it out
with iex and our Tunez.Music.search_artists code interface function:

iex(6)> Tunez.Music.search_artists( "the" , [ query: [ sort: [ name::asc ]]])
{:ok,
%Ash.Page.Offset{

https://hexdocs.pm/ash/code-interfaces.html#using-the-code-interface
https://hexdocs.pm/ash/Ash.Query.html#build/3
Dynamically Sorting Artists • 71

results:[
#Tunez.Music.Artist<name:"Nightsin the Nullarbor", ...> ,
#Tunez.Music.Artist<name:"TheLostKeys", ...>
],
...
}}
sort_input is a bit different — instead of a list, we can specify a single comma-
separated string of fields to sort on. Sorting is ascending by default, but can
be inverted by prefixing a field name with a -. So our example from before,
sorting alphabetically by name and then newest first would be name,-inserted_at.
Heaps better!
To use sort_input, we do need to make one change to our resource though —
as it’s intended to let users specify their own sort methods, it will only permit
sorting on public attributes. We don’t want users trying to hack our app in
any way, after all. All attributes are private by default, for the highest level of
security, so we’ll have to explicitly mark those we want to be publicly accessi-
ble. This can be done by adding public?true as an option on each of the
attributes we want to be sortable:
03/lib/tunez/music/artist.ex
attributes do
# ...
attribute :name , :string do
allow_nil?false
➤ public?true
end
# ...
➤ create_timestamp :inserted_at , public?: true
➤ update_timestamp :updated_at , public?: true
end
Once the attributes are marked public, then sort_input will be usable the way
we want:
iex(6)> Tunez.Music.search_artists( "the" , [ query: [ sort_input:"-name" ]])
{:ok,%Ash.Page.Offset{results:[...],...}
Because we’ve condensed sorting down to specifying a single string value at
runtime, it’s perfect for adding as an option when we run our search, in the
handle_params/3 function in TunezWeb.Artists.IndexLive:
03/lib/tunez_web/live/artists/index_live.ex
def handle_params(params,_url,socket) do
# ...
➤ artists= Tunez.Music.search_artists!(query_text, query: [ sort_input: sort_by])

Chapter 3. Creating a Better Search UI • 72

# ...
It’s actually more powerful than our UI needs — it supports sorting on multiple
columns, when we only have a single dropdown for one field, but that’s okay.
There’s just one little tweak to make in our sort_options function — when we
want recently added or updated records to be shown first, they should be
sorted descending , so prefix those two field names with a -.
03/lib/tunez_web/live/artists/index_live.ex
defp sort_options do
[
➤ { "recentlyupdated" , "-updated_at" },
➤ { "recentlyadded" , "-inserted_at" },
{ "name" , "name" }
]
end
We can now search and sort, or sort and search, and everything works just
as expected. There’s still too much data to display on the page, though. Even
if searching through All Of The Artists That Ever Was returns only a few
hundred or thousand results, that would take too long to render. We’ll split
up the results with pagination, and let users browse artists at their own pace.

Pagination of Search Results
Pagination is the best way of limiting the amount of data on an initial page
load, to the most important things a user would want to see. If they want
more data (more search results, more tweets/posts, more artists), they can
request more data, either by scrolling to the bottom of the page and having
more data load automatically (usually called infinite scroll ), or by clicking a
button to load more.
We’ll implement the more traditional method of having distinct pages of
results, and letting users go backwards/forwards between pages via buttons
at the bottom of the catalog.
Adding pagination support to the search action
Our first step in implementing pagination is to update our search action to
support it. Ash supports automatic pagination of read actions^10 using the
pagination^11 macro, so we’ll add that to our action definition.
03/lib/tunez/music/artist.ex
read :search do
10.https://hexdocs.pm/ash/read-actions.html#pagination
11.https://hexdocs.pm/ash/dsl-ash-resource.html#actions-read-pagination
Pagination of Search Results • 73

# ...
➤ pagination offset?: true, default_limit: 12
end
We’ve elected to use offset pagination (eg. “show the next 20 records after the
40th record”) over keyset pagination (eg. “show the next 20 records after record
ID=12345”). It’s easier to understand, and well-suited for when the data isn’t
frequently being updated. When the data is frequently being updated, such
as for news feeds or timelines, or you want to implement infinite scrolling,
then keyset pagination would be the better choice.
Adding the pagination macro immediately changes the return type of the search
action. You can see this if you run a sample search in iex:
iex(1)> Tunez.Music.search_artists!( "cove" )
«databasequery»
%Ash.Page.Offset{
results:[#Tunez.Music.Artist<name: "CrystalCove", ...> ],
limit:12,
offset:0,
count:nil,
rerun:{#Ash.Query< ...> , [ «opts» ]},
more?:false
}
The list of artists resulting from running the text search is now wrapped up
in an Ash.Page.Offset struct, which contains extra pagination-related information
— how many results there are in total, whether there are more results to
display, and information about how this same query can be re-run if neces-
sary. If we were using keyset pagination, you’d get back an Ash.Page.Keyset struct
instead, but the data within would be similar.
This means we’ll need to update the liveview as well, to support the new data
structure.

Showing paginated data in the catalog
In TunezWeb.Artists.IndexLive, we load a list of artists and assign them directly to
the socket, for the template to iterate over:
03/lib/tunez_web/live/artists/index_live.ex
def handle_params(params,_url,socket) do
# ...
artists= Tunez.Music.search_artists!(query_text, query: [ sort_input: sort_by])
socket=
socket
|> assign( :query_text , query_text)
|> assign( :artists , artists)
Chapter 3. Creating a Better Search UI • 74

# ...
Now calling search_artists! will return a Page struct, so rename the variable and
socket assign to better reflect what is being stored.
03/lib/tunez_web/live/artists/index_live.ex
def handle_params(params,_url,socket) do
# ...
page= Tunez.Music.search_artists!(query_text, query: [ sort_input: sort_by])
socket=
socket
|> assign( :query_text , query_text)
➤ |> assign( :page , page)
# ...
We also need to update the template code, to use the new @page assign and
iterate through the page results.
03/lib/tunez_web/live/artists/index_live.ex
➤ <div:if= {@page.results == []} class= "p-8text-center" >
<. iconname= "hero-face-frown" class= "w-32h-32bg-gray-300" />

No artistdatato display!

➤
<**.** artist_cardartist= _{artist}_ />
This works — now we only have one page worth of artists showing in the catalog, but no way of navigating to other pages. We can add some dummy pagination links to the bottom of the artist catalog template, with the pagination_links function component. As pagination info will also be kept in the URL for easy sharing/reloading, the component will use the query text, the current sort and the page to construct URLs to link to, for changing pages. **03/lib/tunez_web/live/artists/index_live.ex def** render(assigns) **~** H _""" <% # ... %> <.pagination_linkspage={@page}query_text={@query_text}sort_by={@sort_by}/> """_ **end** To make the pagination links functional, we’ll look at another of AshPhoenix’s modules — AshPhoenix.LiveView.^12 It contains a handful of really useful helper 12.https://hexdocs.pm/ash_phoenix/AshPhoenix.LiveView.html
Pagination of Search Results • 75

functions for inspecting a Page struct to see if there’s a previous page, next
page, what the current page is, and so on. We can use these to add links to
for the next/previous pages in the pagination_links function component, condi-
tionally disabling them if there is no valid page to link to.
03/lib/tunez_web/live/artists/index_live.ex
<div
➤ :if= {AshPhoenix.LiveView.prev_page?(@page) ||
➤ AshPhoenix.LiveView.next_page?(@page)}
class= "flexjustify-centerpt-8space-x-4"

<.button_linkdata-role= "previous-page" kind= "primary" inverse
➤ patch={ ~ p "/?#{ query_string(@page, @query_text, @sort_by, "prev" ) }" }
➤ disabled={! AshPhoenix.LiveView.prev_page?(@page)}

« Previous
</.button_link>
<.button_linkdata-role= "next-page" kind= "primary" inverse
➤ patch={ ~ p "/?#{ query_string(@page, @query_text, @sort_by, "next" ) }" }
➤ disabled={! AshPhoenix.LiveView.next_page?(@page)}

Next »
</.button_link>

The query_string helper function doesn’t yet exist, but we can quickly write it. It will take some pagination info from the @page struct, and use it to generate a keyword list of data to put in the query string: **03/lib/tunez_web/live/artists/index_live.ex def** query_string(page,query_text, sort_by,which) **do case** AshPhoenix.LiveView.page_link_params(page,which) **do** _:invalid_ -> [] list-> list **end** |> Keyword.put( _:q_ , query_text) |> Keyword.put( _:sort_by_ , sort_by) |> remove_empty() **end** We’re using offset pagination, so when you call AshPhoenix.LiveView.page_link_params/2 it will generate limit and offset parameters. **iex(1)>** page= Tunez.Music.search_artists!( _"a"_ ) %Ash.Page.Offset{results:[#Tunez.Music.Artist< **...>** , ...],...} **iex(2)>** TunezWeb.Artists.IndexLive.query_string(page, _"a"_ , _"name"_ , _"prev"_ ) [sort_by:"name",q: "a"] **iex(3)>** TunezWeb.Artists.IndexLive.query_string(page, _"a"_ , _"-inserted_at"_ , _"next"_ ) [sort_by:"-inserted_at",q: "a",limit:12, offset:12]
Chapter 3. Creating a Better Search UI • 76

When interpolated by Phoenix into a URL on the “Next” button link, it will
become http://localhost:4000/?q=a&sort_by=name&limit=12&offset=12.
The last step in the process is to use these limit/offset parameters, to make
sure we load the right page of data. At the moment even if we click “Next”,
the URL changes but we still only see the first page of artists. To do that, we’ll
use another one of the helpers from AshPhoenix.LiveView, to parse the right data
out of the params before we load artist data in handle_params/3.
03/lib/tunez_web/live/artists/index_live.ex
def handle_params(params,_url,socket) do
# ...
➤ page_params= AshPhoenix.LiveView.page_from_params(params,12)

page=
Tunez.Music.search_artists!(query_text,
➤ page: page_params,
query: [ sort_input: sort_by]
)
We could pluck out the limit and offset values from params ourselves, but by
doing it this way, if we wanted to change the pagination type — from offset
to keyset, or vice versa — we wouldn’t have to touch this view code at all.
We’d only have to change one line of code, the pagination definition in the search
action, and everything else would still work. If you really want to be wild, you
can even support both types of pagination in the action — URLs that include
params for either type will work. Nifty!
And that’s it! We’ve now got full sorting, searching, and pagination for our
artist catalog. It was a lot to go through and understand, but not actually a
lot of code. Concerns that belong entirely to our UI, like sorting, stayed in the
UI layer of the app. Features that are more in-depth, like text searching, came
into the resource layer to be analyzed and optimized.
Looking for even more dynamicness?
If you’re imagining the majesty of a full “advanced search”-type
form, where users can add their own boolean predicates and
really narrow down what they’re looking for, Ash has support for
that by way of AshPhoenix.FilterForm.^13 Implementing one is a little out

13.https://hexdocs.pm/ash_phoenix/AshPhoenix.FilterForm.html
Pagination of Search Results • 77

Looking for even more dynamicness?
of the scope of this book, but the documentation and an example
app^14 should be able to get you started!
Now we’d love to talk about a really killer data modelling feature that Ash
provides — calculations!
No DB field? No Problems, with Calculations
Calculations^15 are an awesome way of defining a special type of attribute that
isn’t stored in your database, but is calculated on-demand from other infor-
mation. What types of other information can you use? Well, anything really!
You can use data from related resources, data from files on the filesystem,
from external sources, or even just some way of tweaking, deriving or refor-
matting data you already store for that resource.
Calculations have to be specifically loaded when reading data, the same way
you load a relationship; but once they’re loaded, they can be treated like any
other attribute of a resource.
Calculating data with style
Let’s say we wanted to display how many years ago each album was released,
on an artist’s profile page. That’ll make all Tunez’s users feel really old! (We
won’t actually do this, because it’s a terrible idea, but for demonstration
purposes.)
Like a lot of the functionality we’ve seen before, we can add calculations to a
resource by defining a top-level calculations block in the resource.
defmodule Tunez.Music.Album do
# ...
➤ calculations do
➤ end
end
Inside the calculations block, we can use the calculate^16 macro to define individual
calculations. A calculation needs three things — a name for the resulting
attribute, the type of the resulting attribute, and some method of generating
the value to store in the attribute.
calculations do

14.https://github.com/totaltrash/filter_form_example
15.https://hexdocs.pm/ash/calculations.html
16.https://hexdocs.pm/ash/dsl-ash-resource.html#calculations-calculate
Chapter 3. Creating a Better Search UI • 78

➤ calculate :years_ago , :integer , expr(2025 - year_released)
end
Calculations use the expression syntax^17 that we saw earlier with filters, to
make for really terse code. These are SQL-ish, so we can’t use arbitrary Elixir
functions in them (hence we’re hardcoding 2025 for the year), but we can
write some very complex conditions. If we wanted to use some logic that can’t
be written as an expression, such as dynamically using the current year, or
converting a string of minutes and seconds to a number of seconds, we could
define a separate calculation module. We’ll see this exact example later in
Automatic Conversions Between Seconds and Minutes, on page 212!
Once you’ve added a calculation, you can test it out in iex by loading the cal-
culation as part of the data for an album. We’ve seen load: [:albums] when
loading artist data before, and to load nested data, each item in the load list
can be a keyword list of nested things to load.
iex(1)> Tunez.Music.get_artist_by_id( «uuid» , load: [ albums: [ :years_ago ]])
{:ok,#Tunez.Music.Artist<
albums:[
#Tunez.Music.Album<year_released:2022,years_ago:3, ...> ,
#Tunez.Music.Album<year_released:2012,years_ago:13, ...>
],
...

}
You could then use this years_ago attribute when rendering a view, or in an
API response, like any other attribute. And because they are just like any
other attribute, you can even use them within other calculations:
calculations do
calculate :years_ago , :integer , expr(2025 - year_released)
➤ calculate :string_years_ago ,
➤ :string ,
➤ expr( "wow,thiswas released" <> years_ago<> " yearsago!" )
end
If you load the string_years_ago calculation, you don’t need to specify that it
depends on another calculation so that should be loaded too — Ash can work
that out for you.
iex(1)> Tunez.Music.get_artist_by_id( «uuid» , load: [ albums: [ :string_years_ago ]])
{:ok,#Tunez.Music.Artist<
albums:[
#Tunez.Music.Album<
year_released:2022,

17.https://hexdocs.pm/ash/expressions.html
No DB field? No Problems, with Calculations • 79

string_years_ago:"wow,thiswas released3 yearsago!",
years_ago:#Ash.NotLoaded<:calculation,field::years_ago>,
...

,
#Tunez.Music.Album<
year_released:2012,
string_years_ago:"wow,thiswas released13 yearsago!",
years_ago:#Ash.NotLoaded<:calculation,field::years_ago>,
...

],
...

}

You only get back what you request!
One important thing to note here is that Ash will only return the
calculations you requested, even if some extra calculations are
evaluated as a side-effect.
In the above example, Ash will calculate the years_ago field for each
artist record, because it’s needed to calculate string_years_ago — but
years_ago will not be returned as part of the Artist data.
This is to avoid accidentally relying on these implicit side-effects.
If we changed how string_years_ago is calculated, to not use years_ago,
it would break any usage of years_ago in our views. This can lead
to hard-to-debug issues!
Calculations are a really, really powerful tool. They can be used for simple
data formatting, like our string_years_ago example here, or complex tasks like
building tree data structures out of a flat data set, or pathfinding in a graph.
Calculations can also work with resource relationships and their data, and
here we get to what we actually want to build for Tunez.

Calculations with related records

Tunez is recording all this interesting album information for each artist, but
not showing any of it in the artist catalog. So we’ll use calculations to surface
some of it as part of the loaded Artist data, and display it on the page.

There are three pieces of information we really want:

The number of albums each artist has released,
The year that each artist’s latest album was released in, and
The most recent album cover for each artist
Let’s look at how we can build each of those with calculations!

Chapter 3. Creating a Better Search UI • 80

Counting albums for an artist
Ash provides the count/2 expression function,^18 also known as an inline
aggregate function (we’ll see why shortly), that we can use to count records
in a relationship.
So to count each artist’s albums as part of a calculation, we could add it as
a calculation in the Artist resource:
defmodule Tunez.Music.Artist do
# ...
calculations do
➤ calculate :album_count , :integer , expr(count(albums))
end
end
Testing this in iex, you can see it makes a pretty efficient query, even when
querying multiple records. There’s no n+1 query issues here, it’s all handled
in one query through a clever join:
iex(1)> Tunez.Music.search_artists( "a" , load: [ :album_count ])
SELECTa0."id",a0."name",a0."biography",a0."previous_names",
a0."inserted_at",a0."updated_at",coalesce(s1."aggregate_0",$1::bigint)
::bigint::bigint::bigintFROM"artists"AS a0 LEFTOUTERJOINLATERAL
(SELECTsa0."artist_id"AS "artist_id",coalesce(count( ***** ),
$2::bigint)::bigintAS "aggregate_0"FROM"public"."albums"AS sa0 WHERE
(a0."id"= sa0."artist_id")GROUPBY sa0."artist_id")AS s1 ON TRUEWHERE
(a0."name"::textILIKE$3) ORDERBY a0."id"LIMIT$4 [0, 0, "%a%",13]
{:ok,%Ash.Page.Offset{...}}
It’s a little bit icky with some extra type-casting that doesn’t need to be done,
but we’ll address that shortly (this isn’t the final form of our calculation!)

Finding the most recent album release year for an artist
This one is a little bit trickier. We’re working with relationship data again, so
we’ll use another inline aggregate function. Because we’ve ensured that albums
are always ordered according to release year in Loading Related Resource
Data, on page 44, the first album in the list of related albums will always be
the most recent.
The first aggregate function is used to fetch a specific attribute value from the
first record in the relationship, so we can use it to pull out just the year_released
value from the album, and store it in a new attribute on the Artist.
calculations do
calculate :album_count , :integer , expr(count(albums))
18.https://hexdocs.pm/ash/expressions.html#sub-expressions
No DB field? No Problems, with Calculations • 81

➤ calculate :latest_album_year_released , :integer ,
➤ expr(first(albums, field::year_released ))
end

Finding the most recent album cover for an artist
This is very similar to, but a slight twist on, the previous calculation. Again
we want the most recent album, but only out of albums that have the
optional cover_image_url attribute specified. We could add this extra condition
using the filter option on the base query, like we did when we set a sort order
in The base query for a read action, on page 70, but we don’t actually need
to — for convenience, Ash will filter out nil values automatically. Note that the
calculation can still return nil if an artist has no albums at all, or has no
albums with album covers.
Everything combined, our calculation can look like this:
calculations do
calculate :album_count , :integer , expr(count(albums))
calculate :latest_album_year_released , :integer ,
expr(first(albums, field::year_released ))
➤ calculate :cover_image_url , :string ,
➤ expr(first(albums, field::cover_image_url ))
end

If you don’t want this convenience, if you really do want the cover
for the most recent album even if it’s nil, you can add the include_nil?:
true option to the first inline-aggregate function call.
And this works! We can specify any or all of these three calculation names,
:album_count, :latest_album_year_released, and :cover_image_url, when loading artist
data and get the attributes properly calculated and returned. This is really
powerful; and we’ve only scratched the surface of what you can do with cal-
culations.
The code here is starting to get a little bit gnarly, though. Our three calcula-
tions have one thing in common — they all use inline aggregate functions, to
surface some attribute or derived value from relationships. Instead of defining
the aggregates inline, we can look at extracting them into full aggregates, and
see how that cleans up the code.
Relationship Calculations as Aggregates
Aggregates are a specialized type of calculation, as we’ve seen above. All
aggregates are calculations; but a calculation like years_ago in our Album
example was not an aggregate.
Chapter 3. Creating a Better Search UI • 82

Aggregates perform some kind of calculation on records in a relationship —
it could be a simple calculation like first or count, or a more complicated calcu-
lation like min or avg (average), or you can even provide a fully-custom imple-
mentation if the full list of aggregate types^19 doesn’t have what you need.
To start adding aggregates to our Artist resource, we first need to add the
aggregates block at the top level of the resource. (You might be sensing a pattern
about this, by now.)
03/lib/tunez/music/artist.ex
defmodule Tunez.Music.Artist do
# ...
aggregates do
end
end
Each of the three inline-aggregate calculations we defined, can be rewritten
to be an aggregate within this block. An aggregate needs at least three things
— the type of aggregate, the name of the attribute to be used for the result
value, and the relationship to be used for the aggregate.
So our example of the album_count calculation:
calculate :album_count , :integer , expr(count(albums))
Could be written more appropriately as a count aggregate:
03/lib/tunez/music/artist.ex
aggregates do
➤ count :album_count , :albums
end
We don’t need to specify the type of the resulting attribute — Ash knows that
a count is always an integer, it can’t be anything else, even if it’s zero. This
also simplifies the generated SQL a little bit, there’s no need for repeatedly
casting things as bigints.
Our latest_album_year_released calculation can be rewritten similarly:
03/lib/tunez/music/artist.ex
aggregates do
count :album_count , _:albums

old:calculation
calculate:latest_album_year_released,:integer,
expr(first(albums,field::year_released))_
➤ first :latest_album_year_released , :albums , :year_released

19.https://hexdocs.pm/ash/aggregates.html#declaring-aggregates-on-a-resource
Relationship Calculations as Aggregates • 83

end
We’ve dropped a little bit of the messy syntax, and the result is a lot easier
to read. We don’t need to define that latest_album_year_released is an integer —
that can be inferred because the Album resource already defines the
year_released attribute as an integer. If the syntax seems a bit mysterious (where
did the field key go?), the options available for each type of aggregate are fully
laid out in the Ash.Resource DSL documentation.^20
The final calculation, for cover_image_url, is the same as for latest_album_year_released.
The include_nil?:true option can be used here too, if you really want a cover that
might be nil, but we’ll rely on the default value of false. If a given artist has
any awesome album covers, we want the most recent one.
03/lib/tunez/music/artist.ex
aggregates do
count :album_count , :albums
first :latest_album_year_released , :albums , :year_released
# old:calculation
# calculate:cover_image_url,:string,
# expr(first(albums,field::cover_image_url))
➤ first :cover_image_url , :albums , :cover_image_url
end
In this way, we can put all the logic of how to calculate a latest_album_year_released
or a cover_image_url for an artist where it belongs, in the domain layer of our
application, and our front-end views don’t have to worry about where it might
come from. On that note, let’s integrate these aggregates in our artist catalog.

Using aggregates like any other attribute
It would be amazing if the artist catalog looked like a beautiful display, of
album artwork and artist information.
20.https://hexdocs.pm/ash/dsl-ash-resource.html#aggregates
Chapter 3. Creating a Better Search UI • 84

In Tunez.Artists.IndexLive, the cover image display is handled by a call to the cov-
er_image function component within artist_card:
03/lib/tunez_web/live/artists/index_live.ex
<divid= {"artist-#{@artist.id}"} data-role= "artist-card" class= "relativemb-2" >
<. linknavigate= {~p"/artists/#{@artist}"} >
<. cover_image/>
</. link>

Because we can use and reference aggregate attributes like any other attributes on a resource, we can add an image argument to the cover_image function component, to replace the default placeholder image with our cov- er_image_url calculation: **03/lib/tunez_web/live/artists/index_live.ex** <**.** linknavigate= _{~p"/artists/#{@artist}"}_ > ➤ <**.** cover_imageimage= _{@artist.cover_image_url}_ /> Refreshing the artist catalog after making the change might not be what you expect — why aren’t the covers displaying? Because we aren’t loading them! Remember that we need to specifically load calculations/aggregates if we want to use them, they won’t be generated automatically. We _could_ add the calculations to our Tunez.Music.search_artists function call using the load option, like we loaded albums for an artist on their profile page: page= Tunez.Music.search_artists!(query_text, _page:_ page_params,
Relationship Calculations as Aggregates • 85

query: [ sort_input: sort_by],
➤ load: [ :album_count , :latest_album_year_released , :cover_image_url ]
)
And this works! This would be the easiest way. But if you ever wanted to
reuse this artist card display, you would need to manually include all of the
calculations when loading data there too, which isn’t ideal. There are a few
other ways we could load the data, such as via a preparation^21 in the Artist
search action itself:
read :search do
# ...
preparebuild( load: [ :album_count , :latest_album_year_released ,
:cover_image_url ])
end
Implementing it this way would mean that every time you call the action, the
calculations would be loaded, even if they’re not used. If the calculations were
expensive, such as loading data from an external service, this would be
costly!
Ultimately it depends on the needs of your application, but in this specific
case a good middle ground would be to add the load statement to the code
interface , using the default_options^22 option. This means that whenever we call
the action via our Tunez.Music.search_artists code interface, the data will be loaded
automatically, but if we call the action manually (such as by constructing a
query for the action), it won’t.
03/lib/tunez/music.ex
define :search_artists ,
action::search ,
args: [ :query ],
➤ default_options: [
➤ load: [ :album_count , :latest_album_year_released , :cover_image_url ]
➤ ]

Reloading the artist catalog will now populate the data for all of the aggregates
we listed, and look at the awesome artwork appear! Special thanks to Midjour-
ney, for bringing our imagination to life!
Note that some of our sample bands don’t have any albums, and some of the
artists with albums, don’t have any album covers. Our aggregates can account
for these cases, and the site isn’t broken in any way — we see the placeholder
images that we saw before.
21.https://hexdocs.pm/ash/Ash.Resource.Preparation.Builtins.html#build/1
22.https://hexdocs.pm/ash/dsl-ash-domain.html#resources-resource-define-default_options
Chapter 3. Creating a Better Search UI • 86

For the album count and latest album year released fields, we can add those
details to the end of the artist_card function, using the previously-unused
artist_card_album_info component defined right below it:
03/lib/tunez_web/live/artists/index_live.ex
def artist_card(assigns) do
~ H """
<% # ... %>
<.artist_card_album_infoartist={@artist}/>
"""
end
And behold! The artist catalog is now in its full glory!
Earlier in the chapter, we looked at sorting artists in the catalog, via three
different attributes - name, inserted_at and updated_at. We’ve explicitly said a few
times now, that calculations and aggregates can be treated like any other
attribute — does that mean we might be able to sort on them too???
You bet you can!
Sorting based on aggregate data
Around this point is where Ash really starts to shine, and you might start
feeling a bit of a tingle with the power at your fingertips. Hold that thought,
because it’s going to get even better. Let’s add some new sort options for our
aggregate attributes, to our list of available sort options in Tunez.Artists.IndexLive:
03/lib/tunez_web/live/artists/index_live.ex
defp sort_options do
[
{ "recentlyupdated" , "-updated_at" },
{ "recentlyadded" , "-inserted_at" },
{ "name" , "name" },
➤ { "numberof albums" , "-album_count" },
➤ { "latestalbumrelease" , "--latest_album_year_released" }
]
end
We want artists with the most albums and with the most recent albums listed
first, so we’ll sort them descending by prefixing the attribute name with a -.
Using -- is a bit special — it’ll put any nil values (if an artist hasn’t released
any albums!) at the end of the list.
To allow the aggregates to be sorted on, we do need to mark them as public?
true, like we did with our initial set of sortable attributes in Using sort_input
for succinct yet expressive sorting, on page 71:

Relationship Calculations as Aggregates • 87

03/lib/tunez/music/artist.ex
aggregates do
count :album_count , :albums do
➤ public?true
end
first :latest_album_year_released , :albums , :year_released do
➤ public?true
end
# ...
end
And then we’ll be able to sort in our artist catalog, to see which artists have
the most albums, or have released albums most recently:

This is all amazing! We’ve built some really excellent functionality over the
course of this chapter, to let users search, sort, and paginate through data.
And in the next one, we’ll see how we can use the power of Ash to build some
neat APIs for Tunez, using our existing resources and actions. Reduce, re-
use and recycle code!
Chapter 3. Creating a Better Search UI • 88

CHAPTER 4
