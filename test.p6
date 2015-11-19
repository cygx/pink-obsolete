use lib 'lib';
use Lang::Pink;

say Lang::Pink.parse(q:to/__END__/).?ast;
set i = 42
say i
__END__
