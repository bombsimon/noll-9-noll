# NollNioNoll

This is yet another perl bot based on
[Bot::BasicBot::Pluggable::Module](https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module).

When I started to learn about perl I used this base class to quickly get up and
running and learn to code. It was a great way to find new ways to solve problems
and experience different kind of APIs. So, here I am again with yet another perl
bot, years later...

## Usage

I cannot really see how anyone would like to use this, however if you just clone
this repository and modify it to your own bot, all you need to do is include
NollNioNoll.pm in your `PERL5LIB` and start the executable file.

```sh
090_CONFIG=/path/to/config.yaml PERL5LIB=/path/to/module perl noll9noll
```

By default this module is actually not loaded, however `Load` and `Auth`
is. To load this module, authenticate yourself and load it. For more information
see documentation for ```Bot::BasicBot::Pluggable::Module```

```text
/msg Noll9Noll !auth admin julia
/msg Noll9Noll !password julia <new-password>
/msg Noll9Noll !load NollNioNoll

# In the same channel as the bot, just use configured prefix

/say !w London
```

## Features

* Greet users when they join
* Fetch URL titles (for defined list of sites)
* Fetch user, date and tweet from Twitter links
* Fetch movie name and rating for iMDB links
* Fetch artist, title and print a copy-link for Spotify links
* Check URL reposts and statistics
* Create reminders (`!remind_me <interval> <unit> <task>`)
* Search Wikipedia (`!w <topic> [language]`)
* Get latest tweet from a user (`!lt <user>`)
* Get a random bible verse (`!bible`)
* Show NiPs upcomming CS:GO matches (`!nip`)
* Add Steam players to VAC watch and get PMed when they're being banned (`!vac
  <STEAM_0:X:XXXXXX>`)
* Get temperature for your city (`!temp <location>`)

## Dependencies

* `libxml2`
* `openssl-dev`
* CPAN modules, install with `cpanm .` (or your preferred way)
