class Entity {
    use JSON::Tiny;
    my %cache;

    has $.id is rw;

    multi method Str (Entity:D: ) { self.id }

    sub _load($id --> Entity) {
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

#    method would-recurse (Mu $to-be-contained) {
#        say self;
#        say $to-be-contained;
#        die;
#        return 0;
#    }
}

role Location { }

role Lendable {
    has Location $.location;
    has @.location_history;

    method is-at(Location $new) {
        $!location = $new;
        @!location_history.push({ dt => ~DateTime.now, location => ~$new });
    }
}

class Person    is Entity does Location { }
class Place     is Entity does Location { }
class Thing     is Entity does Lendable { }
class Container is Entity does Lendable does Location { }

# vim: ft=perl6
