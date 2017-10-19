# NollNioNoll

This is yet another perl bot based on [Bot::BasicBot::Pluggable::Module](https://metacpan.org/pod/Bot::BasicBot::Pluggable::Module).

When I started to learn about perl I used this base class to quickly get up and running and learn to code. It was a great way to find new ways to solve problems and experience different kind of APIs. So, here I am again with yet another perl bot, years later...

# Usage

I cannot really see how anyone would like to use this, however if you just clone this repository and modify it to your own bot, all you need to do is include NollNioNoll.pm in your ```PERL5LIB``` and start the executable file.

```
090_CONFIG=./config PERL5LIB=. perl noll9noll
```

By default this module is actually not loaded, however ```Load``` and ```Auth``` is. To load this module, authenticate yourself and load it. For more information see documentation for ```Bot::BasicBot::Pluggable::Module```

```
/msg Noll9Noll !auth admin julia
/msg Noll9Noll !load NollNioNoll

# In the same channel as the bot, just use configured prefix

/say !w London
```

# Features

* Greet users when they join
* Search Wikipedia
* Get latest Tweet from a user
* Get a random bible verse
* Fetch URL titles
* Fetch unique information for some URLs (Twitter, iMDB, Wikipedia, Spotify)
* Check URL reposts and statistics
* Show NiPs upcomming CS:GO matches
* Get temperature for your city
