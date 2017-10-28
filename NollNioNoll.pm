package Bot::BasicBot::Pluggable::Module::NollNioNoll;

=head1 SYNOPSOS

Yet another perl bot with some examples

=head1 DESCRIPTION

You will need to run a process loading this module. See L<Bot::BasicBot::Pluggable>

=cut

$Bot::BasicBot::Pluggable::Module::NollNioNoll::VERSION = '1.0';

use warnings;
use strict;
use utf8;

use JSON;
use Mojo::UserAgent;
use Net::Twitter;
use YAML::XS;

use base qw( Bot::BasicBot::Pluggable::Module );

sub _module_config {
    my $self = shift;

    my $file = $ENV{'090_CONFIG'} // './config.yaml';

    if ( ! -e $file ) {
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

Package methods

=head2 init

Setup the bot

=cut

sub init {
    my $self = shift;

    $self->config( $self->_module_config );

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

A tick is called every five seconds. This method is used
to trigger recurrent events.

=cut

sub tick {
    my $self = shift;

    return 1;
}

=head2 told

Told is triggered on every priority 2 message. That is the
most common such as when someone is typing in the chat.

=cut

sub told {
    my ( $self, $message ) = @_;

    my $prefix = $self->get( 'prefix' );

    if ( $message->{body} =~/^\Q$prefix\E(\w+)\s?(.+)?$/ ) {
        my ( $action, $args ) = ( $1, $2 );
        my @args = split( /\s+/, $args // '' );

        my $method = $self->get( 'action_aliases' )->{ $action } // $action;

        if ( $self->can( $method ) ) {
            return $self->$method( $message, @args );
        }
    }

    my $url       = $self->is_url( $message->{body} );
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
        elsif ( $url =~ m!\.(jpe?g|png|gif|tiff)! ) {
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
    return if !$self->get( 'greet_on_chanjoin' );

    my @hello_phrases = @{ $self->get( 'greetings' ) };
    my $phrase        = $hello_phrases[ rand @hello_phrases ];

    $self->tell( $message->{channel}, sprintf( "%s %s! :)", $phrase, $message->{who} ) );

    return 1;
}

=head2 help

Return the help text for the bot

=cut

sub help {
    my ( $self, $message ) = @_;

    my @commands_to_show = qw(
        !wiki <text>
        !nip
        !temp <stad>
        !bible
        !lt <twitter-användare>
    );

    return sprintf(
        'Jag är bara en bot skapad av %s! Utöver att hälsa och kolla länkar jag kan du testa något av följande: %s.',
        $self->get( 'contact' ), join( ', ', @commands_to_show )
    );
}

=head2 is_url

Check if the body contains any URLs

=cut

sub is_url {
    my ( $self, $message ) = @_;

    my ( $url ) = $message =~ m|(https?://\S+)|;
    return if !$url;

    return $url;
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

=head1 ACTIONS

Different actions available via prefix and beloning methods

=head2 wikipeia

Search Wikipedia for a given subject.

  !wiki <subject> <language>
  !wiki London en

=cut

sub wikipedia {
    my ( $self, $message, @args ) = @_;

    my $language = $args[-1] =~ /^[a-z]{2}$/ ? pop @args : $self->get( 'wikipedia' )->{default_language};
    my $subject  = join( '_', @args );
    my $url      = sprintf( 'https://%s.wikipedia.org/w/api.php?action=query&prop=extracts&format=json&exintro=&titles=%s', $language, $subject );
    my $ua       = Mojo::UserAgent->new();
    my $result   = $ua->get( $url )->res->json;

    my $html = '';
    foreach my $id ( keys %{ $result->{'query'}->{'pages'} } ) {
        last if $id < 1;

        my $code = $result->{'query'}->{'pages'}->{$id}->{'extract'};
        last if !$code;

        $html = "<div>" . $code . "</div>";
    }

    if ( !$html ) {
        $self->tell( $message->{channel}, sprintf( "Hittade inget om %s", join( ' ', map { lc $_ } @args ) ) );

        return;
    }

    my $dom          = Mojo::DOM->new( $html );
    my $limit        = $self->get( 'wikipedia' )->{max_length};
    my $full_text    = $dom->at( 'div' )->all_text();
    $full_text       =~ s|\n| |g;

    my $text_content = substr( $full_text, 0, $limit );
    $text_content   .= "[...]" if length( $full_text ) > $limit;

    # Remove last sentence if text is trimmed
    my ( $short_text, $other_text ) = $text_content =~ /^([^\.]+\. )([^\.]+\.? )?/;

    if ( !$short_text && !$other_text ) {
        $self->tell( $message->{channel}, "Kunde inte hämta sidans innehåll..." );
        return;
    }

    my $ingress = $short_text =~ /^(För andra|For other)/ ? $other_text : $short_text;

    $self->tell( $message->{channel}, $ingress );

    return 1;
}

=head2 get_title

Return the title for a web page

=cut

sub get_title {
    my ( $self, $message, $url ) = @_;

    if ( $self->get( 'url_limit' ) ) {
        my $allowed_urls = join( '|', @{ $self->get( 'url_whitelist' ) } );
        my $allowed_re   = qr{https?://(\w+\.?)*\.?($allowed_urls)};

        return if $url !~ $allowed_re;
    }

    my $ua    = Mojo::UserAgent->new();
    my $title = $ua->max_redirects( 5 )->get( $url )->res->dom->at( 'title' )->text;

    return if !$title;

    if ( $title =~ /(?:(.+) by (.+) on Spotify|(.*), a song by (.*) on Spotify)/ ){
        my $name   = $1;
        my $artist = $2;

        my @url_parts      = split( /\//, $url );
        my ( $type, $uri ) = ( $url_parts[-2], $url_parts[-1] );
        my $copy_code      = sprintf( 'spotify:%s:%s', $type, $uri );

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

Get the tweet content for a twitter link

=cut

sub get_tweet {
    my ( $self, $message, %args ) = @_;

    my $twitter = Net::Twitter->new(
        traits              => [ qw(API::RESTv1_1 OAuth API::TwitterVision InflateObjects) ],
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
        $result = eval { $twitter->user_timeline( { screen_name => $args{user}, exclude_replies => 1 } )->[0] };
    }

    return if !$result;

    $self->tell( $message->{channel}, sprintf( '%s %s: %s', $result->user->screen_name, $result->relative_created_at, $result->text ) );

    return 1;
}

=head2 get_imdb

Get movie information from IMDb links

=cut

sub get_imdb {
    my ( $self, $message, $movie_id ) = @_;

    my $url    = sprintf( 'http://www.omdbapi.com/?apikey=%s&i=%s', $self->get( 'imdb' )->{api_key}, $movie_id );
    my $ua     = Mojo::UserAgent->new();
    my $result = $ua->get( $url )->res->json;

    return if $result->{Response} ne 'True';

    my $info   = sprintf('%s (%s). Metascore: %s, IMDb rating: %s', $result->{Title}, $result->{Year}, $result->{Metascore}, $result->{imdbRating});

    $self->tell( $message->{channel}, $info );

    return 1;
}

=head2 ninjas_in_pyjamas

Get schedule for NiP CS:GO team

=cut

sub ninjas_in_pyjamas {
    my ( $self, $message ) = @_;

    my $url    = sprintf( 'https://api.sportradar.us/csgo-t1/sv/teams/%s/schedule.json?api_key=%s', $self->get( 'nip' )->{team_id}, $self->get( 'nip' )->{api_key} );
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

        my ( $ss, $mm, $hh, $day, $month, $year, $zone ) = strptime( $time );
        my $scheduled = sprintf( '%04d-%02d-%02d %02d:%02d', $year + 1900, $month, $day, $hh, $mm );

        push @schedule, sprintf(
            '%s (%s) vs. %s (%s) - %s (%s) @ %s',
            $team_one_name, $team_one_country,
            $team_two_name, $team_two_country,
            $tournament, $venue,
            $scheduled
        );
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

    my $city = join( ' ', @args );

    my $url      = sprintf( 'https://api.openweathermap.org/data/2.5/weather?q=%s&units=metric&mode=json&APPID=%s', $city, $self->get( 'temperature' )->{api_key} );
    my $ua       = Mojo::UserAgent->new();
    my $result   = $ua->get( $url )->res->json;
    my $temp     = $result->{main}->{temp};
    my $humidity = $result->{main}->{humidity};
    my $wind     = $result->{wind}->{speed};

    if ( !$temp || !$humidity || !$wind ) {
        $self->tell( $message->{channel}, sprintf( 'Hittade inget väder för %s', $city ) );
        return;
    }

    $self->tell( $message->{channel}, sprintf( '%.2f grader, %d%% luftfuktughet och %.1f m/s vind i %s', $temp, $humidity, $wind, $city ) );

    return 1;
}

=head2 bible

Bible will print a random verse from the bible

=cut

sub bible {
    my ( $self, $message ) = @_;

    my $url = "http://labs.bible.org/api/?passage=random&type=json";
    my $ua  = Mojo::UserAgent->new();
    my $result = $ua->get( $url )->res->json->[0];

    my $verse = sprintf( "%s %d:%d: %s", $result->{bookname}, $result->{chapter}, $result->{verse}, $result->{text} );

    $self->tell( $message->{channel}, $verse );

    return 1;
}

=head2 image_recognition

Try to recognize what's in the image

=cut

sub image_recognition {
    my ( $self, $message, $url ) = @_;

    my $ua = Mojo::UserAgent->new();
    my $result = $ua->post(
        $self->get( 'clarifi' )->{api_url},
        { Authorization => sprintf( 'Key %s', $self->get( 'clarifi' )->{api_key} ) },
        json => { inputs => [ { data => { image => { url => $url } } } ] }
    )->res->json;

    return if !$result->{status}->{description} eq 'OK';

    my @keywords = ();
    foreach my $concept ( @{ $result->{outputs}->[0]->{data}->{concepts} } ) {
        next if $concept->{value} < 0.991;

        push @keywords, $concept->{name};
    }

    $self->tell( $message->{channel}, sprintf( 'Det här ser jag på bilden: %s', join( ', ', @keywords ) ) );

    return 1;
}

=head2 repost_check

If someone posts a link, make sure it's not a repost!
If it is, tell everyone!

=cut

sub repost_check {
    my ( $self, $message ) = @_;

    my ( $url ) = $message->{body} =~ m!(https?://\S+)!;

    # Normalize URL so it counts as same despide protocol or www prefix
    $url =~ s!https?://(www\.)?|/$!!;

    my $links = $self->_get_links();
    $self->_save_link( $url, $message->{who} );

    return if !$self->get( 'repost' )->{enable};

    if ( my $reposts = $links->{urls}->{ $url } ) {
        my $repost       = $reposts->[0];

        my $link_count   = scalar @$reposts;
        my $domain_count = $links->{domains}->{ $repost->{domain} };
        my $other_users  = { map { $_->{user} => 1 } @$reposts };

        my $summary      = $self->get( 'repost' )->{summary} ? sprintf(
            'Länken har postats %d gång(er) tidigare av följande användare: %s. Totalt %d länkar till %s',
            $link_count, join( ', ', keys %$other_users ), $domain_count, $repost->{domain}
        ) : '';

        $self->tell(
            $message->{channel},
            sprintf( 'REPOST! %s postade den där länken för %s sedan. %s',
                $repost->{user}, $self->_relative_time( $repost->{time} ), $summary
            )
        );

        return 1;
    }

    return;
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

        push @{ $links{urls}->{ $link } }, {
            time   => $time,
            user   => $user,
            domain => $domain
        };

        $links{domains}->{ $domain }++;
    }

    close $links_file;

    return \%links;
}

=head1 AUTHOR

Simon Sawet L<simon@sawert.se>

=cut

1;
