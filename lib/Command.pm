use Entity;

role Command::List { }
role Command::Infix { }
role Command::Unary { }
role Command::Immediate { }

class Command { method Str { "<{ self.^name }>" } }

class Command::is-at is Command does Command::List does Command::Infix {
    method infix-prompt (@stack) {
        return "Where is @stack[0] now (location or person)? " if @stack <= 2;
        return "Where are these items now? ";
    }
    multi method execute (@stack, Any $new-location) {
        die "$new-location is not a person or location";
    }
    multi method execute (@stack, Location $new-location) {
        @stack.pop if @stack.tail ~~ Command::is-at;
        all(@stack) ~~ Lendable or die "Not all items on the stack are lendable";  # XXX test via own test method

        @stack».is-at($new-location);
        @stack».store;

        say "{ +@stack } { @stack == 1 ?? "item" !! "items" } updated.\n";
        @stack = ();
    }
}

class Command::abort is Command does Command::Immediate {
    method execute (@stack) {
        note "ABORTED.";
        @stack = ();
    }
}

class Command::help is Command does Command::Immediate {
    method execute (@) {
        note "Help function is not implemented yet. You're on your own... :D";
    }
}

class Command::info is Command does Command::Unary {
    multi method execute (Person $person) {
        note "Not yet implemented."
    }
    multi method execute (Lendable $thing) {
        say "$thing is currently at { $thing.location }\n";
    }
}

# vim: ft=perl6
