All About Testing

While working on Tunez, we’ve been doing lots of manual testing of our code.
We’ve called functions in iex and verified the results, and loaded the web app
in a browser to click around. This is fine while we figure things out, but won’t
scale as our app grows. For that, we can look at automated testing.

There are two main reasons to write automated tests:

To confirm our current understanding of our code. When we write tests,
we’re asserting that our code behaves in a certain way. This is what we’ve
been doing so far.
To protect against unintentional change. When we make changes to our
code, it’s critical to understand the impact of those changes. The tests
now serve as a safety net to prevent regressions in functionality or bugs
being introduced.
A common misconception about testing Ash applications is that you don’t
need to write as many tests as you would if you had handwritten all of the
features that Ash provides for you. This isn’t the case: it’s important to confirm
our understanding and to protect against unintentional change when building
with Ash. Just because it’s much easier to build our apps doesn’t mitigate
the necessity for testing.

In this chapter, we won’t cover how to use ExUnit^1 to write unit tests in Elixir.
There are entire books written on testing, such as Testing Elixir [LM21]. For
LiveView-specific advice, there’s also a great section in Programming Phoenix
LiveView [TD24] , and libraries like PhoenixTest^2 to make it smoother. What
we will focus on is as follows:

https://hexdocs.pm/ex_unit
https://hexdocs.pm/phoenix_test/
How to set up and execute tests against Ash resources
What helpers Ash provides to assist in testing
What kinds of things you should test in applications built with Ash
This information will help you apply any testing methodology you might adopt.

There’s no code for you to write in this chapter — Tunez comes
with a full set of tests pre-prepared, but they’re all skipped and
commented out (to prevent compilation failures). As we go through
this chapter, you can check them out, and un-skip and un-com-
ment the tests that cover features we’ve written so far.
For the remaining chapters in this book, we’ll point out the tests
that cover the functionality we’re going to build.
Some of the tests we show in this chapter are for demonstration
purposes only, and don’t exist in Tunez. These will be marked with
comments saying so.
What Should We Test?
“What do we test?” is a question that Ash can help answer. Ultimately, every
interface in Ash stems from our action definitions. This means that the vast
majority of our testing should center around calling our actions, making
assertions about the behavior and effects of those actions. We should still
write tests for our API interfaces, but they don’t necessarily need to be com-
prehensive. One caveat to this is that if you are developing a public API, you
may want to be more rigorous in your testing. We will cover this in greater
detail shortly.

Additionally, Ash comes with tools and patterns that allow you to unit test
various elements of your resource. Since an example is worth a thousand
words, let’s use some of these tools.

The basic first test

One of the best first tests to write for a resource is the empty read case —
when there is no stored data, nothing is returned. This test may be kind of
obvious, but it can detect problems in your test setup, such as leftover data
that isn’t being deleted between tests. It can also help identify when something
is broken about your action that has nothing to do with the data in your data
layer.

defmodule Tunez.Music.ArtistTest do
use Tunez.DataCase, async: true

Chapter 7. All About Testing • 170

describe "Tunez.Music.read_artists!/0-2" do
test "whenthereis no data,nothingis returned" do
assertTunez.Music.read_artists!()== []
end
end
end

We can call the code interface functions defined for our actions and directly
assert on the result. Provide inputs, verify outputs. It sounds so simple, when
written like that!

While our code interfaces are on the Tunez.Music domain module,
and not the Tunez.Music.Artist resource module, it would make for a
very long and hard-to-navigate test file to include all the tests for
the domain in one test module.
It is generally better to split up tests into smaller groups. Here
we’re testing actions on the Tunez.Music.Artist resource specifically,
so we have one module just for those. This is not a requirement,
but it leads to better test organization.
For more complicated actions (i.e. nearly all of them), we’ll need a way of
setting up the data and state required.

Setting Up Data
For Artist actions like search or update, we’ll need some records to exist in the
data layer before we can run our actions and check the results. There are
two approaches for this:

Setting up test data using your resource actions
Seeding data directly via the data layer, bypassing actions
Let’s take a look at how these two approaches differ, the pros and cons of
each, and when you might want to use one or the other.

Using actions to set up test data

The first approach is to do what we’ve already been doing all throughout this
book: calling resource actions. These tests can be seen as a series of events.

_# Demonstrationtestonly

Thereare testsfor thisactionin Tunez,but not writtenlikethis!_
defmodule Tunez.Music.ArtistTest do
# ...
describe "Tunez.Music.search_artists!/1-3" do
test "can findartistsby partialnamematch" do

Setting Up Data • 171

artist= Tunez.Music.create_artist!(%{
name:"The FroodyDudes" ,
biography:"42 musiciansall playingthe sameinstrument(a towel)"
}, authorize?: false)
assert[match]= Tunez.Music.search_artists!( "Frood" )
assertmatch.id== artist.id
end
end
end

This is a pretty straightforward construction. First we create an Artist, and
then we assert that we get it back when we search for it. When in doubt, start
with these kinds of tests.

We’re testing our application’s behaviour in the same way that it actually gets
used. And because we’re building with Ash, and our APIs and web UIs go
through the same actions, we don’t need to write extensive tests covering
each different interface — we can test the action thoroughly, and then write
simpler smoke tests for each of the interfaces that uses it.

(Writing out action calls with full data can be tedious and prone to breakage,
though. We’ll cover ways of addressing this in Consolidating Test Setup Logic,
on page 175 .)

What are the pros and cons of this kind of testing?

Pro: We are testing real sequences of events

If something changes in the way that our users create artists that affects
whether or not they show up in the search bar, our test will reflect that. This
is more akin to testing a “user story” than a unit test (albeit a very small user
story).

This can also be a con: if something breaks in the Artist create action, every
test that creates artist records as part of their setup will suddenly start failing.
If this happens, though, all tests that aren’t specifically for the Artist :create
function should point directly to it as the cause.

Con: Real application code has rules and dependencies

Let’s imagine that we have a new app requirement, that new artists could
only be created on Tuesdays. If we wrote a custom validation module named
IsTuesday and called it in the Artist create action, suddenly our test suite would
only pass on Tuesdays!

There are ways around this, such as using a private argument to determine
whether to run the validation or not. This can then be specifically disabled

Chapter 7. All About Testing • 172

in tests, by passing in the option private_arguments:%{validate_tuesday: false} when
building a changeset or calling a code interface function.

create :create do
argument :validate_tuesday , :boolean , default: true, private?: true
validateIsTuesday, where: argument_equals( :validate_tuesday , true)
end

You could also introduce a test double in the form of a mock with an explicit
contract,^3 with different implementations based on the environment. This is
also commonly used for replacing external dependencies in either dev or test.
We’ve already used an example of this with the Swoosh mailer, in Why do
users always forget their passwords!?, on page 124. In production, it will send
real emails (if we connected a suitable adapter)^4 but in dev/test it uses an in-
memory adapter instead.

If all else fails, you can fall back to a library like mimic,^5 that performs more
traditional mocking (mocking-as-a-verb).

Pro: Your application is end-to-end testable

If you have the time and resources to go through the above steps to ensure
that actions with complex validations or external dependencies are testable,
then this strategy is the best approach. Our tests are all doing only real, valid
action calls, and we can have much more confidence in them.

With all of that said, there are still cases where we would want to set up our
tests by working directly against the data layer. Let’s explore one of those
cases now.

Seeding data

The other method of setting up our tests is to use seeds. Seeds bypass action
logic, going straight to the data layer. When using AshPostgres, this essentially
means performing an INSERT statement directly. The only thing that Ash can
validate when using seeds are attribute types, and the allow_nil? option, because
they’re implemented at the database level. If you’ve used libraries like
ex_machina,^6 this is the strategy they use.

When should you reach to for seeds to set up test data, instead of calling your
resource actions? Imagine that we’ve realized that a lot of Tunez users are

https://dashbit.co/blog/mocks-and-explicit-contracts
https://hexdocs.pm/swoosh/Swoosh.html#module-adapters
https://hexdocs.pm/mimic/
https://hexdocs.pm/ex_machina/
Setting Up Data • 173

creating artists with incomplete biographies, like just the word “Hi”. To fix
this, we’ve decided that it should actually be a rule that all biographies have
at least 3 sentences.
So we write another custom validation module called SentenceCount, and add
it the validations block of our Artist resource like validate{SentenceCount,field::biography,
min: 3}, so it applies to all actions. Fantastic, ship it. Oops, we’ve just created
a subtle bug! Can you spot it?
In this hypothetical, when a user tries to update the name of an artist that
has a too-short biography saved, they’ll get an error about the biography.
That’s not a great user experience. Luckily, it’s an easy fix. We can tweak the
validation to only apply when the biography is being updated:
validations do
validate{SentenceCount, field::biography , min: 3} do
➤ wherechanging( :biography )
end
end
How do we test this fix that we just made? We need a record with a short
biography in the database to make sure the validation doesn’t get triggered
if it’s not being changed. We don’t want to add a new action just to allow for
the creation of bad data. This is a perfect case for seeds to insert data
directly into the data layer using Ash.Seed.
In this example, we use Ash.Seed to create an artist that would not normally
be allowed to be created.
# Demonstrationtestonly- thisvalidationdoesn'texistin Tunez!
describe "Tunez.Music.update_artist!/1-3" do
test "whenan artist'snameis updated,the biographylengthdoes
not causea validationerror" do
artist=
Ash.Seed.seed!(
%Tunez.Music.Artist{
name:"The FroodyDudes" ,
biography:"42 musiciansall playingthe sameinstrument(a towel)."
}
)
updated_artist= Tunez.Music.update_artist!(artist,%{ name:"New Name" })
assertupdated_artist.name== "New Name"
end
end
What are the pros and cons of this kind of testing?

Chapter 7. All About Testing • 174

Pro: Your tests are faster and simpler

Ash.Seed goes directly to the data layer, so any action logic, policies, or notifiers
will be skipped. It can be easier to reason about what your test setup actually
does. You can think more simply in terms of the data you need, not about
the steps required to create it. If a call to Ash.Seed.seed! succeeds, you know
you’ve written exactly that data to the data layer.

For the same reason, this will always be at least a little faster than calling
actions directly. For actions that do a lot of validation or contain hooks to
call other actions for example, using seeds can be much faster.

Con: Your tests are not as realistic

While writing test setup using real actions makes setup more complicated,
it also makes them more valuable and more correct. When testing with seed
data, it’s easy to accidentally create data that has no value to test against
because it’s not possible to create under normal app execution. In Tunez
tests, we could seed some artists that were created by users with role :user or
:editor, which definitely violates our authorization rules. Or we could even set
a user role that doesn’t exist in our app! (This has actually happened.) And
what is testing the validity of the test data?

Depending on the situation, this can be worse than just wasted code: It can
mislead you into believing that you’ve tested a part of your application that
you haven’t. It can also be difficult to know when you’ve changed something
in your actions that should be reflected in your tests because your test setup
bypasses actions.

How do I choose between seeds and calling actions?

When both will do what you need, consider what you’re trying to test. Are
you testing a data condition , such as the validation example, or are you testing
an event , such as running a search query? If the former, then use seeds. If
the latter, use your resource actions. When in doubt, use actions.

Consolidating Test Setup Logic
Ash.Generator^7 provides tools for dynamically generating various kinds of data.
You can generate action inputs, queries, and even complete resource records,
without having to specify values for every single attribute. We can use
Ash.Generator to clean up our test setup and also to clearly distinguish our
setup code from our test code.

https://hexdocs.pm/ash/Ash.Generator.html
Consolidating Test Setup Logic • 175

The core functionality of Ash.Generator is built using the StreamData^8 library, and
the generator/1 callback on Ash.Type. You can test out any of Ash’s built-in types,^9
using Ash.Type.generator/2:

iex(1)>Ash.Type.generator( :integer , min: 1, max: 100)
#StreamData<66.1229758/2in StreamData.integer/1>
iex(2)>Ash.Type.generator( :integer , min: 1, max: 100)|> Enum.take(10)
[21,79, 33, 16, 15, 95, 53, 27, 69, 31]

The generator returns an instance of StreamData, which is a lazily-evaluated
stream^10 of random data that matches the type and constraints specified. To
get generated data out of the stream, we can evaluate it using functions from
the Enum module.

Ash.Generator also works for more complex types, such as maps of a set format:

iex(1)>Ash.Type.generator( :map , fields: [
hello: [
type: { :array , :integer },
constraints: [
min_length: 2, items: [ min: -1000, max: 1000]
]
],
world: [ type::uuid ]
]) |> Enum.take(1)
[%{ hello: [-98,290], world:"2368cc8d-c5b6-46d8-97ab-1fe1d9e5178c" }]

We can generate more than just basic data structures, as well. Ash.Genera-
tor.action_input/3 can be used to generate sets of valid inputs for actions, and
Ash.Generator.changeset_generator/3 builds on top of that to generate whole
changesets for calling actions. That sounds like an idea...

Creating test data using Ash.Generator

We can use the tools provided by Ash.Generator to build a Tunez.Generator module
for test data. Using changeset_generator/3,^11 we can write functions that generate
streams of changesets for a specific action, which can then be modified further
if necessary or submitted to insert the records into the data layer.

Let’s start with defining a user generator. To create different types of users,
we would need to create changesets for the User register_with_password action,
submit it, and then maybe update their roles afterwards with

https://elixir-lang.org/blog/2017/10/31/stream-data-property-based-testing-and-data-generation-for-elixir/
https://hexdocs.pm/ash/Ash.Type.html
10.https://hexdocs.pm/elixir/Stream.html
11.https://hexdocs.pm/ash/Ash.Generator.html#changeset_generator/3
Chapter 7. All About Testing • 176

Tunez.Accounts.set_user_role. We can follow a very similar pattern using options
for changeset_generator/3.

The key point to keep in mind is that our custom generators should always
return a stream: The test calling the generator should always be able to decide
if it needs one record or 100.

defmodule Tunez.Generator do
use Ash.Generator
def user(opts\ []) do
changeset_generator(
Tunez.Accounts.User,
:register_with_password ,
defaults: [
_# Generatesuniquevaluesusingan auto-incrementingsequence

eg. user1@example.com, user2@example.com,etc.
email:_ sequence( :user_email , & "user#{ &1 }@example.com" ),
password:"password" ,
password_confirmation:"password"
],
overrides: opts,
after_action: fn user->
role= opts[ :role ] || :user
Tunez.Accounts.set_user_role!(user,role, authorize?: false)
end
)
end
end

To use our shiny new generator in a test, the test module needs to use
Tunez.Generator and then we can use the provided generate^12 or generate_many
functions:

# Demonstrationtest- thisis onlyto showhow to callgenerators!
defmodule Tunez.Accounts.UserTest do
import Tunez.Generator
test "can createuserrecords" do
# Generatea userwithall defaultdata
user= generate(user())
# Or generatemorethanone user,withsomespecificdata
two_admins= generate_many(user( role::admin ), 2)
end
end

As the opts to the generator function are passed directly to changeset_generator/3
as overrides for the default data, we could also include a specific email address

12.https://hexdocs.pm/ash/Ash.Generator.html#generate/1

Consolidating Test Setup Logic • 177

or password, if we wanted. The generate functions use Ash.create! to process the
changeset, so if something goes wrong, we’ll know immediately. This is pretty
clean!

We can write a generator for artists similarly. Creating an artist needs some
additional data to exist in the data layer: an actor to create the record. We
can pass an actor in via opts, or we can call our user generator within the artist
generator.

One pitfall of calling the user generator directly is that we would get a user
created for each artist we create. That might be what you want, but most of
the time, it’s unnecessary. To get around this, Ash.Generator provides the once/2
helper function: It will call the passed-in function (in which we can generate
a user) exactly once, and then re-use the value for subsequent calls in the
same generator.

defmodule Tunez.Generator do
# ...
def artist(opts\ []) do
actor= opts[ :actor ] || once( :default_actor , fn ->
generate(user( role::admin ))
end )
changeset_generator(
Tunez.Music.Artist,
:create ,
defaults: [ name: sequence( :artist_name , & "Artist#{ &1 }" )],
actor: actor,
overrides: opts
)
end
end

If we don’t pass in an actor when generating artists, even if we generate a
million artists, they’ll all have the same actor. Efficient!

Now we can tie it all together to create an album factory. We can follow the
same patterns as before, accepting options to allow customizing the generator,
and massaging the generated inputs to be acceptable by the action.

defmodule Tunez.Generator do
# ...
def album(opts\ []) do
actor= opts[ :actor ] || once( :default_actor , fn ->
generate(user( role: opts[ :actor_role ] || :editor ))
end )
artist_id= opts[ :artist_id ] || once( :default_artist_id , fn ->
generate(artist()).id

Chapter 7. All About Testing • 178

end )
changeset_generator(
Tunez.Music.Album,
:create ,
defaults: [
name: sequence( :album_name , & "Album#{ &1 }" ),
year_released: StreamData.integer(1951..2024),
artist_id: artist_id,
cover_image_url: nil
],
overrides: opts,
actor: actor
)
end
end

If we do need to seed data instead of using changesets with actions, Ash.Gener-
ator also provides seed_generator/2.^13 This can be used in a very similar way,
except instead of providing a resource/action, you can provide a resource
struct:

defmodule Tunez.Generator do
# ...
def seeded_artist(opts\ []) do
actor= opts[ :actor ] || once( :default_actor , fn ->
generate(user( role::admin ))
end )
seed_generator(
%Tunez.Music.Artist{ name: sequence( :artist_name , & "Artist#{ &1 }" )},
actor: actor,
overrides: opts
)
end
end

This is a drop-in replacement for the artist generator, so you can still call
functions like generate_many(seeded_artist(),3). You could even put both seed and
changeset generators in the same custom generator, and switch between
them based on an opt value. It’s a very flexible pattern that allows you to
generate exactly the data you need, in an explicit yet succinct way, and with
the most confidence that what you’re generating is real.

Armed with our generator, we’re ready to start writing more tests!

13.https://hexdocs.pm/ash/Ash.Generator.html#seed_generator/2

Consolidating Test Setup Logic • 179

Testing Resources
As we discussed earlier, the interfaces to our app all stem from our resource
definitions. The code interfaces we define are the only thing external sources
know about our app and how it works. So it makes sense that most of our
tests will revolve around calling actions and verifying what they do. We’ve
already seen a brief example when we wrote our first empty-case teston page
170 , and now we’ll write some more.

Testing actions

The tests we want to write will follow a few guidelines:

Prefer to use code interfaces when calling actions
Use the raising “bang” versions of code interfaces in tests
Avoid using pattern matching to assert success or failure of actions
For asserting errors, use Ash.Test.assert_has_error or assert_raise
You can test policies, calculations, aggregates and relationships,
changesets, and queries in unit tests
The reasons for using code interfaces in tests are the same as in our applica-
tion code, and they’ll help us detect when changes to our resources require
changes in our tests. Using the bang versions of functions that support it will
keep our tests simple and give us better error messages when something goes
wrong. Avoiding pattern matching helps with error messages and also
increases the readability of our tests.

Some of the more interesting actions we might want to test are the Artist search
action (including filtering and sorting), and the Artist update action (for storing
previous names and recording who made the change). What might those look
like with our new generators?

_# Thiscan alsobe addedto the usingblockin Tunez.DataCasefor

use in all tests_
use Tunez.Generator

describe "Tunez.Music.search_artists/1-2" do
defp names(page), do : Enum.map(page.results,& &1.name)
test "can filterby partialnamematches" do
[ "hello" , "goodbye" , "what?" ]
|> Enum.each(&generate(artist( name: &1)))
assertEnum.sort(names(Music.search_artists!( "o" ))) == [ "goodbye" , "hello" ]
assertnames(Music.search_artists!( "oo" )) == [ "goodbye" ]
assertnames(Music.search_artists!( "he" )) == [ "hello" ]
end

Chapter 7. All About Testing • 180

The test uses the generators we just wrote, so we’re assured that we’re looking
at real (albeit trivial) data. What about something a bit more complex, like
testing one of the aggregate sorts we added?
test "can sortby numberof albumreleases" do
generate(artist( name:"two" , album_count: 2))
generate(artist( name:"none" ))
generate(artist( name:"one" , album_count: 1))
generate(artist( name:"three" , album_count: 3))
actual=
names(Music.search_artists!( "" , query: [ sort_input:"-album_count" ]))
assertactual== [ "three" , "two" , "one" , "none" ]
end
The artist generator we wrote doesn’t currently have an album_count option (it
won’t raise an error, but it won’t do anything). For something like this, though,
that feels like common behaviour, we can always add one. We can add an
after_action to the call to changeset_generator to generate the number of albums we
want for the artist.
def artist(opts\\ []) do
# ...
➤ after_action=
➤ if opts[ :album_count ] do
➤ fn artist->
➤ generate_many(album( artist_id: artist.id),opts[ :album_count ])
➤ Ash.load!(artist, :albums )
➤ end
➤ end

# ...
changeset_generator(
Tunez.Music.Artist, :create ,
defaults: [ name: sequence( :artist_name , & "Artist#{ &1 }" )],
actor: actor, overrides: opts,
➤ after_action: after_action
)
end
We haven’t specified any overrides for the albums to be generated. If you want
to do that (e.g., specify that the albums were released in a specific year), we
recommend not using this option and generating the albums separately in
your test.

Testing Resources • 181

Testing errors

Testing errors is a critical part of testing your application, but can also be
kind of inconvenient. Actions can produce many different kinds of errors, and
sometimes even multiple errors at once.

ExUnit comes with assert_raise^14 built-in for testing raised errors, and Ash also
provides a helper function named Ash.Test.assert_has_error.^15 assert_raise is good for
quick testing to say “when I do X, it fails for Y reason”, while assert_has_error
allows for more granular verification of the generated error.

The most common errors in Tunez right now are data validation errors, so
what kind of tests might we write for those?

defmodule Tunez.Music.AlbumTest do
# Thiscan alsobe importedin the usingblockof Tunez.DataCase
import Ash.Test
import Tunez.DataCase
describe "validations" do
test "year_releasedmustbe between 1950 and now" do
admin= generate(user( role::admin ))
artist= generate(artist())
_# The assertionisn'treallyneededhere,but we wantto signalto

our futureselvesthatthisis partof the test,not the setup._
assertMusic.create_album!(
%{ artist_id: artist.id, name: "test2024" , year_released: 2024},
actor: admin
)
# Usingassert_raise
assert_raiseAsh.Error.Invalid, ~r/mustbe between 1950 and thisyear/ ,
fn ->
Music.create_album!(
%{ artist_id: artist.id, name:"test1925" , year_released: 1925},
actor: admin
)
end
# Usingassert_has_error
%{ artist_id: artist.id, name:"test1950" , year_released: 1950}
|> Music.create_album( actor: admin)
|> assert_has_error(Ash.Error.Invalid, fn
%{ message: message}->
message== "mustbe between 1950 and thisyear"
_ ->
false

14.https://hexdocs.pm/ex_unit/ExUnit.Assertions.html#assert_raise/2
15.https://hexdocs.pm/ash/Ash.Test.html

Chapter 7. All About Testing • 182

end )
end
There are a few more examples of validation testing in the Tunez.Music.AlbumTest
module — including how to use Ash.Generator.action_input^16 to generate valid action
inputs (according to the constraints defined.) Check them out!

Testing policies

If you test anything at all while building an app, test your policies. Policies
typically define the most critical rules in your application, and should be
tested rigorously.

We can use the same tools for testing policies as we did in our liveview tem-
plates for showing/hiding buttons and other content — ‘Ash.can?‘,on page
157 and the helper functions generated for code interfaces, can_*?. These run
the policy checks for the actions, and return a boolean. Can the supplied
actor run the actions according to the policy checks, or not? For testing
policies for create, update and destroy actions, these make for very simple and
expressive tests.

Note how we’re using refute for the last three assertions in the test: These
users can’t create artists!

test "onlyadminscan createartists" do
admin= generate(user( role::admin ))
assertMusic.can_create_artist?(admin)
editor= generate(user( role::editor ))
refuteMusic.can_create_artist?(editor)
user= generate(user())
refuteMusic.can_create_artist?(user)
refuteMusic.can_create_artist?(nil)
end

Testing policies for read actions looks a bit different. These policies typically
result in filters , not yes/no answers, meaning that we can’t simply test “can
the user run this query?” The answer is usually “yes, but nothing is returned
if we do.” For these kind of tests, we can use the data option to test that a
specific record can be read.

Let’s say that we get a new requirement that users should be able to look up
their own user records and admins should be able to look up any user record,

16.https://hexdocs.pm/ash/Ash.Generator.html#action_input/3

Testing Resources • 183

by email address. This could be over an API or in the UI; for our purposes, it
is not important (and the Ash code looks the same).

The Tunez.Accounts.User resource already has a get_by_email action, but it doesn’t
have any specific policies associated. We can add a new policy specifically for
that action:

policies do
# ...
policyaction( :get_by_email ) do
authorize_ifexpr(id== ^actor( :id ))
authorize_ifactor_attribute_equals( :role , :admin )
end
end

To make the action more accessible, we’ll add a code interface for the action,
in the Tunez.Accounts domain module:

resources do
# ...
resourceTunez.Accounts.User do
# ...
define :get_user_by_email , action::get_by_email , args: [ :email ]
end
end

Now we can test the interface with the auto-generated can_get_user_by_email?
function. Using the data option tells Ash to check the authorization against
the provided record or records. It’s roughly equivalent to running the query
with any authorization filters applied and checking to see if the given record
or records are returned.

# Demonstrationtestsonly- thisfunctionalitydoesn'texistin Tunez!
test "userscan onlyreadthemselves" do
[actor,other]= generate_many(user(), 2)
_# thisassertionwouldfail,becausethe actorcanrun the action

but it won'treturnthe otheruserrecord
refuteAccounts.can_get_user_by_email?(actor,other.email)_
refuteAccounts.can_get_user_by_email?(actor,other.email, data: other)
assertAccounts.can_get_user_by_email?(actor,actor.email, data: actor)
end

test "adminscan readotherusers" do
[user1,user2]= generate_many(user(), 2)
admin= generate(user( role::admin ))
assertAccounts.can_get_user_by_email?(admin,user1.email, data: user1)
assertAccounts.can_get_user_by_email?(admin,user2.email, data: user2)

Chapter 7. All About Testing • 184

end

You should test your policies until you’re confident that you’ve fully covered
all of their variations, and then add a few more tests just for good measure!

Testing relationships & aggregates

Ash doesn’t provide any special tools to assist in testing relationships or
aggregates because none are really needed. You can set up some data in your
test, load the relationship or aggregate, and then assert something about the
response.

We will, however, use this opportunity to show how you can use authorize?:false
to test or bypass your policies for the purpose of testing. A lot of the time,
you’ll likely want to skip authorization checking when loading data, unless
you’re specifically testing your policies around that data.

# Demonstrationtestonly- thisfunctionalitydoesn'texistin Tunez
test "userscannotsee who createdan album" do
user= generate(user())
album= generate(album())
# We canloadthe userrecordif we skipauthorization
assertAsh.load!(album, :created_by , authorize?: false).created_by
# If thisassertionfails,we knowthatit mustbe due to authorization
assert_raiseAsh.Error.Forbidden.Policy, fn ->
Ash.load!(album, :created_by , actor: user)
end
end

Testing calculations

Calculations often contain important application logic, so it can be important
to test them. You can test them the same way you test relationships and
aggregates — load them on a record and verify the results — but you can also
test them in total isolation using a helper function named Ash.calculate/3.^17

To show this, we’ll add a temporary calculation to the Tunez.Music.Artist resource
that calculates the length of the artist’s name using the expression function
string_length:^18

defmodule Tunez.Music.Artist do
# ...
calculations do
calculate :name_length , :integer , expr(string_length(name))

17.https://hexdocs.pm/ash/Ash.html#calculate/3
18.https://hexdocs.pm/ash/expressions.html#functions

Testing Resources • 185

end
end

If we wanted to use this calculation “normally”, we would have to construct
or load an Artist record, and then load the data:

iex(1)> artist= %Tunez.Music.Artist{ name:"Amazing!" } |>
Ash.load!(:name_length)
#Tunez.Music.Artist< ...>
iex(2)> artist.name_length
8

Using Ash.calculate/3, we can call the calculation directly, passing in a map of
references, or refs — data that the calculation needs to be evaluated.

iex(30)> Ash.calculate!(Tunez.Music.Artist, :name_length ,
refs:%{name:"Amazing!"})
8

The name_length calculation only relies on a name field, so the rest of the data
of any Artist record doesn’t matter. This makes it simpler to set up the data
required for tests.

This also works for calculations that require the database, such as those
written using database fragments.^19 If we were to rewrite our name_length cal-
culation using PostgreSQL’s length function:

calculations do
calculate :name_length , :integer , expr(fragment( "length(?)" , name)))
end

We could still call it in iex or in a test, only needing to pass in the name ref:

iex(3)>Ash.calculate!(Tunez.Music.Artist,:name_length,
refs:%{name:"Amazing!"})
SELECT(length($1))::bigintFROM(VALUES(1))AS f0 ["Amazing!"]
8

You can even define code interfaces for calculations. This combines the benefits
of Ash.calculate/3, with the benefits of code interfaces.

For a demonstration of this, we’ll use define_calculation^20 to define a code interface
for our trusty name_length calculation in the Tunez.Music domain module. A major
difference here is how we specify arguments for the code interface compared
with defining code interfaces for actions. Because calculations can also accept
arguments,^21 they need to be formatted slightly differently. Each of the code

19.https://hexdocs.pm/ash_postgres/expressions.html
20.https://hexdocs.pm/ash/dsl-ash-domain.html#resources-resource-define_calculation
21.https://hexdocs.pm/ash/calculations.html#arguments-in-calculations

Chapter 7. All About Testing • 186

interface arguments should be in a tuple tagging it as a ref, or an arg. Our
name is a ref, a data dependency of the calculation.

resources do
resourceTunez.Music.Artist do
...
define_calculation :artist_name_length , calculation::name_length ,
args: [{ :ref , :name }]
end
end

This exposes the name_length calculation defined on the Tunez.Music.Artist resource,
as an artist_name_length function on the domain module. (If the calculation name
and desired function name are the same, the calculation option can be left out.)
Look at the difference in clarity you get when calling this new function:

# Demonstrationtestonly- thisfunctiondoesn'texistin Tunez!
test "name_lengthshowshow manycharactersare in the name" do
assertTunez.Music.artist_name_length!( "fred" ) == 4
assertTunez.Music.artist_name_length!( "wat" ) == 3
end

When would something like this be useful, though? Imagine a scenario we
put a limit on the length of an artist’s name or some other content like a blog
post. You could use this calculation to display the number of characters
remaining next to the text box while the user is typing without visiting the
database. Then, if you some day change the way you count characters in an
artist’s name, like perhaps ignoring the spaces between words, the logic will
be reflected in your view in any API interface that uses that information and
even in any query that uses the calculation.

Unit testing changesets, queries and other Ash modules

The last tip for testing Ash is that you can unit test directly against an
Ash.Changeset, Ash.Query, or by calling functions directly on the Ash.Resource.Change
and Ash.Resource.Query modules.

For example, if we want to test our validations for year_released, we don’t neces-
sarily need to go through the rigamarole of setting up test data and trying to
call actions if we don’t want to. We have a few other options.

We could directly build a changeset for our actions and assert that it has a
given error. It doesn’t matter that it also has other errors. We just care that
it has one matching what we’re testing.

# Demonstrationtestonly- thisis coveredby actiontestsin Tunez
test "year_releasedmustbe greaterthan1950" do
Album

Testing Resources • 187

|> Ash.Changeset.for_create( :create , %{ year_released: 1920})
|> assert_has_error( fn error->
match?(%{ message:"mustbe between 1950 and" <> _}, error)
end )
end

We can apply the same logic above to Ash.Query and Ash.ActionInput to unit test
any piece of logic that Ash does eagerly as part of running an action. We can
test directly against the modules that we define, as well. Let’s write a test that
calls into our artist UpdatePreviousNames change.

# Demonstrationtestonly- thisis coveredby actiontestsin Tunez
test "previous_namesstorethe currentnamewhenchangingto a new name"
changeset=
%Artist{ name:"george" , previous_names: [ "fred" ]}
|> Ash.Changeset.new()
_# optsand contextaren'tusedby thischange,so we can

leavethemempty_
|> Tunez.Music.Changes.UpdatePreviousNames.change([],%{})
assertAsh.Changeset.changing_attribute?(changeset, :previous_names )
assert{ :ok , [ "george" , "fred" ]} = Ash.Changeset.fetch_change(changeset,
:previous_names )

As you can see, there are numerous places where you can drill down for more
specific unit testing as needed. This brings us to a reeeeeally big question....

Should I actually unit test every single one of these things?

Realistically? No.

Not every single variation of everything needs its own unit test. You can gen-
erally have a lot of confidence in your tests simply by calling your resource
actions and making assertions about the results. If you have an action with
a single change on it that does a little validation or data transformation, test
the action directly. You’ve exercised all of the code, and you know your action
works. That’s what you really care about, anyway!

You only need to look at unit testing individual parts of your resource if they
grow complex enough that you have trouble understanding them in isolation.
If you find yourself wanting to write many different combinations of inputs
to exercise one part of your action, perhaps that part could be tested on its
own.

Testing Interfaces
All of the tests we’ve looked at so far have centered around our resources.
This is the most important type of testing, because it extends to every interface

Chapter 7. All About Testing • 188

that uses our resources. If the number 5 is an invalid value when calling an
action, that property will extend to any UI or API that we use to call that
action. This doesn’t mean, however, that we shouldn’t test those higher layers.

What it does allow us to do is to be a bit less rigorous in testing these gener-
ated interfaces. If we’ve tested every action, validation, and policy at the Ash
level, we only really need to test some basic interactions at the UI/API level
to get the most bang for our buck.

Testing GraphQL

Since AshGraphql is built on top of the excellent absinthe library, we can use
its great utilities^22 for testing. It offers three different approaches, for testing
either resolvers, documents, or HTTP requests.

Ash actions take the place of resolvers, so any tests we write for our actions
will cover that facet. Our general goal is to have several end-to-end HTTP
request-response sanity tests to verify that the API as a whole is healthy and
seperate schema-level tests for different endpoints. These will quickly surface
errors if any types happen to accidentally change.

The main purpose of these tests is to verify our assumptions about our
schema. We don’t want to break our app’s defined contract with any external
sources. One of our tests might look like the following for the createArtist
mutation defined on the Tunez.Music domain:

test "createArtistvia Absinthe.run" do
user= generate(user( role::admin ))
assert{ :ok , resp}=
"""
mutationCreateArtist($input:CreateArtistInput!){
createArtist(input:$input){
result{ name}
errors{ message}
}
}
"""
|> Absinthe.run(TunezWeb.Schema,
variables: %{ "input" => %{ "name" => "New Artist" }},
context: %{ actor: user}
)
assertEnum.empty?(resp.data[ "createArtist" ][ "errors" ])
assertresp.data[ "createArtist" ][ "result" ][ "name" ] == "New Artist"
end

22.https://hexdocs.pm/absinthe/testing.html

Testing Interfaces • 189

This pattern should look fairly similar to testing our actions directly, except
it’s now all Absinthe-y. Instead of calling the action, we create the GraphQL
document for Absinthe.run, and we verify the result by checking the JSON
response.

We also highly recommend setting up your CI process (such as GitHub Actions)
to help guard against accidental changes to your API schema. This can be
done by generating a known-good schema definition once with the
absinthe.schema.sdl Mix task and committing it to your repository. As a step in
your build process, you can then run the task again into a separate file and
compare the two files to ensure no breaking changes.

Testing AshJsonApi

Everything we said for testing a GraphQL API above applies to testing an API
built with AshJsonApi as well. Since we generate an OpenAPI specification
for your API, you can even use the same strategy for guarding against
breaking changes.

The main difference when testing APIs built with AshJsonApi is that under
the hood, they use Phoenix controllers, so we can use Phoenix helpers for
controller tests. There are also some useful helpers in the AshJsonApi.Test mod-
ule^23 that you can import to make your tests more streamlined.

import AshJsonApi.Test

test "can createan artist" do
user= generate(user( role::admin ))
post(
Tunez.Music,
"/artists" ,
%{
data: %{
attributes: %{ name:"New JSON:APIartist" }
}
},
router: TunezWeb.AshJsonApiRouter,
status: 201,
actor: user
)
|> assert_data_matches(%{
"attributes" => %{ "name" => "New JSON:APIartist" }
})
end

23.https://hexdocs.pm/ash_json_api/AshJsonApi.Test.html

Chapter 7. All About Testing • 190

If something goes wrong, we’ll get an error in the response instead of the
newly-created record, and we can then assess and debug.

Testing Phoenix LiveView

Testing user interfaces is entirely different than anything else that we’ve dis-
cussed thus far. There are whole books dedicated to solely this topic. LiveView
itself has many testing utilities, and often when testing LiveView, we’re testing
much more than the functionality of our application core.

It’s unrealistic to cover all (or even most) of the UI testing patterns that exist
here, for LiveView or otherwise. Instead, let’s take a look at a few example
tests, using our preferred PhoenixTest^24 library. These should help you get
your feet wet, and the documentation for PhoenixTest and Phoenix.LiveViewTest^25
will take you the rest of the way.

Testing Page Content

In these examples, we can test an entire page in a rather broad way. For our
artist catalog in TunezWeb.Artists.IndexLive, we want to make sure that a card for
each artist is being rendered on the page (by HTML ID selector), and then we
have a separate test to cover the contents of each artist card. You can find
these tests, and more, in the Tunez app in test/tunez_web/live/artists/index_live_test.exs.

These tests use helpers like visit/2 and assert_has/3, which are provided by
PhoenixTest, to load pages and ensure that specific content is present.

describe "artist_card/1" do
test "showsthe artistnameand theiralbumcount" , %{ conn: conn} do
artist= generate(artist())
conn
|> visit( ~ p "/" )
|> assert_has(link( ~ p "/artists/#{ artist.id }" ))
|> refute_has( "span" , text:"0 albums" )
# Add an albumfor the artist
generate(album( artist_id: artist.id))
# Now it shouldsay thattheyhavean album
conn
|> visit( ~ p "/" )
|> assert_has(link( ~ p "/artists/#{ artist.id }" ))
|> assert_has( "span" , text:"1 album" )
end
end

24.https://hexdocs.pm/phoenix_test/
25.https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html

Testing Interfaces • 191

Testing Forms

We can also use PhoenixTest to find and fill out forms on LiveView pages.
Just like with testing other interfaces that call actions, you don’t necessarily
need to test every variation of input and errors, but generally you would want
to test at least one successful “happy” path and one unsuccessful “sad” path.
Any logic that is specific to a web UI, such as flash messages, is also a good
candidate to test here.

Here you can see multiple tests for the TunezWeb.Artists.FormLive module, showing
its behavior in different scenarios, such as when you attempt to access the
page without permission, or when successfully creating a new record.

describe "creatinga new artist" do
test "errorsfor forbiddenusers" , %{ conn: conn} do
assert_raise(Ash.Error.Forbidden.Policy, fn ->
conn
|> insert_and_authenticate_user()
|> visit( ~ p "/artists/new" )
end )
end
test "succeedswhenvaliddetailsare entered" , %{ conn: conn} do
conn
|> insert_and_authenticate_user( :admin )
|> visit( ~ p "/artists/new" )
|> fill_in( "Name" , with : "Temperance" )
|> click_button( "Save" )
|> assert_has(flash( :info ), text: "Artistsavedsuccessfully" )
assertget_by_name(Tunez.Music.Artist, "Temperance" )
end
# ...
end

We often find ourselves adding one or two helper functions like get_by_name,
shown in this code sample, to make testing a little bit easier. This function,
already defined in test/support/helpers.ex, builds a query and applies a filter, to
return either zero or one record:

def get_by_name(resource,name,opts\ []) do
resource
|> Ash.Query.for_read( :read , %{},opts)
|> Ash.Query.filter(name== ^name)
|> Ash.read_first!()
end

Chapter 7. All About Testing • 192

There are other tests for working with forms pre-prepared in the test/tunez_web/live
folder of the Tunez app, including for using the pagination, search, and sort
in the artist catalog.

And that’s a wrap! This was a whirlwind tour through all kinds of testing that
we might do in our application. There are a lot more tests available in the
Tunez repo (along with some that cover functionality that we haven’t built
yet), far too many to go over in this chapter.

All of the tools that Ash works with, like Phoenix and Absinthe, have their
own testing utilities and patterns that you’ll want to spend some time learning
as you go along. The primary takeaway is that you’ll get the most reward for
effort by doing your heavy and exhaustive testing at the resource layer.

Testing is a very important aspect of building any software, and that doesn’t
change when you’re using Ash. Tests are investments that pay off by helping
you understand your code and protect against unintentional change in the
future.

In the next chapter, we’ll switch back into writing some new features to
enhance our domain model. We’ll look at adding track listings for albums,
adding calculations for track and album durations, and learn how AshPhoenix
can help make building nested forms a breeze.

Testing Interfaces • 193

CHAPTER 8
