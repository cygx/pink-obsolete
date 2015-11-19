my enum Kind <TERM FUNC PROC DECL DEF CONTROL INFIX PREFIX POSTFIX>;
my subset NamedKind of Kind where TERM|FUNC|PROC|DECL|DEF|CONTROL;

my role Lexel[Kind \K] {
    has $.name;

    method is(\kind) { kind == K }
    method new(:$name!) { $name => self.bless(:$name, |%_) }
    method kind { K }
}

my class Proc does Lexel[PROC] {}
my class Term does Lexel[TERM] {}
my class Infix does Lexel[INFIX] {}
my class Declaration does Lexel[DECL] {}
my class Control does Lexel[CONTROL] {}

my class Definition does Lexel[DEF] {
    has %.locals;
    has %.lexicals;

    method enter { $*scope = $*scope.spawn(:%!locals, :%!lexicals) }
    method leave { $*scope = $*scope.parent }
}

my class Scope {
    has $.parent;
    has %.locals;
    has %.lexicals;
    has %.prefixes;
    has %.postfixes;
    has %.infixes;

    method spawn { Scope.new(parent => self, |%_) }

    multi method LOCAL(NamedKind) { %!locals }
    multi method LOCAL($) { Nil }

    multi method LEX(NamedKind) { %!lexicals }
    multi method LEX(INFIX) { %!infixes }
    multi method LEX(PREFIX) { %!prefixes }
    multi method LEX(POSTFIX) { %!postfixes }

    method declare($lexel) {
        my $name := $lexel.name;
        my %stash := self.LEX($lexel.kind);
        die "redeclaration of '$name'" if %stash{$name}:exists;
        %stash{$name} = $lexel;
    }

    method lookup($name, $type) {
        with self.LOCAL($type) {
            my $value;
            return $value if ($value := .{$name}).?is($type);
        }

        my $current := self;
        loop {
            my $value;
            return $value
                if ($value := $current.LEX($type).{$name}).?is($type);

            last unless $current := $current.parent;
        }

        Nil;
    }
}

sub gistlist(@list) { @list ?? ' ' ~ @list>>.gist.join(' ') !! '' }

my class AST::Root {
    has $.scope;
    has @.mainline;

    method gist {
        "(root{ gistlist @!mainline })"
    }
}

my class AST::Def {
    has $.scope;
    has $.type;
    has $.name;
    has @.mainline;

    method gist {
        "(def $!type {$!name}{ gistlist @!mainline })"
    }
}

my class AST::Decl {
    has $.type;
    has $.name;
    has $.init;

    method gist {
        "(decl $!type {$!name}{ defined($!init) ?? ' ' ~ $!init.gist !! ''})"
    }
}

my class AST::Expr {
    has @.parts;
    method gist { "(expr{ gistlist @!parts })" }
}

my class AST::Op {
    has $.name;
    method gist { "(infix $!name)" }
}

my class AST::Eval {
    has $.name;
    has @.args;

    method gist { "(eval {$!name}{ gistlist @!args })" }
}

my grammar Grammar {
    method lookup(|args) { $*scope.lookup(|args) }

    token eol { \h* \v \s* | \s* $ }
    token string { \" <-["]>* \" }
    token number { \d+ { make $/.Str.Int } }
    token name { [\w+]+ % ';' }

    token infix {
        :my $op;
        \h+ (<-[\s\w,;.:]><-[\s,;.:]>*) \s+ <?{ $op = self.lookup(~$0, INFIX) }>
        { make AST::Op.new(name => $op.name) }
    }

    token atom {
        [ <at=.term>
        | <at=.func>
        | <at=.number>
        | <at=.string>
        ] { make $<at>.ast }
    }

    token expression {
        <head=.atom>
        [ [ <infix> <atom> ]+
            { make AST::Expr.new(
                parts => [ $<head>.ast, |flat $<infix>>>.ast Z $<atom>>>.ast ]) }
        || { make $<head>.ast } ]
    }

    token term {
        <name> <?{ self.lookup(~$/, TERM) }>
        { make AST::Eval.new(name => ~$<name>) }
    }

    token proc {
        <name> <?{ self.lookup(~$/, PROC) }>
        [ \h+ <expression>+ % [ \h* ',' \s* ] ]?
        { make AST::Eval.new(name => ~$<name>,
            args => [ |$<expression>>>.ast ]) }
    }

    token func {
        <name> <?{ self.lookup(~$/, FUNC) }>
        '(' \s* <expression>* % [ \h* ',' \s* ] \s* ')'
        { make AST::Eval.new(name => ~$<name>,
            args => [ |$<expression>>>.ast ]) }
    }

    token declaration {
        :my $decl;
        <type=.name> <?{ $decl = self.lookup(~$/, DECL) }> \h+ <name>
        { $*scope.declare(Term.bless(name => ~$<name>)) }
        [ \h+ '=' \h+ <init=.expression> ]?
        { make AST::Decl.new(type => ~$<type>, name => ~$<name>,
            init => $<init>.?ast) }
    }

    token statement {
        [ <sm=.declaration>
        | <sm=.definition>
        | <sm=.control>
        | <sm=.proc>
        | <sm=.expression>
        ] { make $<sm>.ast }
    }

    token control {
        <name> <?{ self.lookup(~$/, CONTROL) }>
        [ \h+ <expression> ]?
        [ \h+ <block> | \h* ':' \s+ <statement> ]?
    }

    token block {
        '{' \s* <statement>* % <eol> \s* '}'
        { make [ |$<statement>>>.ast ] }
    }

    token definition {
        :my $def;
        <.name> <?{ $def := self.lookup(~$/, DEF) }> \h+ <name>
        { $def.enter }
        [ \h+ <block> ]?
        { make AST::Def.new(:$*scope, type => $def.name, name => ~$<name>,
            mainline => $<block>.ast) }
        { $def.leave }
    }

    token TOP {
        \s* [ <statement> <eol> ]*
        { make AST::Root.new(scope => $*scope,
            mainline => [ |$<statement>>>.ast ]) }
    }
}

sub lobby {
    Scope.new:
        :infixes(hash
            Infix.new(:name<+>),
        ),

        :lexicals(hash
            Proc.new(:name<say>),
            Term.new(:name<PI>),
            Declaration.new(:name<set>),
            Declaration.new(:name<let>),
            Control.new(:name<if>),
        ),

        :locals(hash
            Declaration.new(:name<global>),
            Declaration.new(:name<const>),
            Declaration.new(:name<static>),
            Definition.new(
                :name<class>,
                :locals(hash
                    Declaration.new(:name<has>),
                    Declaration.new(:name<takes>),
                    Definition.new(:name<method>),
                    Definition.new(:name<action>),
                    Definition.new(:name<get>),
                    Definition.new(:name<set>),
                ),
            ),
        );
}

class Lang::Pink {
    method parse($code) {
        my $*scope = lobby;
        Grammar.parse($code);
    }
}
