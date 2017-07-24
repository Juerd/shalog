use Entity;
use Color;
use Prompt;

class X::Aborted is Exception { }

role Command::Infix { }

class Command::is-at { ... }
class Command::stays-at { ... }
class Command::stays-there { ... }
class Command::abort { ... }
class Command::help { ... }
class Command::info { ... }
class Command::edit-metadata { ... }
class Command::clear { ... }
class Command::create { ... }
class Command::generate { ... }
class Command::print { ... }
class Command::pop { ... }
class Command::restore { ... }

class Command {
    my %commands =
        'is-at' | '@' | 'at'         => Command::is-at,
        'stays-at'                   => Command::stays-at,
        'stays-there'                => Command::stays-there,
        'abort' | 'cancel'           => Command::abort,
        'help' | '?'                 => Command::help,
        'info'                       => Command::info,
        'edit-metadata'              => Command::edit-metadata,
        'clear'                      => Command::clear,
        'create' | 'new' | 'adduser' => Command::create,
        'generate'                   => Command::generate,
        'print'                      => Command::print,
        'pop'                        => Command::pop,
        'restore'                    => Command::restore;

    method all-commands (Command:U:) {
        return %commands.keys.sort;
    }

    method from-str (Command:U: Str $str) {
        return %commands{$str}.new if %commands{$str}:exists;
        return Nil;
    }

    method Str {
        return self.^shortname
    }

    method accepts-list($command: @stack --> Bool) {
        die "Cannot queue multiple commands" if any(@stack) ~~ Command;
        return True;
    }
}

class Command::List is Command {
    method accepts-list($command: @stack --> Bool) {
        die "$command cannot operate on an empty selection" if @stack == 0;
        nextsame;
    }
}

class Command::Unary is Command {
    method accepts-list($command: @stack --> Bool) {
        die "$command cannot operate on more than 1 item" if @stack > 1;
        nextsame;
    }
}

class Command::Immediate is Command { }

class Command::help is Command::Immediate {
    method execute (@) {
        print qq:to/END/;

        { white 'General commands:'}
            help                Print this help text
            generate            Generate a bunch of homogenous items
            clear               Clear the screen
        { white 'List operations:' }
            is-at <location>    Store the new location
            stays-at <location> Store the new permanent location
            stays-there         Make the current location permanent
            <person>            Short for "is-at <location>"
            print               Print labels for selected items
        { white 'Single-item operations:' }
            info                Print contents and/or location
            edit-metadata       Change metadata
        { white 'Stack manipulation:' }
            <entity>            Add entity to selection
            pop                 Remove last item from selection
            abort               Empty selection
            restore             Restore selection

        Each part of a command is entered on a line by itself.
        Every command or item can be scanned from a barcode, or typed by hand.

        END
    }
}

class Command::is-at is Command::List does Command::Infix {
    method prompt (@stack) {
        return "Where is @stack[0] now (location or person)? " if @stack <= 2;
        return "Where are these items now? ";
    }
    multi method execute (@stack, Location $new-location, Bool :$stays = False) {
        @stack.pop if @stack.tail ~~ Command::is-at;

        die "$new-location would cause infinite containment loop"
            if $new-location.would-loop: any(@stack);

        my (:@accepted, :@rejected) := @stack.classify: sub ($entity) {
            $new-location ~~ Person or return 'accepted';
            $entity.?requires-groups or return 'accepted';
            my @rg = $entity.requires-groups.words or return 'accepted';

            # subset of or equal to
            @rg (<=) $new-location.groups.?words and return 'accepted';
            return 'rejected';
        };

        for @accepted -> $entity {
            $entity.is-at: $new-location, :$stays;
            $entity.store;
        }
        put "Accepted { +@accepted } updates.";

        for @rejected -> $entity {
            put red "REJECTED:";
            my @g = map { red $_ }, (
                $entity.requires-groups.?words (-) $new-location.groups.?words
            ).keys;

            my $g = @g == 1 ?? "group @g[]" !! "groups @g.join("+")";
            put "$new-location is not in $g but $entity requires it.";
        }

        @stack.reset;
    }
    multi method execute (@, Any $new-location, Bool :$stays) {
        die "$new-location is not a person or location";
    }

    method accepts-list($command: @stack --> Bool) {
        if @stack.grep: * !~~ Lendable -> @wrong {
            die "$command cannot be applied on @wrong.join(", ")";
        }
        nextsame;
    }
}

class Command::stays-at is Command::is-at {
    method execute (@stack, Any $new-location) {
        nextwith(@stack, $new-location, :stays);
    }
}

class Command::stays-there is Command::List {
    method execute (@stack) {
        for @stack -> $entity {
            $entity.is-at: $entity.location, :stays;
            $entity.store;
        }
        @stack.reset;
    }
}

class Command::abort is Command::Immediate {
    method execute (@stack) {
        @stack.reset;
        die X::Aborted.new;
    }
}

class Command::info is Command::Unary {
    method execute(Entity $entity) {
        given $entity {
            .print-contents when Location;
            .print-location when Lendable;
        }
    }
}

class Command::clear is Command::Immediate {
    method execute (@) {
        print "\e[2J\e[;H";
    }
}

class Command::create is Command::Immediate {
    method execute (@) {
        put "To register a new entity, just try to use it and I will ask you "
            ~ "if you want to create it, after which it is added to the "
            ~ "selection for immediate use.";
    }
}

class Command::generate is Command::Immediate {
    method execute (@stack) {
        put "Only use this function if you know what you're doing. "
            ~ "Type 'abort' to abort.";

        my $prefix = prompt(yellow "prefix> ").trim;
        die X::Aborted.new if $prefix eq 'abort' | '';

        my subset PosInt of Int where * > 0;

        my PosInt $first = 1;
        if Entity.all-entities.grep: { .id ~~ /^$prefix '#' \d+ $/ } -> @existing {
            $first = 1 + @existing».id».match(/\d+ $/)».Int.max;
        }
        $first = +prompt(yellow("first> "), :default(~$first)).trim || $first;

        my PosInt $num = +prompt(yellow "number> ") || die X::Aborted.new;
        my PosInt $last = $first + $num - 1;

        my Any:U $type = prompt-type(
            "What are '$prefix#$first-$last'?", "$prefix#$first-$last"
        );
        die X::Aborted.new if $type !~~ Entity;

        for $first..$last -> $i {
            my $id = "$prefix#$i";
            die "$id already exists; aborting." if Entity.load($id);
            my $e = $type.new(:$id);
            $e.add-to-cache;
            $e.store;

            @stack.push: $e;
        }
    }
}

class Command::print is Command::List {
    method execute (@stack) {
        print qq:to/END/;

        What kind of labels do you want?
        '1' or 'barcode':   Linear 1D barcodes (narrow: screwdrivers etc.)
        '2' or 'aztec':     Square 2D codes (square, redundant, recommended)
        '3' or 'text':      Just text (not yet implemented)
        '0' or 'ignore':    Don't print any barcodes
        END

        my $type = prompt(
            yellow("label> ") ~ white,
            :tab<barcode aztec text ignore>
        ) until $type.defined;
        reset-color;

        given $type {
            when 1 | 'barcode' {
                temp $*CWD = 'ptouch-770';
                run 'perl', 'barcode.pl', @stack.map: *.id;
                print "Printing barcode{ @stack > 1 ?? "s" !! "" }...\n\n";
            }
            when 2 | 'aztec' {
                temp $*CWD = 'ptouch-770';
                run 'perl', 'aztec.pl', @stack.map: *.id;
                print "Printing square code{ @stack > 1 ?? "s" !! "" }...\n\n";
            }
            when 3 | 'text' {
                die "Text barcodes are not yet implemented.";
            }
            when 0 | 'ignore' {
                put "Ignoring print command."
            }
            default {
                die "Invalid label type $type; ignoring print command.";
            }
        }
        print "Note: selection kept. Type 'abort' to clear the selection.\n\n";
    }
}

class Command::pop is Command::List {
    method execute (@stack) {
        @stack.pop;
    }
}

class Command::restore is Command::Immediate {
    method execute (@stack) {
        die "Cannot restore non-empty stack." if @stack;
        @stack.restore;
    }
}

class Command::edit-metadata is Command::Unary {
    method execute (Entity $entity) {
        use Prompt; 
        my %tab = groups => <teamlead driver manitou>;

        for <comment owner requires-groups groups> -> $attr {
            my $m = $entity.^lookup: $attr or next;

            $entity.$m = prompt
                yellow($attr ~ "> "),
                :default($entity.$m // ''),
                :tab(%tab{$attr} // []);
        }
        $entity.store;
    }
}


# vim: ft=perl6
