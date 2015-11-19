use lib 'lib';
use Lang::Pink;

say Lang::Pink.parse(q:to/__END__/).?ast;
var i = 42
println i
__END__
