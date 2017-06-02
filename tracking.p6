#!perl6

class Nowhere { ... }

class Entity {
    use JSON::Tiny;
    my %cache;

    has $.id is rw;

    multi method Str (Entity:D: ) { self.id }

    sub _load($id --> Entity) {
        return Nowhere if $id eq 'nowhere';
        return %cache{$id} if %cache{$id}:exists;

        my $io = "$id.json".IO;
        $io.r or return;
        my $json = try $io.slurp or return;

        my %hash = from-json $json;
        my $class = %hash<class>:delete;

        if (%hash<location>:exists) {
            %hash<location> = Entity.load(%hash<location>);
        }
        %hash<id> = $id;

        $class ~~ /^ [ Thing | Container | Person | Place ] $/
            or die "Invalid class '$class' for $id";

        return %cache{$id} = ::($class).new(|%hash);
    }

    method load($id --> Entity) {
        return _load($id);
    }

    method store {
        spurt $.id ~ ".json", $.json;
    }

    method json {
        my %hash;
        for self.^attributes -> $a {
            my $value = $a.get_value(self);
            if (defined $value) {
                $value = ~$value if $value.isa(Entity);
                %hash{ $a.Str.substr(2) } = $value;
            }
        };
        %hash<class> = self.^name;
        return to-json %hash;
    }

    method would-recurse (Mu $to-be-contained) {
        say self;
        say $to-be-contained;
        die;
        return 0;
    }
}

role Location { }

role Lendable {
    has Location $.location = Nowhere;
    has @.location_history;

    method is-at(Location $new) {
        $!location = $new;
        @!location_history.push({ dt => ~DateTime.now, location => ~$new });
    }
}

class Person    is Entity does Location { }
class Place     is Entity does Location { }
class Nowhere   is Entity does Location { method Str { "nowhere" } }
class Thing     is Entity does Lendable { }
class Container is Entity does Lendable does Location { }

###

role Command::List { }
role Command::Infix { }
role Command::Unary { }
role Command::Immediate { }

class Command {
    method Str {
        "<{ self.^name }>";
    }
}

class Command::is-at is Command does Command::List does Command::Infix {
    method infix-prompt (@stack) {
        return "Where is @stack[0] now (location or person)? " if @stack <= 2;
        return "Where are these items now? ";
    }
    method execute (@stack, $new-location) {
        $new-location ~~ Location or die "$new-location is not a person or location";
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

###

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
