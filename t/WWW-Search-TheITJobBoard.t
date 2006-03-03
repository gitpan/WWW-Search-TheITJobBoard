# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WWW-Search-TheITJobBoard.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Data::Dumper;
use lib '../lib';
use Test::More tests => 1;
BEGIN { use_ok('WWW::Search::TheITJobBoard') };


__END__

my $oSearch = WWW::Search->new('TheITJobBoard', _debug=>undef);
isa_ok($oSearch, 'WWW::Search::TheITJobBoard');

my $sQuery = WWW::Search::escape_query("perl");
ok(defined($sQuery),'Query escaped');

ok(defined($oSearch->native_query($sQuery)),'Native query');
my $r = $oSearch->next_result();
isa_ok($r, 'WWW::SearchResult');


#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

