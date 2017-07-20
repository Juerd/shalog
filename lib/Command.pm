use Entity;
use Color;

class X::Aborted is Exception { }

role Command::Infix { }

class Command::is-at { ... }
class Command::abort { ... }
class Command::help { ... }
class Command::info { ... }
class Command::clear { ... }
class Command::create { ... }

class Command {
    method from-str (Command:U $: Str $str) {
        return Command::is-at.new  if $str eq 'is-at' | '@' | 'at';
        return Command::abort.new  if $str eq 'abort' | 'cancel';
        return Command::help.new   if $str eq 'help' | '?';
        return Command::info.new   if $str eq 'info';
        return Command::clear.new  if $str eq 'clear';
        return Command::create.new if $str eq 'create' | 'new' | 'adduser';
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


class Command::is-at is Command::List does Command::Infix {
    method prompt (@stack) {
        return "Where is @stack[0] now (location or person)? " if @stack <= 2;
        return "Where are these items now? ";
    }
    multi method execute (@stack, Location $new-location) {
        @stack.pop if @stack.tail ~~ Command::is-at;

        die "$new-location would cause infinite containment loop"
            if $new-location.would-loop: any(@stack);

        @stack».is-at: $new-location;
        @stack».store;

        put "{ +@stack } { @stack == 1 ?? "item" !! "items" } updated.\n";
        @stack.reset;
    }
    multi method execute (@stack, Any $new-location) {
        die "$new-location is not a person or location";
    }

    method accepts-list($command: @stack --> Bool) {
        if @stack.grep: * !~~ Lendable -> @wrong {
            die "$command cannot be applied on @wrong.join(", ")";
        }
        nextsame;
    }
}

class Command::abort is Command::Immediate {
    method execute (@stack) {
        @stack.reset;
        die X::Aborted.new;
    }
}

class Command::help is Command::Immediate {
    method execute (@) {
        note "Help function is not implemented yet. You're on your own... :D";
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

# vim: ft=perl6
