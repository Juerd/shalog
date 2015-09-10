#!perl6

class Person { ... }
class Thing { ... }
class Container { ... }
class Place { ... }
class Nowhere { ... }

class Entity {
    use JSON::Tiny;
    my %cache;

    has $.id is rw;

    multi method Str (Entity:D: ) { self.id }

    sub _load($id) is cached {
        return Nowhere if $id eq 'nowhere';

        my %hash = from-json slurp "$id.json";
        my $class = %hash<class>:delete;

        if (%hash<location>:exists) {
            %hash<location> = Entity.load(%hash<location>);
        }
        %hash<id> = $id;

        $class ~~ /^ [ Person | Place | Container | Thing ] $/
            or die "Invalid class '$class' for $id";

        return ::($class).new(|%hash);
    }

    method load($id) {
        return _load($id);
    }

    method json {
        my %hash;
        for self.^attributes -> $a {
            my $value = $a.get_value(self);
            if (defined $value) {
                %hash{ $a.Str.substr(2) } = $a.get_value(self).Str
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

class Place is Entity {
    has Place $.location is rw;
}

class Person is Entity {
    has Place $.location is rw = Nowhere;
}

class Container is Entity {
    has Entity $.location is rw where Place|Container = Nowhere;
}

class Thing is Entity {
    has Entity $.location is rw where Place|Container|Person = Nowhere;
}

class Nowhere is Place {
    method Str { "nowhere" }
}


my $t = Entity.load("foo");
say $t.perl;
say $t.json;
say $t.location.perl;
say $t.location.json;
