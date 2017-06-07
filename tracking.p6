#!perl6

use v6;
use lib 'lib';
use Entity;
use Command;

class Stack is Array {
    method Str (@stack:) {
        my @entities = @stack.grep: Entity;
        my @commands = @stack.grep: Command;

        die if @commands > 1;

        my $rv = "Selection: { @entities ?? @entities.join(", ") !! "(empty)" }\n";
        $rv ~= "Command: @commands[0]\n" if @commands;

        return $rv;
    }

    method prompt (@stack: --> Str) {
        return @stack.grep(*.can('prompt')).tail.?prompt(@stack);
    }

    method try-infix (@stack:) {
        return unless @stack >= 3 and @stack[* - 2] ~~ Command::Infix;
        my $infix = @stack[* - 2];
        my $post = @stack.pop;
        try {
            $infix.execute: @stack, $post;
            CATCH { default { note "{ .Str }; command aborted."; } }
        }
    }

    method try-unary (@stack:) {
        return unless @stack == 2 and one(@stack) ~~ Command::Unary;
        @stack.head.execute: @stack.tail if @stack.head ~~ Command::Unary;
        @stack.tail.execute: @stack.head if @stack.tail ~~ Command::Unary;
        # XXX error handling?
        @stack = ();
    }
}


my @stack is Stack where Entity | Command::Infix | Command::Unary;

sub create($id) {
    print qq:to/END/;

    What is '$id'?
    '1' or 'thing':     Register '$id' as a new thing.
    '2' or 'person':    Register '$id' as a new person.
    '3' or 'place':     Register '$id' as a new place.
    '4' or 'container': Register '$id' as a new container.
    '0' or 'ignore':    Ignore this input (typo, scan error, etc.)
    END

    loop {
        given prompt("create> ").trim {
            when 1 | 'thing'     { return Thing.new(:$id); }
            when 2 | 'person'    { return Person.new(:$id); }
            when 3 | 'place'     { return Place.new(:$id); }
            when 4 | 'container' { return Container.new(:$id); }
            when 0 | 'ignore'    { return; }
            default { note "$_ is not a valid response."; }
        }
    }
}

my Command %commands = (
    "is-at"  => Command::is-at.new,
    "@"      => Command::is-at.new,
    "at"     => Command::is-at.new,
    "abort"  => Command::abort.new,
    "cancel" => Command::abort.new,
    "help"   => Command::help.new,
    "?"      => Command::help.new,
    "info"   => Command::info.new,
);

loop {
    @stack.try-infix;
    @stack.try-unary;
    @stack.print;

    my $line = prompt(@stack.prompt // "> ").trim;
    my $input = %commands{$line} // Entity.load($line) // create($line) // redo;

    given $input {
        when any(@stack) {
            note "Ignoring duplicate input."
        }
        when Command {
            when Command::Immediate {
                .execute: @stack;
            }
            when any(@stack) ~~ Command {
                note "Cannot queue multiple commands; ignoring.";
            }
            when not @stack and $input ~~ Command::List {
                note "$input cannot operate on an empty selection; ignoring.";
            }
            when @stack > 1 and $input ~~ Command::Unary {
                note "$input cannot operate on more than 1 item; ignoring.";
            }
            default {
                @stack.push: $input;
            }
        }
        when Entity {
            if $input ~~ Person and @stack and all(@stack) ~~ Lendable {
                Command::is-at.new.execute: @stack, $input;
            } else {
                @stack.push: $input;
            }
        }
        default {
            note "INPUT NOT RECOGNIZED";
        }
    }
}
