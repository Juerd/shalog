#!perl6

use v6;
use lib ~$*PROGRAM.resolve.sibling: 'lib';
use Entity;
use Command;
use Color;
use Prompt;

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
        my $infix-command = @stack[* - 2];
        my $post = @stack.pop;
        $infix-command.execute: @stack, $post;
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
    my Entity $e;

    if $id ~~ /^ 'angel-'/ {
        $e = Person.new(:$id);
    } else {
        my $type = prompt-type("What is '$id'?", $id);
        return if $type !~~ Entity;

        $e = $type.new(:$id);
    }
    $e.add-to-cache;
    $e.store;
    return $e;
}

sub handle-input (@stack, $input where Command | Entity --> Bool) {
    given $input {
        when any(@stack) {
            die "$input is already selected; ignoring duplicate input.";
        }
        when Command::Immediate {
            .execute: @stack;
        }
        when Command {
            .accepts-list: @stack;
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

    my @tab = flat Entity.all-entities».id, Command.all-commands;
    my $line = prompt(@stack.prompt // green("> ") ~ white, :@tab).trim;
    reset-color;

    redo if $line eq "";

    die "Input contains an unsupported character: '$0'."
        if $line ~~ /(<-[\x21..\x7E]>)/;

    if $line ~~ s/^\@\s*<before .>// {
        handle-input @stack, Command::is-at.new or redo;
    }

    handle-input @stack, Command.from-str($line)
        // Entity.load($line)
        // create($line)
        // redo;

    @stack.try-infix;
    @stack.try-unary;

    CATCH {
        when X::Aborted { note red "ABORTED.\n" }
        when X::AdHoc { note "{ red "Error:" } $_\n" }
        default { note red "Unexpected exception: $_.gist()\n" }
    }
}

