use Color;
use Prompt;

role Location { ... }
role Lendable { ... }

class Entity {
    use JSON::Tiny;

    my %cache;

    has $.id is rw;

    multi method Str (Entity:D: ) { self.id ~ gray('(' ~ self.^name.lc ~ ')'); }

    method all-entities(Entity:U:) {
        state $old-mtime;
        state @cached;

        my $path = 'db'.IO;

        my $mtime = $path.modified;
        return @cached if $old-mtime and $old-mtime == $mtime;
        $old-mtime = $mtime;

        return @cached = gather {
            for $path.dir.grep(/'.json' $/) -> $file {
                take Entity.load-from-file($file);
            }
        }
    }

    method load-from-file(Entity:U: IO() $file) {
        $file.r or return;
        my $json = try $file.slurp or return;

        my %hash = from-json $json;
        my $class = %hash<class>:delete;

        if %hash<location>:exists {
            my $location = Entity.load(%hash<location>);
            if not $location {
                note "%hash<id> was at %hash<location>, but that's gone!";
                $location = Location;
            }
            %hash<location> = $location;
        }

        $class ~~ /^ [ Thing | Container | Person | Place ] $/
            or die "Invalid class '$class' for %hash<id>";

        my Entity $entity = ::($class).new(|%hash);
        $entity.add-to-cache;

        return $entity;
    }

    sub _file($id is copy --> IO) {
        $id.=subst('/', ' ', :global);
        return ("db/{ $id.lc }.json").IO;
    }

    method load(Entity:U: $id --> Entity) {
        return %cache{$id.lc} if %cache{$id.lc}:exists;

        my $io = _file($id);
        my $entity = Entity.load-from-file($io) or return;

        if $entity.id.lc ne $id.lc {
            note "LOADED $id AS { Entity.id }, WHICH IS WEIRD.";
        }

        return $entity;
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
            if defined $value {
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

role Location {
    method print-contents {
        my Entity @items = Entity.all-entities.grep(Lendable)
            .grep({ .location && .location.id.lc eq $.id.lc });

        put "{ self } has { +@items } {
            @items == 0 ?? 'items.' !! @items == 1 ?? 'item:' !! 'items:' }";
        put yellow("* "), $_, (.stays ?? " (permanent)" !! "") for @items;
    }
}

role Lendable {
    has Location $.location;
    has $.location_history;
    has Bool $.stays = False;

    method is-at(Location $new, Bool :$stays = False) {
        $!location = $new;
        $!stays = $stays;
        $!location_history.push: hash {
            dt => ~DateTime.now,
            location => $new.id,
            stays => $stays,
        };
    }

    method would-loop(Entity $to-be-contained --> Bool) {
        return True  if $.id eq $to-be-contained.id;
        return False if not $.location;
        return False if $.location !~~ Lendable;
        return $.location.would-loop: $to-be-contained;
    }

    method print-location (Bool :$history = True) {
        without $!location {
            put "The location for { self } is unknown.";
            return;
        }

        if ($history and $!location_history.elems) {
            my $max = 5;
            my @prev = @($!location_history)».{'location'}.squish;
            # These are just id's, but the pretty printing with type is not
            # wanted here anyway.
            @prev.pop;  # discard current
            @prev.=tail($max);
            @prev.push: "(...)" if $!location_history.elems > $max;

            put "{ self } was previously at @prev.reverse.join(", ").";
        }

        my $may-stay = $!stays ?? " and may stay there!" !! ".";
        put "{ self } is currently at $!location$may-stay";

        $!location.print-location(:!history) if $!location ~~ Lendable;
    }
}

class Person    is Entity does Location { }
class Place     is Entity does Location { }
class Thing     is Entity does Lendable { }
class Container is Entity does Lendable does Location { }
use MONKEY-TYPING;

augment class Entity {
    sub prompt-type (Str $prompt, Str $id --> Any:U) is export {
        print qq:to/END/;

        $prompt
        '1' or 'thing':     Register '$id' as a new thing.
        '2' or 'person':    Register '$id' as a new person.
        '3' or 'place':     Register '$id' as a new place.
        '4' or 'container': Register '$id' as a new container.
        '0' or 'ignore':    Ignore this input (typo, scan error, etc.)
        END

        my %options =
            1 | 'thing'     => Thing,
            2 | 'person'    => Person,
            3 | 'place'     => Place,
            4 | 'container' => Container,
            0 | 'ignore'    => Any;

        loop {
            my $input = prompt(
                yellow("create> ") ~ white, :tab(%options.keys)
            ).trim;

            if %options{$input}:exists {
                return %options{$input};
            }
            reset-color;
            note "$input is not a valid response.";
        }
    }
}

# vim: ft=perl6
