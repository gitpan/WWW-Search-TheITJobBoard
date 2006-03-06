# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WWW-Search-TheITJobBoard.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Data::Dumper;
use lib '../lib';
use Test::More tests => 1;
BEGIN { use_ok('WWW::Search::TheITJobBoard' => 0.03) };

 __END__

my $oSearch = WWW::Search->new('TheITJobBoard', _debug=>10, detailed=>1,);
isa_ok($oSearch, 'WWW::Search::TheITJobBoard');
is($oSearch->{detailed}, 1, 'Passed arg');
is(WWW::Search::TheITJobBoard::CONTRACT, 1, 'Constants');

my $sQuery = WWW::Search::escape_query("perl html");
ok(defined($sQuery),'Query escaped');

warn Dumper $oSearch;

ok(defined($oSearch->native_query($sQuery,
	jobtype			=> WWW::Search::TheITJobBoard::CONTRACT,
	'location[]'	=> 180,
	orderby			=> WWW::Search::TheITJobBoard::NONAGENCY,
)),'Native query');

my $hits = 0;
while ( my $r = $oSearch->next_result() ){
	++$hits;
	isa_ok($r, 'WWW::SearchResult');
}

warn Dumper $oSearch;
warn "Got $hits";

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

