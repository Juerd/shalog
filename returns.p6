#!perl6

use v6;
use lib ~$*PROGRAM.resolve.sibling: 'lib';
use Entity;
use Command;
use Color;
use Prompt;

my $port = 9101;
my $my-location = Entity.load('lhq-returns');

$my-location ~~ Place or die;

sub display ($x is copy) {
    my Buf $buf .= new(0x1b, 0x42, 0x30, 0x1b, 0x25);
    $buf.push: $x.subst(:global, "\n", "\x0d").encode;
    $buf.push: Buf.new: 0x03;
    return $buf;
}

react {
    whenever IO::Socket::Async.listen('0.0.0.0', $port) -> $conn {
        say "New connection";
        whenever $conn.Supply -> $input is copy {
            $input.=trim;
            say "Received: $input";
            if $input ~~ /<-[\x20..\x7F]>/ {
                $conn.write: display "malformed barcode.";
                next;
            }

            if Entity.load($input) -> $entity {
                if $entity ~~ Lendable {
                    my $l = $entity.location;
                    my $reply;
                    if $l.id eq $my-location.id {
                        $conn.write: display "Duplicate scan.";
                        next;
                    } elsif $l ~~ Person {
                        my $name = $l.id.subst(/^'angel-'/, '');
                        $reply = "Hi $name,\nthanks for returning\n$entity.id()!\n";
                    } else {
                        $reply = "Next time don't forget\nto check out!\n";
                    }
                    $entity.update;
                    $entity.is-at: $my-location;
                    $entity.store;
                    $conn.write: display $reply;
                }
            } else {
                $conn.write: display "Unknown barcode\n$input";
            }
        }
    }
}
