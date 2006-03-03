package WWW::Search::TheITJobBoard;
our $VERSION = '0.02';
our $DEBUG   = 0;
our $MAINTAINER = 'Lee Goddard <lgoddard -at- cpan -dot- org';

our $WIN = ($^O =~ /Win/g); # For the Win32 bug

use strict;
use warnings;

use base 'WWW::Search';

use WWW::SearchResult;
use HTML::TokeParser;

=head1 NAME

WWW::Search::TheITJobBoard - search www.TheITJobBoard.co.uk

=head1 SYNOPSIS

	use WWW::Search::TheITJobBoard;
	use Data::Dumper;
	my $oSearch = WWW::Search->new('TheITJobBoard', _debug=>undef);
	$oSearch->native_query(
		WWW::Search::escape_query("perl"),
		{
			jobtype => 0,
		}
	);
	while (my $oResult = $oSearch->next_result){
		warn Dumper $oResultr;
	}



=head1 DESCRIPTION

Gets jobs from the UK IT job site, I<The IT Job Board>.

A sub-class of L<WWW::Search> that uses L<HTML::TokeParser> to return C<WWW::SearchResult> objects
for each result found when querying C<www.theitjobboard.co.uk>.

At the time of writing, valid options for The IT Job Board are as follows:

=over 4

=item keywords

THe keywords your target job description should contain. Default is C<perl>, of course.

=item jobtype

Valid values are: C<1> for contract (our default), C<2> for permenant, and C<0> for either.

=item days

The age of the posting, in days, according to the site's records. A value of C<0> represents any age.
Our default is C<1>.

=item orderby

Not especially relevant for us: valid values are C<1> to order by relevance to the keywords;
C<2> to order by date posted; C<3> orders by salary; C<4> puts non-agency jobs first, which is the default.

=item locations[]

Ugly variable name. Default is to return all jobs, regardless. Valid values are:
C<undef> to return all jobs;
C<180> for UK, C<124> for Netherlands, C<93> for Germany, C<69> for France,
C<308> for Switzerland, C<170> for Republic Of Ireland, C<3> for Austria, C<301> for 'the rest Of the world,'
C<254> for 'other European.'

=item currpage

The number of the page to start at, indexed from C<1>.

=item lang

Defaults to C<en> for English, but you could try other two-letter ISO codes.

=back

=head1 DEPENDENCIES

L<WWW::Search>, L<HTML::TokeParser>.

=head1 BUGS

Frankly, this is a quick first-stab at L<WWW::Search> sub-classing and this module. It passes the
basic test, which is enough for my needs today, and as far as I can see, it conforms with L<WWW:Search>
requirements. But please send bug reports via CPAN.

=cut

# "native_setup_search()" is invoked before the search. It is passed a
# single argument: the escaped, native version of the query.
# http://www.theitjobboard.co.uk/index.php?keywords=HTML&locations%5B%5D=&jobtype=1&days=2&orderby=3&submit=Search&task=JobSearch&xc=0&lang=en
# Blx, it takes opts too

=head2 METHOD native_setup_search

Sets up default search parameters. B<NOTE> that the first argument is the same as the option C<keywords: see
L<DESCRIPTION>, above.

=cut

sub native_setup_search { my ($self, $native_query, $opts) = (shift, shift, shift);
	$self->user_agent('non-robot');
	$self->{_hits_per_page} 			= 100;
	$self->{_next_to_retrieve} 			= 1;
	$self->{search_base_url} 			||= 'http://www.theitjobboard.co.uk';
	$self->{search_base_path} 			||= '/index.php';
	$self->{search_url}					||= $self->{search_base_url} . $self->{search_base_path};
	$self->{_options}->{keywords}		||= $native_query || 'PERL';
	$self->{_options}->{task}			||= 'JobSearch';
	$self->{_options}->{xc}				||= '0';
	$self->{_options}->{lang}			||= 'en';
	$self->{_options}->{'locations[]'}	||= undef;  # 180=UK
	$self->{_options}->{jobtype}		||= '1';    # 0=any, 1=contract, 2=perm
	$self->{_options}->{days}			||= '1';	# 0=all, otherwise literal
	$self->{_options}->{orderby}		||= '4';	# 1=relevance, 2=date posted, 3=salary, 4=non-agency
	$self->{_options}->{currpage}		||= 1;		# Current page of results
	$self->{_debug}						||= $DEBUG;
	if ($opts){
		foreach my $i (keys %$opts){
			$self->{_options}->{$i} = $opts->{$i};
		}
	}
	$self->{_next_url} = $self->{search_url} .'?' . $self->hash_to_cgi_string($self->{_options});
}


sub preprocess_results_page {
	my $self = shift;
	my $html = shift;
	warn " + RawHTML ===>$html<=== RawHTML\n" if 2 < $self->{_debug};
	return $html;
}


# After WWW::Search::Yahoo::Advanced

=head2 METHOD native_retrieve_some

Retrieve some results. Returns the number of results found. Will make as many HTTP requests
as necessary to get to the maximum results you specify.

=cut

sub native_retrieve_some { my $self = shift;
	$self->{state} = WWW::Search::SEARCH_BEFORE;
	$self->{number_retrieved} ||= 0;
	$self->{_done_uris} = {};

	# printf STDERR (" +   %s::native_retrieve_some()\n", __PACKAGE__) if $self->{_debug};

	# Initially _next_url is preset; we then undef it and try to get it from the HTML returned by the query:
	HTTP_REQUEST:
	while (defined $self->{_next_url} and not exists $self->{_done_uris}->{$self->{_next_url}}){ # fast exit if already done

		# If this is not the first page of results, sleep so as to not overload the server:
		$self->user_agent_delay if 1 < $self->{_next_to_retrieve};

		$self->{state} = WWW::Search::SEARCH_RETRIEVING;

		# Get one page of results:
		print STDERR " +   submitting URL (", $self->{_next_url}, ")\n" if $self->{_debug};
		$self->{response} = $self->http_request($self->http_method, $self->{_next_url});
		print STDERR " +     got response\n", $self->{response}->headers->as_string, "\n" if 2 <= $self->{_debug};
		$self->{_prev_url} = $self->{_next_url};
		$self->{_done_uris}->{$self->{_next_url}} ++;
		$self->{state} = WWW::Search::SEARCH_UNDERWAY;

		# Assume there are no more results, unless we find out otherwise when we parse the html:
		$self->{_next_url} = undef;
		print STDERR " --- HTTP response is:\n", $self->{response}->as_string if 4 < $self->{_debug};
		if (! $self->{response}->is_success) {
			if ($self->{_debug}) {
				print STDERR " --- HTTP request failed, response is:\n", $self->{response}->as_string;
			}
			return undef;
		}

		# Pre-process the output: actually, we don't but may later.
		my $html = $self->preprocess_results_page($self->{response}->content);

		# Parse the output:
		# No matches:
		if ($html =~ /There are no vacancies matching your search criteria/g){
			if ($self->{_debug}) {
				print STDERR " --- search failed: there are no vacancies matching your search criteria";
			}
			return undef;
		}

		$self->{_parser} = HTML::TokeParser->new(\$html);
		# Nice ppl they are, they provide a <div id="results"> containing lots of <div class="jobdet">
		# so loop over div class jobdet:
		PARSE_PAGE:
		while (my $token = $self->{_parser}->get_tag("div")) {
			# A 'div' with a 'class' attribute:
			if ($token->[1] and defined $token->[1]->{class}){
				# Found a job description:
				use Data::Dumper; die Dumper $token if not $token->[1]->{class};
				if ($token->[1]->{class} eq 'jobdet'){
					my $xtoken_a = $self->{_parser}->get_tag("a");
					if (not $xtoken_a){
						print STDERR " --- unexpected result format (code 'a'): please inform author";
						return undef;
					}
					my $title = $self->{_parser}->get_text("/a");
					if (not $title){
						print STDERR " --- unexpected result format (code '/a'): please inform author";
						return undef;
					}
					my $token_br = $self->{_parser}->get_tag("br");
					if (not $token_br){
						print STDERR " --- unexpected result format (code 'br'): please inform author";
						return undef;
					}
					my $all = $self->{_parser}->get_text("/p");
					if (not $token_br){
						print STDERR " --- unexpected result format (code '/p'): please inform author";
						return undef;
					}
					my ($last_posted) = $all =~ /LAST POSTED: (\d{2}\/\d{2}\/\d{4} \d{2}:\d{2}:\d{2})/g;
					my $hit = WWW::SearchResult->new;
					$hit->add_url(
						($xtoken_a->[1]->{href} =~ /^\//? $self->{search_base_url} : '')
						. $xtoken_a->[1]->{href}
					);
					$hit->title( $title );
					$hit->description( $all );
					$hit->change_date( $last_posted );
					push @{$self->{cache}}, $hit;
					$self->{_num_hits} ++;
				} # End found job

			} # End found div/class

			# Links to more results
			elsif ($token->[1]->{id} and $token->[1]->{id} eq 'prevnextpage'){
				while (my $xtoken_a = $self->{_parser}->get_tag("a")){
					next unless $xtoken_a->[1]->{title} and $xtoken_a->[1]->{title} eq 'Next';
					if ($WIN){
						# Weird bug in the latest (3.19) HTML::Parser.ppm TokeParser binary from AS
						# So have to do this:
						($xtoken_a->[1]->{href}) = $xtoken_a->[3] =~ /href=([^\s>]+)/;
						($xtoken_a->[1]->{href}) = $xtoken_a->[1]->{href} =~ /^.(.*).$/;
					}
					my $uri = ($xtoken_a->[1]->{href} =~ /^\//? $self->{search_base_url} : '') . $xtoken_a->[1]->{href};
					# IF we've not done it:
					if (not exists $self->{_done_uris}->{$uri}){
						$self->{_next_url} = $uri;
						print STDERR " + next URI: ".$self->{_next_uri} if $self->{_debug};
						last PARSE_PAGE;
					}
					# else { it's the end of the result set }
				}
			} # End found more results

		} # Next PARSE_PAGE

		$self->{_options}->{currpage} ++;

		last HTTP_REQUEST if $self->{number_retrieved} + $self->{_num_hits} >= $self->{maximum_to_retrieve};
	} # Next HTTP_REQUEST

	$self->{state} = WWW::Search::SEARCH_DONE;
	return $self->{_num_hits};
}



1;

__END__


=head1 SEE ALSO

This module was composed after reading L<WWW::Search>, L<WWW::Search::Yahoo>, L<WWW::Search::Yahoo::Advanced>
and L<WWW::Search::Jobserve>. If this module is useful to you, check out the latter too.

=head1 COPYRIGHT

Copyright (C) Lee Goddard, 2006. Some Rights Reserved.

=head1 LICENCE

This work is licensed under a I<Creative Commons Attribution-NonCommercial-ShareAlike 2.0 England &amp; Wales License>:
L<http://creativecommons.org/licenses/by-nc-sa/2.0/uk|http://creativecommons.org/licenses/by-nc-sa/2.0/uk>.

=begin html

<!--Creative Commons License--><a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/2.0/uk/"><img alt="Creative Commons License" border="0" src="http://creativecommons.org/images/public/somerights20.png"/></a>
<br/>This work is licensed under a <a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/2.0/uk/">Creative Commons Attribution-NonCommercial-ShareAlike 2.0 England &amp; Wales License</a>.
<!--/Creative Commons License-->
=end html

=begin xml

<!-- <rdf:RDF xmlns="http://web.resource.org/cc/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
	<Work rdf:about="">
	<license rdf:resource="http://creativecommons.org/licenses/by-nc-sa/2.0/uk/" />
	<dc:title>WWW::Search::TheITJobBoard</dc:title>
	<dc:date>2006</dc:date>
	<dc:creator><Agent><dc:title>Lee Goddard</dc:title></Agent></dc:creator>
	<dc:rights><Agent><dc:title>Lee Goddard</dc:title></Agent></dc:rights>
	<dc:type rdf:resource="http://purl.org/dc/dcmitype/InteractiveResource" />
		</Work>
		<License rdf:about="http://creativecommons.org/licenses/by-nc-sa/2.0/uk/"><permits rdf:resource="http://web.resource.org/cc/Reproduction"/><permits rdf:resource="http://web.resource.org/cc/Distribution"/>
		<requires rdf:resource="http://web.resource.org/cc/Notice"/>
		<requires rdf:resource="http://web.resource.org/cc/Attribution"/>
		<prohibits rdf:resource="http://web.resource.org/cc/CommercialUse"/>
		<permits rdf:resource="http://web.resource.org/cc/DerivativeWorks"/>
		<requires rdf:resource="http://web.resource.org/cc/ShareAlike"/></License>
	</rdf:RDF>
-->

=end xml



=cut



