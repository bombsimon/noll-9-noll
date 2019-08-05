package Bot::BasicBot::Pluggable::Module::NollNioNoll;

=head1 SYNOPSOS

Yet another perl bot with some examples

=head1 DESCRIPTION

You will need to run a process loading this module. See
L<Bot::BasicBot::Pluggable>

=cut

$Bot::BasicBot::Pluggable::Module::NollNioNoll::VERSION = '1.0';

use warnings;
use strict;
use utf8;

use DateTime::Format::Strptime qw( strptime );
use JSON;
use Mojo::UserAgent;
use Net::Twitter;
use YAML::XS;

use base qw( Bot::BasicBot::Pluggable::Module );

sub _module_config {
    my $self = shift;

    my $file = $ENV{'090_CONFIG'} // './config.yaml';

    if ( !-e $file ) {
        warn 'Could not load any configuration';
        return {};
    }

    open my $fh, '<', $file || die 'Could not open file: ' . $!;
    my @content = <$fh>;
    close $fh;

    my $config = YAML::XS::Load( join( '', @content ) );

    return $config;
}

=head1 METHODS

Methods found in this pacakge. All methods are documented, even the internal
once. This is to get a better overview of what the bot actually does. =head1
CORE

Core methods overridden to fulful the L<Bot::BasicBot::Pluggable> interface

=head2 init

Setup the bot

=cut

sub init {
    my $self = shift;

    my @preserve_keys     = qw( reminders );
    my %preserve_keys_map = map { $_ => 1 } @preserve_keys;
    my @store_keys        = grep { not $preserve_keys_map{$_} } $self->store_keys;

    # Always reload full store
    $self->unset( $_ ) for @store_keys;

    $self->config( $self->_module_config );

    $self->set( 'dow' => DateTime->now()->day_of_week );

    return 1;
}

=head2 tell

Override tell method if special handling is needed like encoding

=cut

sub tell {
    my ( $self, $where, $body ) = @_;

    $self->SUPER::tell( $where, $body );
}

=head2 tick

A tick is called every five seconds. This method is used to trigger recurrent
events.

=cut

sub tick {
    my $self = shift;

    # Check each time
    my $current_reminders = $self->get( 'reminders' );
    my @reminders_not_due = ();

    while ( my $item = shift @$current_reminders ) {
        if ( $item->{when} < DateTime->now( time_zone => 'local' )->set_time_zone( 'floating' )->epoch() ) {
            $self->tell( $item->{where},
                sprintf( "%s: I was supposed to remind you now - '%s'", $item->{who}, $item->{what} ),
            );
        }
        else {
            push @reminders_not_due, $item;
        }
    }

    # Restore reminders not due yet.
    $current_reminders->push( $_ ) for @reminders_not_due;

    # Check at interval
    my $tick_interval  = 5;    # This method is called every 5 seconds
    my $ticks_passed   = $self->get( 'ticks' ) // 0;
    my $seconds_passed = $ticks_passed * $tick_interval;

    # One minute
    if ( $seconds_passed % 60 == 0 ) {
    }

    # Every five minutes
    elsif ( $seconds_passed % 300 == 0 ) {
    }

    # Every 30 minutes
    elsif ( $seconds_passed % 1800 == 0 ) {
    }

    # One hour
    elsif ( $seconds_passed % 3600 == 0 ) {
        $self->check_vac_watch();
    }

    # 720 ticks == 1 hour (720 * 5 = 3600 )
    if ( $ticks_passed == 720 ) {
        $self->set( 'ticks' => 1 );
    }

    # New day
    if ( $self->_day_changed ) {
    }

    $self->set( 'ticks' => ++$ticks_passed );
    $self->set( 'dow'   => DateTime->now()->day_of_week )
      if DateTime->now()->second > 30;

    return 1;
}

=head2 told

Told is triggered on every priority 2 message. That is the most common such as
when someone is typing in the chat.

=cut

sub told {
    my ( $self, $message ) = @_;

    my $prefix = $self->get( 'prefix' );

    if ( $message->{body} =~ /^\Q$prefix\E(\w+)\s?(.+)?$/ ) {
        my ( $action, $args ) = ( $1, $2 );
        my @args = split( /\s+/, $args // '' );

        my $method = lc( $self->get( 'action_aliases' )->{$action} // $action );

        if ( $self->can( $method ) ) {
            return $self->$method( $message, @args );
        }
    }

    my $url       = $self->_is_url( $message->{body} );
    my $is_repost = $url ? $self->repost_check( $message ) : 0;

    if ( $url && !$is_repost ) {
        if ( $url =~ m!twitter\.com/[^/]+/status/(\d+)! ) {
            my $tweet_id = $1;
            $self->get_tweet( $message, id => $tweet_id );
        }
        elsif ( $url =~ m!imdb.*(tt\d+)! ) {
            my $movie_id = $1;
            $self->get_imdb( $message, $movie_id );
        }
        elsif ( $url =~ m!(\w+)\.wikipedia\.org/wiki/(\S+)! ) {
            my ( $language, $page ) = ( $1, $2 );
            $self->wikipedia( $message, $page, $language );
        }
        elsif ( $url =~ m!\.(jpe?g|png|gif|tiff)!i ) {
            $self->image_recognition( $message, $url );
        }
        else {
            $self->get_title( $message, $url );
        }
    }

    return 1;
}

=head2 chanjoin

Chanjoin is called everytime someone joins the channel.

=cut

sub chanjoin {
    my ( $self, $message ) = @_;

    return if $message->{who} eq $self->bot->nick;
    return if !$self->get( 'greeting' )->{enabled};

    my @hello_phrases = @{ $self->get( 'greeting' )->{greetings} };
    my $phrase        = $hello_phrases[ rand @hello_phrases ];

    $self->tell( $message->{channel}, sprintf( "%s %s! :)", $phrase, $message->{who} ) );

    return 1;
}

=head1 HELPERS

Helper methods for internal usage

=head2 _is_url

Check if the body contains any URLs

=cut

sub _is_url {
    my ( $self, $message ) = @_;

    my ( $url ) = $message =~ m|(https?://\S+)|;
    return if !$url;

    return $url;
}

=head2 _user_online

Check if a given user is online

=cut

sub _user_online {
    my ( $self, $user ) = @_;

    my @channels = $self->bot->channels;
    foreach my $channel ( @channels ) {
        my $channel_data = $self->bot->channel_data( $channel );

        return 1 if $channel_data->{$user};
    }

    return;
}

=head2 _day_changed

Check if the day has changed. We will set the day of week each tick if we're
passed 30 seconds on the clock. This means we should get at least 5 ticks before
we recognize a new day!

=cut

sub _day_changed {
    my $self = shift;

    return $self->get( 'dow' ) != DateTime->now()->day_of_week;
}

=head2 _relative_time

Calculate relative time based on unix timestamp

=cut

sub _relative_time {
    my ( $self, $time ) = @_;

    my $now      = time;
    my $timediff = $now - $time;

    if ( $timediff < 60 ) {
        return 'mindre än en minut sedan';
    }
    elsif ( $timediff < 120 ) {
        return 'typ en minut';
    }
    elsif ( $timediff < 45 * 60 ) {
        return sprintf( '%d minuter', int( $timediff / 60 ) );
    }
    elsif ( $timediff < 90 * 60 ) {
        return 'typ en timme';
    }
    elsif ( $timediff < 24 * 60 * 60 ) {
        return sprintf( '%d timmar', int( $timediff / 3600 ) );
    }
    elsif ( $timediff < 48 * 60 * 60 ) {
        return 'en dag';
    }
    else {
        return sprintf( '%d dagar', int( $timediff / 86400 ) );
    }

    return 'okänd tid';
}

=head2 _id_to_64

Convert a SteamID to ID64 format

=cut

sub _id_to_64 {
    my ( $self, $id ) = @_;

    my $identifier = 76561197960265728;

    my ( $auth, $steam_id ) = split( /:/, $id );

    return $identifier + ( ( $steam_id * 2 ) + $auth );
}

=head2 _save_link

Save a new link each time someone posts a link

=cut

sub _save_link {
    my ( $self, $url, $user ) = @_;

    my ( $domain ) = $url =~ m!^([^/]+)!;

    open my $links_file, '>>', $self->get( 'repost' )->{link_file};
    print $links_file sprintf( "%s %s %s %s\n", time, $user, $domain, $url );
    close $links_file;

    return 1;
}

=head2 _get_links

Get all links and domain count posted

=cut

sub _get_links {
    my $self = shift;

    my %links = ();

    open my $links_file, '<', $self->get( 'repost' )->{link_file};

    while ( my $line = <$links_file> ) {
        chomp $line;

        my ( $time, $user, $domain, $link ) = split( /\s+/, $line );

        push @{ $links{urls}->{$link} },
          {
            time   => $time,
            user   => $user,
            domain => $domain
          };

        $links{domains}->{$domain}++;
    }

    close $links_file;

    return \%links;
}

=head2 _notify_users_vac

Notify users when someone is banned

=cut

sub _notify_users_vac {
    my ( $self, $to_notify ) = @_;

    while ( my ( $user, $bans ) = each %$to_notify ) {
        my @ban_info = ();
        foreach my $ban ( @$bans ) {
            push @ban_info,
              sprintf( '%s (tillagd %s sedan)', $ban->{username}, $self->_relative_time( $ban->{added} ) );
        }

        $self->tell( $user,
            sprintf( 'Ny VAC ban! Följande spelare är nu bannad: %s', join( ', ', @ban_info ) ) );
    }

    return 1;
}

=head2 _get_steam_status

Poll player profile and ban status from Steam

=cut

sub _get_steam_status {
    my ( $self, $player_id ) = @_;

    my $player_url
      = sprintf( $self->get( 'steam' )->{profile_url}, $self->get( 'steam' )->{api_key}, $player_id );
    my $bans_url = sprintf( $self->get( 'steam' )->{bans_url}, $self->get( 'steam' )->{api_key}, $player_id );

    my $ua     = Mojo::UserAgent->new();
    my $player = $ua->get( $player_url )->res->json->{response}->{players}->[0];
    my $bans   = $ua->get( $bans_url )->res->json->{players}->[0];

    return ( $player, $bans );
}

=head2 _update_vac_watch

Add players to the banlist

=cut

sub _update_vac_watch {
    my ( $self, $players, $reset ) = @_;

    my $current_listing = $reset ? {}  : $self->_get_player_watch();
    my $file_operand    = $reset ? '>' : '>>';

    open my $file, $file_operand, $self->get( 'steam' )->{ban_file};
    foreach my $user ( keys %$players ) {
        foreach my $steam_id ( keys %{ $players->{$user} } ) {

            # Don't add same player twice for a user
            next if $current_listing->{$user}->{$steam_id};

            my $player = $players->{$user}->{$steam_id};

            print $file sprintf( "%s %d %d %s %s %s\n",
                $user, $steam_id, $player->{added}, $player->{username}, $player->{banned},
                $player->{days_since_ban} );
        }
    }
    close $file;

    return 1;
}

=head2 _get_player_watch

Get all watched players

=cut

sub _get_player_watch {
    my $self = shift;

    my %ban_watch = ();

    open my $file, '<', $self->get( 'steam' )->{ban_file};
    while ( my $line = <$file> ) {
        chomp $line;

        my ( $user, $id64, $player_added, $player_username, $player_banned, $player_days_since_ban )
          = split( /\s+/, $line );

        $ban_watch{$user}->{$id64} = {
            added          => $player_added,
            username       => $player_username,
            banned         => $player_banned,
            days_since_ban => $player_days_since_ban
        };
    }
    close $file;

    return \%ban_watch;
}

=head2 _imdb_omdb

Get IMDb info with OMDB API

=cut

sub _imdb_omdb {
    my ( $self, $movie_id ) = @_;

    my $url = sprintf( $self->get( 'imdb' )->{omdbapi}->{api_url},
        $self->get( 'imdb' )->{omdbapi}->{api_key}, $movie_id );
    my $ua     = Mojo::UserAgent->new();
    my $result = $ua->get( $url )->res->json;

    return if !$result;
    return if !$result->{Response};
    return if $result->{Response} ne 'True';

    return {
        title => $result->{Title},
        year  => $result->{Year},
        score => $result->{imdbRating}
    };
}

=head2 _imdb_movie_db

Get IMDb info with movie db API

=cut

sub _imdb_movie_db {
    my ( $self, $movie_id ) = @_;

    my $url    = sprintf( $self->get( 'imdb' )->{movie_db}->{api_url}, $movie_id );
    my $ua     = Mojo::UserAgent->new();
    my $result = $ua->get( $url )->res->json;

    return if $result->{error};

    return {
        title => $result->{data}->{name},
        year  => $result->{data}->{year},
        score => $result->{data}->{rating}
    };
}

=head1 ACTIONS

Different actions available via prefix and beloning methods

=head2 help

Return the help text for the bot

=cut

sub help {
    my ( $self, $message ) = @_;

    my @commands_to_show = (
        '!wiki <text>',
        '!nip',
        '!temp <stad>',
        '!bible',
        '!lt <twitter-användare>',
        '!vac <STEAM_0:X:XXXXXX>'
    );

    return sprintf(
'Jag är bara en bot skapad av %s! Utöver att hälsa och kolla länkar jag kan du testa något av följande: %s.',
        $self->get( 'contact' ),
        join( ', ', @commands_to_show )
    );
}

=head2 add_vac_watch

Let a user post SteamIDs and I will watch those profile and notify the user if
the player gets a ban!

=cut

sub add_vac_watch {
    my ( $self, $message, @args ) = @_;

    my ( @ids ) = $message->{body} =~ /STEAM_\d:((?:\d+):(?:\d+))/g;

    my %players   = ();
    my @usernames = ();
    my $ua        = Mojo::UserAgent->new();

    foreach my $id ( @ids ) {
        my $id64 = $self->_id_to_64( $id );

        my ( $player, $bans ) = $self->_get_steam_status( $id64 );
        next if !$player;

        $players{ $message->{who} }->{$id64} = {
            username       => $player->{personaname},
            banned         => $bans->{VACBanned},
            days_since_ban => $bans->{DaysSinceLastBan},
            added          => time
        };

        push @usernames, $player->{personaname};
    }

    $self->_update_vac_watch( \%players );

    $self->tell( $message->{channel},
        sprintf( 'La till dessa spelare på watchlist: %s', join( ', ', @usernames ) ) );

    return 1;
}

=head2 check_vac_watch

Check the current bans and if a new player has received a ban.

=cut

sub check_vac_watch {
    my $self = shift;

    my %to_notify   = ();
    my $player_bans = $self->_get_player_watch();

  USER: foreach my $user ( keys %$player_bans ) {
      PLAYER: foreach my $steam_id ( keys %{ $player_bans->{$user} } ) {
            my $watching = $player_bans->{$user}->{$steam_id};

            # Don't re-check banned players!
            next PLAYER if $watching->{banned} == 1;

            # No need to check if the user watching is offline (cannot PM)
            next USER if !$self->_user_online( $user );

            my ( $player, $bans ) = $self->_get_steam_status( $steam_id );

            next PLAYER if !$bans->{VACBanned};

            $watching->{banned}         = 1;
            $watching->{days_since_ban} = $bans->{DaysSinceLastBan};

            push @{ $to_notify{$user} }, $watching;
        }
    }

    $self->_notify_users_vac( \%to_notify );
    $self->_update_vac_watch( $player_bans, 1 );

    return 1;
}

=head2 wikipeia

Search Wikipedia for a given subject.

  !wiki <subject> <language>
  !wiki London en

=cut

sub wikipedia {
    my ( $self, $message, @args ) = @_;

    my $language
      = $args[-1] =~ /^[a-z]{2}$/
      ? pop @args
      : $self->get( 'wikipedia' )->{default_language};
    my $subject = join( '_', @args );
    my $url     = sprintf( $self->get( 'wikipedia' )->{api_url}, $language, $subject );
    my $ua      = Mojo::UserAgent->new();
    my $result  = $ua->get( $url )->res->json;

    my ( $extract, $title, $source, $disambiguous, @links );
    foreach my $id ( keys %{ $result->{query}->{pages} } ) {
        my $page = $result->{query}->{pages}->{$id};

        last if exists $page->{missing};

        $extract      = $page->{extract} =~ s/\n|\r/ /gr;
        $title        = $page->{title};
        $disambiguous = exists $page->{pageprops}->{disambiguation};

        if ( $disambiguous ) {
            @links = map { $_->{title} } @{ $page->{links} };
        }
    }

    if ( !$extract ) {
        $self->tell( $message->{channel}, sprintf( "Hittade inget om %s", join( ' ', map { lc $_ } @args ) ) );

        return;
    }

    if ( $result->{query}->{redirects} ) {
        $source = $result->{query}->{redirects}->[0]->{from};
    }

    $self->tell(
        $message->{channel},
        sprintf( '%s %s %s',
            $extract,
            $source ? sprintf( '(Från artikeln "%s", omdirigerad från "%s")', $title, $source ) : '',
            $disambiguous ? join( ', ', @links ) : '' )
    );

    return 1;
}

=head2 get_title

Return the title for a web page

=cut

sub get_title {
    my ( $self, $message, $url ) = @_;

    if ( $self->get( 'url_title' )->{limit} ) {
        my $allowed_urls = join( '|', @{ $self->get( 'url_title' )->{whitelist} } );
        my $allowed_re   = qr{https?://(\w+\.?)*\.?($allowed_urls)};

        return if $url !~ $allowed_re;
    }

    my $ua    = Mojo::UserAgent->new();
    my $title = $ua->max_redirects( 5 )->get( $url )->res->dom->at( 'title' )->text;

    $title =~ s/^\s+|\s+$|\r|\n//g;
    return if !$title;

    if ( $title =~ /(?:(.+) (?:(?!song).)*by (.+) on Spotify|(.+), a song by (.+) on Spotify)/ ) {
        my $name   = $1 // $3;
        my $artist = $2 // $4;

        my @url_parts = split( /\//, $url );
        my ( $type, $uri ) = ( $url_parts[-2], $url_parts[-1] );
        my $copy_code = sprintf( 'spotify:%s:%s', $type, $uri );

        $title = sprintf( '%s - %s | %s', $artist, $name, $copy_code );
    }

    $self->tell( $message->{channel}, $title );

    return 1;
}

=head2 latesttweet

Return the latest tweet from a user

=cut

sub latesttweet {
    my ( $self, $message, $username ) = @_;

    return if !$username;

    return $self->get_tweet( $message, user => $username );
}

=head2 get_tweet

Get the tweet content for a twitter link or by username

  $self->get_tweet( $message, id => 1234567890 );      # Get by id (found in URL)
  $self->get_tweet( $message, user => 'GoogleFacts' ); # Get the latest tweet from GoogleFacts

=cut

sub get_tweet {
    my ( $self, $message, %args ) = @_;

    my $twitter = Net::Twitter->new(
        traits              => [qw(API::RESTv1_1 OAuth API::TwitterVision InflateObjects)],
        consumer_key        => $self->get( 'twitter' )->{consumer_key},
        consumer_secret     => $self->get( 'twitter' )->{consumer_secret},
        access_token        => $self->get( 'twitter' )->{access_token},
        access_token_secret => $self->get( 'twitter' )->{access_token_secret},
        ssl                 => 1,
    );

    my $result;
    if ( $args{id} ) {
        $result = eval { $twitter->show_status( { id => $args{id} } ) };
    }
    elsif ( $args{user} ) {
        $result
          = eval { $twitter->user_timeline( { screen_name => $args{user}, exclude_replies => 1 } )->[0]; };
    }

    return if !$result;

    my $tweet = $result->text =~ s/\n|\r//gr;

    $self->tell( $message->{channel},
        sprintf( '%s %s: %s', $result->user->screen_name, $result->relative_created_at, $tweet ) );

    return 1;
}

=head2 get_imdb

Get movie information from IMDb links

=cut

sub get_imdb {
    my ( $self, $message, $movie_id ) = @_;

    my $func   = sprintf( '_imdb_%s', $self->get( 'imdb' )->{source} );
    my $result = $self->$func( $movie_id );

    return if !$result;
    return if !$result->{title};

    my $info = sprintf( '%s (%s). IMDb rating: %s', $result->{title}, $result->{year}, $result->{score} );

    $self->tell( $message->{channel}, $info );

    return 1;
}

=head2 ninjas_in_pyjamas

Get schedule for NiP CS:GO team

=cut

sub ninjas_in_pyjamas {
    my ( $self, $message ) = @_;

    my $url = sprintf( $self->get( 'nip' )->{api_url}, $self->get( 'nip' )->{team_id},
        $self->get( 'nip' )->{api_key} );
    my $ua     = Mojo::UserAgent->new();
    my $result = $ua->get( $url )->res->json;

    my @schedule = ();
    foreach my $game ( @{ $result->{schedule} } ) {
        my $tournament       = $game->{tournament}->{name};
        my $venue            = $game->{venue}->{name};
        my $team_one_name    = $game->{competitors}->[0]->{name};
        my $team_one_country = $game->{competitors}->[0]->{country};
        my $team_two_name    = $game->{competitors}->[1]->{name};
        my $team_two_country = $game->{competitors}->[1]->{country};
        my $time             = $game->{scheduled};

        my $datetime  = strptime( '%Y-%m-%dT%H:%M:%S%z', $time );
        my $scheduled = sprintf( '%s %s', $datetime->ymd, $datetime->hms );

        push @schedule,
          sprintf( '%s (%s) vs. %s (%s) - %s (%s) @ %s',
            $team_one_name, $team_one_country, $team_two_name, $team_two_country, $tournament, $venue,
            $scheduled );
    }

    if ( !@schedule ) {
        $self->tell( $message->{channel}, 'Inga planerade matcher för NiP' );
        return;
    }

    foreach my $game ( @schedule ) {
        $self->tell( $message->{channel}, $game );
    }

    return 1;
}

=head2 temperature

Get the temperature for desired city

=cut

sub temperature {
    my ( $self, $message, @args ) = @_;

    my $city        = join( ' ', @args );
    my $search_word = lc $city;
    $search_word =~ s/å|ä/a/g;
    $search_word =~ s/ö/o/g;
    $search_word =~ s/ü/u/g;

    my $url = sprintf( $self->get( 'temperature' )->{api_url}, $search_word,
        $self->get( 'temperature' )->{api_key} );
    my $ua       = Mojo::UserAgent->new();
    my $result   = $ua->get( $url )->res->json;
    my $temp     = $result->{main}->{temp};
    my $humidity = $result->{main}->{humidity};
    my $wind     = $result->{wind}->{speed};

    if ( !defined $temp || !defined $humidity || !defined $wind ) {
        if ( defined $temp ) {
            $self->tell( $message->{channel}, sprintf( '%.2f grader i %s', $temp, $city ) );
            return 1;
        }

        $self->tell( $message->{channel}, sprintf( 'Hittade inget väder för %s', $city ) );
        return;
    }

    $self->tell( $message->{channel},
        sprintf( '%.2f grader, %d%% luftfuktighet och %.1f m/s vind i %s', $temp, $humidity, $wind, $city ) );

    return 1;
}

=head2 bible

Bible will print a random verse from the bible

=cut

sub bible {
    my ( $self, $message ) = @_;

    my $ua     = Mojo::UserAgent->new();
    my $result = $ua->get( $self->get( 'bible' )->{api_url} )->res->json->[0];

    my $verse
      = sprintf( "%s %d:%d: %s", $result->{bookname}, $result->{chapter}, $result->{verse}, $result->{text} );

    $self->tell( $message->{channel}, $verse );

    return 1;
}

=head2 image_recognition

Try to recognize what's in the image

=cut

sub image_recognition {
    my ( $self, $message, $url ) = @_;

    return if !$self->get( 'clarifai' )->{enable};

    my $ua     = Mojo::UserAgent->new();
    my $result = $ua->post(
        $self->get( 'clarifai' )->{api_url},
        { Authorization => sprintf( 'Key %s', $self->get( 'clarifai' )->{api_key} ) },
        json => { inputs => [ { data => { image => { url => $url } } } ] }
    )->res->json;

    return if !$result->{status}->{description} eq 'OK';

    my @keywords = ();
    foreach my $concept ( @{ $result->{outputs}->[0]->{data}->{concepts} } ) {
        next if $concept->{value} < $self->get( 'clarifai' )->{min_match};

        push @keywords, $concept->{name};
    }

    return if !@keywords;

    $self->tell(
        $message->{channel},
        sprintf( 'Jag är helt jävla säker (a.k.a. killgissar) att detta finns i bilden: %s',
            join( ', ', @keywords ) )
    );

    return 1;
}

=head2 repost_check

If someone posts a link, make sure it's not a repost! If it is, tell everyone!

=cut

sub repost_check {
    my ( $self, $message ) = @_;

    my ( $url ) = $message->{body} =~ m!(https?://\S+)!;

    # Normalize URL so it counts as same despide protocol or www prefix
    $url =~ s!https?://(www\.)?|/$!!;

    my $links = $self->_get_links();
    $self->_save_link( $url, $message->{who} );

    return if !$self->get( 'repost' )->{enable};

    if ( my $reposts = $links->{urls}->{$url} ) {
        my $repost = $reposts->[0];

        my $link_count   = scalar @$reposts;
        my $domain_count = $links->{domains}->{ $repost->{domain} };
        my $other_users  = { map { $_->{user} => 1 } @$reposts };

        my $summary
          = $self->get( 'repost' )->{summary}
          ? sprintf(
            'Länken har postats %d gång(er) tidigare av följande användare: %s. Totalt %d länkar till %s',
            $link_count, join( ', ', keys %$other_users ),
            $domain_count, $repost->{domain}
          )
          : '';

        $self->tell(
            $message->{channel},
            sprintf(
                'REPOST! %s postade den där länken för %s sedan. %s',
                $repost->{user}, $self->_relative_time( $repost->{time} ), $summary
            )
        );

        return 1;
    }

    return;
}

=head3 remind_me

Remind a user after a given interval of something.

=cut

sub remind_me {
    my ( $self, $message ) = @_;

    my ( $interval, $unit, $what ) = $message->{body} =~ /^(?:\S+) (\d+) (\S+) (.+)$/;

    return if !( $interval && $unit && $what );

    my $dt = DateTime->now( time_zone => 'local' )->set_time_zone( 'floating' );
    $dt->add( days    => $interval ) if $unit =~ /^days?|dag(ar)?$/i;
    $dt->add( hours   => $interval ) if $unit =~ /^hours?|timmar|timme$/i;
    $dt->add( minutes => $interval ) if $unit =~ /^minutes?|minut(er)?$/i;
    $dt->add( seconds => $interval ) if $unit =~ /^seconds?|sekund(er)?$/i;

    return if $dt == DateTime->now(); # Nothing added, bad unit?

    my $current_reminders = $self->get( 'NollNioNoll', 'reminders' );

    push @$current_reminders,
      {
        what  => $what,
        when  => $dt->epoch(),
        where => $message->{channel},
        who   => $message->{who},
      };

    $self->set( 'reminders', $current_reminders );

    $self->tell( $message->{channel}, sprintf( 'Wil remind you about %s at %s', $what, $dt->iso8601() ), );

    return 1;
}

=head1 AUTHOR

Simon Sawet L<simon@sawert.se>

=cut

1;
