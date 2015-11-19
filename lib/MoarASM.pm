use nqp;
use MASTNodes:from<NQP>;
use MASTOps:from<NQP>;

multi op($op, 0) {
    sub op0() {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op));
    }
}

multi op($op, 1) {
    sub op1(Mu $a1 is raw) {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op, $a1));
    }
}

multi op($op, 2) {
    sub op2(Mu $a1 is raw, Mu $a2 is raw) {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op, $a1, $a2));
    }
}

multi op($op, 3) {
    sub op3(Mu $a1 is raw, Mu $a2 is raw, Mu $a3 is raw) {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op, $a1, $a2, $a3));
    }
}

multi op($op, 4) {
    sub op4(Mu $a1 is raw, Mu $a2 is raw, Mu $a3 is raw, Mu $a4 is raw) {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op, $a1, $a2, $a3, $a4));
    }
}

multi op($op, 5) {
    sub op5(Mu $a1 is raw, Mu $a2 is raw, Mu $a3 is raw, Mu $a4 is raw,
        Mu $a5 is raw) {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op, $a1, $a2, $a3, $a4, $a5));
    }
}

multi op($op, 6) {
    sub op6(Mu $a1 is raw, Mu $a2 is raw, Mu $a3 is raw, Mu $a4 is raw,
        Mu $a5 is raw, Mu $a6 is raw) {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op, $a1, $a2, $a3, $a4, $a5,
            $a6));
    }
}

multi op($op, 7) {
    sub op7(Mu $a1 is raw, Mu $a2 is raw, Mu $a3 is raw, Mu $a4 is raw,
        Mu $a5 is raw, Mu $a6 is raw, Mu $a7 is raw) {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op, $a1, $a2, $a3, $a4, $a5,
            $a6, $a7));
    }
}

multi op($op, 8) {
    sub op8(Mu $a1 is raw, Mu $a2 is raw, Mu $a3 is raw, Mu $a4 is raw,
        Mu $a5 is raw, Mu $a6 is raw, Mu $a7 is raw, Mu $a8 is raw) {
        die "no \$*CODE to add <$op> to" without $*CODE;
        nqp::push($*CODE, MAST::Op.new(:$op, $a1, $a2, $a3, $a4, $a5,
            $a6, $a7, $a8));
    }
}

sub EXPORT {
    BEGIN {
        Map.new: |MAST::Ops::<%codes>.pairs.map(-> (:key($name), :value($id)) {
            my $count := nqp::atpos_i(MAST::Ops::<@counts>, $id);
            "&op_$name" => op($name, $count);
        });
    }
}

sub local(Mu \type) is export {
    MAST::Local.new(index => $*FRAME.add_local(type));
}

sub lexical(Mu \type, $name) is export {
    MAST::Lexical(index => $*FRAME.add_lexical(type, $name));
}

sub sv($value) is export {
    MAST::SVal.new(:$value);
}

sub iv($value, $size = 64, Bool :$u = False) is export {
    MAST::IVal.new(:$value, :$size, :signed(1 - $u));
}

sub nv($value, $size = 64) is export {
    MAST::NVal.new(:$value, :$size);
}

class MoarASM::CompUnit {
    has $!ast;
    has $!cu;

    submethod BUILD {
        $!ast := MAST::CompUnit.new;
    }

    method add-frame(&block) {
        my $*FRAME := MAST::Frame.new;
        my $*CODE := nqp::getattr($*FRAME, MAST::Frame, '@!instructions');
        block;
        $!ast.add_frame($*FRAME);
        $*FRAME;
    }

    method compile {
        $!cu := nqp::getcomp('MAST').assemble_and_load($!ast);
        self;
    }

    method mainline {
        nqp::compunitmainline($!cu);
    }
}
