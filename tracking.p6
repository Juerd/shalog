#!perl6

use v6;
use lib ~$*PROGRAM.resolve.sibling: 'lib';
use Entity;
use Command;
use Color;

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
        return $p ~ green("$command> ") ~ white;
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

    my Entity $e;
    until $e {
        given prompt(yellow("create> ") ~ white).trim {
            when 1 | 'thing'     { $e = Thing.new(:$id); }
            when 2 | 'person'    { $e = Person.new(:$id); }
            when 3 | 'place'     { $e = Place.new(:$id); }
            when 4 | 'container' { $e = Container.new(:$id); }
            when 0 | 'ignore'    { return; }
            default { reset-color; note "$_ is not a valid response."; }
        }
    }
    $e.store;
    return $e;
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
    reset-color;
    @stack.print;

    my $line = prompt(@stack.prompt // green("> ") ~ white).trim;
    reset-color;

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

    CATCH { default { note red($_), "\n"; } }
}
