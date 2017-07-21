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

my Readline $rl .= new;  # Singleton! libreadline has no instances.
my $rl_point := cglobal('libreadline.so.6', 'rl_point', int);

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
        return $input with $input;
        rl_callback_read_char();
    }
};

# vim: ft=perl6
