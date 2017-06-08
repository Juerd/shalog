#!perl6

use v6;
use lib 'lib';
use Entity;
use Command;

class Stack is Array {
    method Str (@stack:) {
        my @entities = @stack.grep: Entity;
        return "Selection: { @entities ?? @entities.join(", ") !! "(empty)" }\n";
    }

    method prompt (@stack: --> Str) {
        my $command = @stack.grep(Command).tail or return;

        my $p = "";
        if $command.?prompt(@stack) -> $prompt {
            $p ~= "$prompt\n"
        }
        return "$p\e[32;1m$command> \e[0;1m";
    }

    method try-infix (@stack:) {
        return unless @stack >= 3 and @stack[* - 2] ~~ Command::Infix;
        my $infix = @stack[* - 2];
        my $post = @stack.pop;
        $infix.execute: @stack, $post;
    }

    method try-unary (@stack:) {
        return unless @stack == 2 and one(@stack) ~~ Command::Unary;
        @stack.head.execute: @stack.tail if @stack.head ~~ Command::Unary;
        @stack.tail.execute: @stack.head if @stack.tail ~~ Command::Unary;
        # XXX error handling?
        @stack.reset;
    }

    method reset (@stack:) {
        print "\n";
        @stack = ();
    }
}

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
        given prompt("\e[33;1mcreate>\e[0;1m ").trim {
            when 1 | 'thing'     { return Thing.new(:$id); }
            when 2 | 'person'    { return Person.new(:$id); }
            when 3 | 'place'     { return Place.new(:$id); }
            when 4 | 'container' { return Container.new(:$id); }
            when 0 | 'ignore'    { return; }
            default { note "\e[0m$_ is not a valid response."; }
        }
    }
}

sub handle-input (@stack, $input where Command | Entity --> Bool) {
    given $input {
        when any(@stack) {
            die "Ignoring duplicate input.";
        }
        when Command::Immediate {
            .execute: @stack;
        }
        when Command {
            .accepts-list(@stack);
            @stack.push: $input;
        }
        when Person {
            proceed unless @stack and all(@stack) ~~ Lendable;
            Command::is-at.new.execute: @stack, $input;
        }
        when Entity {
            @stack.push: $input;
        }
    }
    return True;
}

my @stack is Stack where Entity | Command::Infix | Command::Unary;

loop {
    print "\e[0m";
    @stack.print;

    my $line = prompt(@stack.prompt // "\e[32;1m> \e[0;1m").trim;
    print "\e[0m";

    next if $line eq "";

    die "Input contains unsupported characters."
        if $line ~~ /<-[\x21..\x7E]>/;

    if $line ~~ s/^\@\s*<before .>// {
        handle-input @stack, Command::is-at.new or redo;
    }

    handle-input @stack, Command.from-str($line)
        // Entity.load($line)
        // create($line)
        // redo;

    @stack.try-infix;
    @stack.try-unary;

    CATCH { default { note "\e[31;1m$_\e[0m\n"; } }
}