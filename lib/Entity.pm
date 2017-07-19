role Location { }

class Entity {
    use JSON::Tiny;
    use Color;

    my %cache;

    has $.id is rw;

    multi method Str (Entity:D: ) { self.id ~ gray('(' ~ self.^name.lc ~ ')'); }

    sub _file($id is copy --> IO) {
        $id.=subst('/', ' ', :global);
        return ("db/{ $id.lc }.json").IO;
    }

    sub _load($id --> Entity) {
        return %cache{$id.lc} if %cache{$id.lc}:exists;

        my $io = _file($id);
        $io.r or return;
        my $json = try $io.slurp or return;

        my %hash = from-json $json;
        my $class = %hash<class>:delete;

        if %hash<location>:exists {
            my $location = Entity.load(%hash<location>);
            if not $location {
                note "$id was at %hash<location>, but that's gone!";
                $location = Location;
            }
            %hash<location> = $location;
        }
        if %hash<id>.lc ne $id.lc {
            note "LOADED $id AS %hash<id>, WHICH IS WEIRD.";
        }

        $class ~~ /^ [ Thing | Container | Person | Place ] $/
            or die "Invalid class '$class' for $id";

        my Entity $entity = ::($class).new(|%hash);
        $entity.add-to-cache;

        return $entity;
    }

    method load($id --> Entity) {
        return _load($id);
    }

    method add-to-cache() {
        %cache{$.id.lc} = self;
    }

    method store {
        spurt _file($.id), $.json;
    }

    method json {
        my %hash;
        for self.^attributes -> $a {
            my $value = $a.get_value(self);
            if (defined $value) {
                $value = $value.id if $value.isa(Entity);
                %hash{ $a.Str.substr(2) } = $value;
            }
        };
        %hash<class> = self.^name;
        return to-json %hash;
    }

    method would-loop ($ --> Bool) {
        return False
    }
}

role Lendable {
    has Location $.location;
    has @.location_history;

    method is-at(Location $new) {
        $!location = $new;
        @!location_history.push({ dt => ~DateTime.now, location => ~$new });
    }

    method would-loop(Entity $to-be-contained --> Bool) {
        return True  if self.id eq $to-be-contained.id;
        return False if not $.location;
        return False if $.location !~~ Lendable;
        return $.location.would-loop: $to-be-contained;
    }
}

class Person    is Entity does Location { }
class Place     is Entity does Location { }
class Thing     is Entity does Lendable { }
class Container is Entity does Lendable does Location { }

# vim: ft=perl6
