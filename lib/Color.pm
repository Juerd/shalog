unit module Color;

multi sub red()      is export { "\e[1;31m" }
multi sub red($t)    is export { "\e[1;31m$t\e[0m" }
multi sub green()    is export { "\e[1;32m" }
multi sub green($t)  is export { "\e[1;32m$t\e[0m" }
multi sub yellow()   is export { "\e[1;33m" }
multi sub yellow($t) is export { "\e[1;33m$t\e[0m" }
multi sub white()    is export { "\e[0;1m" }
multi sub white($t)  is export { "\e[0;1m$t\e[0m" }
multi sub gray()     is export { "\e[1;30m" }
multi sub gray($t)   is export { "\e[1;30m$t\e[0m" }
sub no-color()       is export { "\e[0m" }
sub reset-color()    is export { print no-color; }

# vim: ft=perl6
