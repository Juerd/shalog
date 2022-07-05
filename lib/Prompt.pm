unit module Prompt;

use Readline;
use NativeCall;
use Color;

# The Readline library is incomplete; I'm using the object oriented
# and functional interfaces and a manual event loop, to get tab completion and
# a way to pre-insert a default value.

# Copied from http://rosettacode.org/wiki/Longest_common_prefix#Perl_6
multi lcp()    { '' }
multi lcp($s)  { ~$s }
multi lcp(*@s) { substr @s[0], 0, [+] [\and] [Zeqv] |@s».ords }

my @TAB;

my Readline $rl = BEGIN { Readline.new };  # Singleton! libreadline has no instances.

my $readline-so = BEGIN {
    # We need to load rl_point from the *same* version as Readline.pm6 uses;
    # however, for whatever reason just providing 'readline' doesn't work. So
    # we'll insert a text using Readline.pm6 and then brute force some versions
    # until we find it.
    my $found;
    $rl.insert-text("detect");
    for "libreadline.so." X~ (5..8).reverse -> $lib {
        #put $lib;
        try my $x := cglobal($lib, "rl_end", int);
        $x or next;
        if $x == 6 {
            $found = $lib;
            last;
        }
    }
    # put "Found $found";
    $found or die "libreadline.so that corresponds to the Readline Raku mdoule not found";

    $found;
}


my $rl_point := cglobal($readline-so, 'rl_point', int);

state $tabstate;

# Poor man's tab completion, because we can't assign to rl_completion_entry_func
# because NativeCall does not support assigning to C globals yet.
$rl.bind-key("\t", sub (int32 $foo, int32 $bar --> int32) {
    my $text = $rl.copy-text(0, 1000);
    my $prefix = $text.substr(0, $rl_point) ~~ /\S+$/ or return 0;
    my @c = @TAB.grep(/^ $prefix/).sort or return 0;

    if @c == 1 {
        my $match = @c.head;
        $match ~~ s/^ $prefix//;
        $rl.insert-text("$match ");
        $tabstate = Nil;
        return 0;
    }
    if lcp(|@c) -> $lcp is copy {
        $lcp ~~ s/^ $prefix//;
        if ($lcp) {
            $rl.insert-text($lcp);
            $tabstate = Nil;
            return 0;
        }
    }
    if $tabstate.defined and $tabstate eq $prefix {
        reset-color;
        put "\n", @c.join(" ");
        $rl.reset-line-state;
        $rl.redisplay;
    }
    $tabstate = $prefix;
    return 0;
});

sub prompt(Str $prompt is copy, Str :$default = "", :@tab) is export {
    $tabstate = Nil;
    temp @TAB = @tab;

    # Add RL_PROMPT_START_IGNORE and RL_PROMPT_END_IGNORE to ANSI color escapes
    $prompt ~~ s:global/ ("\e[" .*? "m") /\x01$0\x02/;

    my $input;
    rl_callback_handler_install($prompt, sub (Str $foo) {
        $input = $foo;
        rl_callback_handler_remove();
    });
    $rl.insert-text($default);
    $rl.redisplay();

    loop {
        with $input {
            $rl.add-history: $input;
            return $input;
        }
        rl_callback_read_char();
    }
};

# vim: ft=perl6
