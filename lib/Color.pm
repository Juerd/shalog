unit module Color;

sub red ($text?) is export {
    return "\e[1;31m" without $text;
    return "\e[1;31m$text\e[0m";
}
sub green ($text?) is export {
    return "\e[1;32m" without $text;
    return "\e[1;32m$text\e[0m";
}
sub yellow ($text?) is export {
    return "\e[1;33m" without $text;
    return "\e[1;33m$text\e[0m";
}
sub white ($text?) is export {
    return "\e[0;1m" without $text;
    return "\e[0;1m$text\e[0m";
}
sub no-color is export {
    return "\e[0m";
}
sub reset-color is export {
    print no-color;
}

# vim: ft=perl6
