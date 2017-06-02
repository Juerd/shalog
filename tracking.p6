#!perl6

use v6;
use lib 'lib';
use Entity;
use Command;


my @stack where Entity | Command::Infix | Command::Unary;

my Command %commands = (
    "is-at"  => Command::is-at.new,
    "@"      => Command::is-at.new,
    "abort"  => Command::abort.new,
    "cancel" => Command::abort.new,
    "help"   => Command::help.new,
    "?"      => Command::help.new,
    "info"   => Command::info.new,
);

INPUT: while (1) {
    if @stack >= 3 and @stack[* - 2] ~~ Command::Infix {
        my $infix = @stack[* - 2];
        my $post = @stack.pop;
        try {
            $infix.execute(@stack, $post);
            CATCH { note "{ .Str }; command aborted."; next INPUT }
        }
    }
    if @stack == 2 and @stack.head ~~ Command::Unary {
        # XXX error handling?
        @stack.head.execute(@stack.tail);
        @stack = ();
    }

    print "Selection: (empty)\n" if not @stack;
    print "Selection ({ +@stack } items): @stack.join(", ")\n" if @stack;

    my $prompt = @stack > 1 && @stack.tail ~~ Command::Infix
        ?? @stack.tail.infix-prompt(@stack)
        !! "> ";

    my $input = prompt $prompt;
    $input.=trim;

    given $input {
        when %commands{$input}:exists { $input = %commands{$input} }
        $input = Entity.load($input) // $input;
    }

    given $input {
        # Order of cases matters!
        when any(@stack) {
            note "Ignoring duplicate input."
        }
        when Command {
            when Command::Immediate {
                .execute(@stack);
            }
            when any(@stack) ~~ Command {
                note "Cannot queue multiple commands; ignoring.";
            }
            when not @stack and $input ~~ Command::List {
                note "$input cannot operate on an empty selection; ignoring.";
            }
            when @stack > 1 and $input !~~ Command::List {
                note "$input cannot operate on more than 1 item; ignoring.";
            }
            when Command::Unary {
                if (@stack) {
                    .execute(@stack.tail);
                    @stack = ();
                } else {
                    @stack.push: $input;
                }
            }
            when Command::Infix {
                @stack.push: $input;
            }
            default { note "Internal error: unhandled command; ignoring." }
        }
        when Entity {
            if $input ~~ Person and @stack and all(@stack) ~~ Lendable {
                Command::is-at.new.execute(@stack, $input);
            } else {
                @stack.push: $input;
            }
        }
        default { note "Unknown input '$input' ignored."; }
    }
}
