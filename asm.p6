use lib 'lib';
use MoarASM;

{
    my $cu := MoarASM::CompUnit.new;
    $cu.add-frame: {
        my \S0 = local str;
        my \I0 = local int;
        my \N0 = local num;

        op_const_s S0, sv('hello ');
        op_print S0;

        op_const_n64 N0, nv(1e0);
        op_sleep N0;

        op_const_s S0, sv('world');
        op_say S0;

        op_const_i64 I0, iv(42);
        op_return_i I0;
    }

    say $cu.compile.mainline.();
}

{
    my $cu := MoarASM::CompUnit.new;
    $cu.add-frame: :name<println>, {
        my \ZERO = local int;
        my \ARG = local str;
        my \CAP = local Capture;

        op_usecapture CAP;
        op_captureposarg_s ARG, CAP, ZERO;
        op_say ARG;

        op_return_i ZERO;
    }

    $cu.compile.frame(0).('ok');
}
