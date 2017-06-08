use Entity;

role Command::Infix { }

class Command::is-at { ... }
class Command::abort { ... }
class Command::help { ... }
class Command::info { ... }

class Command {
    method from-str (Command:U $: Str $str) {
        return Command::is-at.new if $str eq 'is-at' | '@' | 'at';
        return Command::abort.new if $str eq 'abort' | 'cancel';
        return Command::help.new  if $str eq 'help' | '?';
        return Command::info.new  if $str eq 'info';
        return Nil;
    }

    method Str {
        return self.^shortname
    }

    method accepts-list($command: @stack --> Bool) {
        if any(@stack) ~~ Command {
            note "Cannot queue multiple commands";
            return False;
        }
        return True;
    }
}

class Command::List is Command {
    method accepts-list($command: @stack --> Bool) {
        if @stack == 0 {
            note "$command cannot operate on an empty selection";
            return False;
        }
        nextsame;
    }
}

class Command::Unary is Command {
    method accepts-list($command: @stack --> Bool) {
        if @stack > 1 {
            note "$command cannot operate on more than 1 item";
            return False;
        }
        nextsame;
    }
}
class Command::Immediate is Command { }


class Command::is-at is Command::List does Command::Infix {
    method prompt (@stack) {
        return "Where is @stack[0] now (location or person)? " if @stack <= 2;
        return "Where are these items now? ";
    }
    multi method execute (@stack, Location $new-location) {
        @stack.pop if @stack.tail ~~ Command::is-at;
        all(@stack) ~~ Lendable or die "Not all items on the stack are lendable";  # XXX test via own test method

        @stack».is-at($new-location);
        @stack».store;

        say "{ +@stack } { @stack == 1 ?? "item" !! "items" } updated.\n";
        @stack = ();
    }
    multi method execute (@stack, Any $new-location) {
        die "$new-location is not a person or location";
    }

    method accepts-list($command: @stack --> Bool) {
        if @stack.grep: * !~~ Lendable -> @wrong {
            note "$command cannot be applied on @wrong.join(", ")";
            return False;
        }
        nextsame;
    }
}

class Command::abort is Command::Immediate {
    method execute (@stack) {
        note "ABORTED.";
        @stack = ();
    }
}

class Command::help is Command::Immediate {
    method execute (@) {
        note "Help function is not implemented yet. You're on your own... :D";
    }
}

class Command::info is Command::Unary {
    multi method execute (Person $person) {
        note "Not yet implemented."
    }
    multi method execute (Lendable $thing) {
        say "$thing is currently at { $thing.location }\n";
    }
}


# vim: ft=perl6
