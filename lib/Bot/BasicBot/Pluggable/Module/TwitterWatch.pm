package Bot::BasicBot::Pluggable::Module::TwitterWatch;

use strict;
use base 'Bot::BasicBot::Pluggable::Module';
use Net::Twitter::Lite;
use Data::Dump;

our $VERSION = '0.01';

=head1 NAME

Bot::BasicBot::Pluggable::Module::TwitterWatch - report new tweets matching given search patterns

=head1 DESCRIPTION

Watches Twitter for tweets matching given search patterns, and reports them.


=head1 SYNOPSIS

Load the module as with any other Bot::BasicBot::Pluggable module, then tell it
what to monitor - use these commands within a channel:

  !twitterwatch search term here
  !twitterunwatch search term here
  !twittersearches

Each channel has its own just of searches stored.

=cut

sub said {
    my ($self, $mess, $pri) = @_;
    return unless $pri == 2;

    my $message;
    if (my($command, $params) = $mess->{body} =~ /!(twitter\w+) (.+)/i) {
        $params = lc $params;
        my $searches = $self->get('twitter_searches') || {};
        $searches->{ lc $mess->{channel} } ||= {};
        my $chansearches = $searches->{ lc $mess->{channel} };

        if (lc $command eq 'twitterwatch') {
            $chansearches->{$params} = time;
            $message =  "OK, now watching for '$params'";
        } elsif (lc $command eq 'twitterunwatch') {
            if (exists $chansearches->{$params}) {
                delete $chansearches->{$params};
                $message = "OK, no longer watching for '$params'";
            } else {
                $message = "I wasn't watching for '$params'.";
            }
        } elsif (lc $command eq 'twittersearches') {
            $message = "Currently watching for: "
                . join ',', map { qq["$_"] } keys %$chansearches;
        }
   
    $self->set('twitter_searches', $searches);

    warn "Searches after command: " . Data::Dump::dump($searches);
    return $message;
    }
}

# Tick is called automatically every 5 seconds
sub tick {
    my $self = shift;
    warn "tick() called";
    my $seconds_between_checks = $self->get('twitter_search_wait') || 30;
    return if time - $self->get('twitter_last_searched') 
        < $seconds_between_checks;

    # OK, time to do the searches:
    my $twitter = Net::Twitter::Lite->new;
    my $searches = $self->get('twitter_searches');

    warn "Search settings: " . Data::Dump::dump($searches);
    for my $channel (keys %$searches) {
        warn "Doing searches for $channel";
        my @results;
        for my $searchterm (keys %{ $searches->{$channel} }) {
            my $last_id = $searches->{$channel}{$searchterm} || 0;
            warn "Searching for '$searchterm' after $last_id on behalf of $channel";
            my $results = $twitter->search({
                q        => $searchterm,
                since_id => $last_id,
            }) or return;

            for my $result (
                grep { $_->{id} > $last_id } @{ $results->{results} }
            ) {
                push @results, sprintf 'Twitter: @%s: "%s"',
                    $result->{from_user}, $result->{text};
            }

            # Remember the ID of the highest match
            $searches->{$channel}{$searchterm} = $results->{max_id};
        }


        # TODO: probably check if we found too many results to sensibly relay
        for my $result (@results) {
            $self->say(channel => $channel, body => $result);
        }
    }
    
    $self->set('twitter_last_searched', time);
    $self->set('twitter_searches', $searches);
            
}



=head1 AUTHOR

David Precious, C<< <davidp at preshweb.co.uk> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-bot-basicbot-pluggable-module-twitterwatch at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Bot-BasicBot-Pluggable-Module-TwitterWatch>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Bot::BasicBot::Pluggable::Module::TwitterWatch


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Bot-BasicBot-Pluggable-Module-TwitterWatch>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Bot-BasicBot-Pluggable-Module-TwitterWatch>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Bot-BasicBot-Pluggable-Module-TwitterWatch>

=item * Search CPAN

L<http://search.cpan.org/dist/Bot-BasicBot-Pluggable-Module-TwitterWatch/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 David Precious.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Bot::BasicBot::Pluggable::Module::TwitterWatch
