package Log::ger::Output::Screen;

# AUTHORITY
# DATE
# DIST
# VERSION

use strict;
use warnings;

use Log::ger::Util;

our %colors = (
    10 => "\e[31m"  , # fatal, red
    20 => "\e[35m"  , # error, magenta
    30 => "\e[1;34m", # warning, light blue
    40 => "\e[32m"  , # info, green
    50 => "",         # debug, no color
    60 => "\e[33m"  , # trace, orange
);

our %level_map;

sub _pick_color {
    my $level = shift;
    if (defined(my $c = $colors{$level})) {
        return $c;
    }
    if (defined(my $clevel = $level_map{$level})) {
        return $colors{$clevel};
    }

    # find the nearest
    my ($dist, $clevel);
    for my $k (keys %colors) {
        my $d = abs($k - $level);
        if (!defined($dist) || $dist > $d) {
            $dist = $d;
            $clevel = $k;
        }
    }
    $level_map{$level} = $clevel;
    return $colors{$clevel};
}

sub hook_before_log {
    my ($ctx, $msg) = @_;
}

sub hook_after_log {
    my ($ctx, $msg) = @_;
    print { $ctx->{_fh} } "\n" unless $msg =~ /\R\z/;
}

sub get_hooks {
    my %conf = @_;

    my $stderr = $conf{stderr};
    $stderr = 1 unless defined $stderr;
    my $handle = $stderr ? \*STDERR : \*STDOUT;
    my $use_color = do {
        if (defined $conf{use_color}) {
            $conf{use_color};
        } elsif (exists $ENV{NO_COLOR}) {
            0;
        } elsif (defined $ENV{COLOR}) {
            $ENV{COLOR};
        } else {
            $stderr ? (-t STDERR) : (-t STDOUT);
        }
    };
    my $formatter = $conf{formatter};

    return {
        # we provide two versions for testing, one using create_log_routine and
        # one using create_logml_routine. by default, create_logml_routine will
        # take precendence.

        create_log_routine => [
            __PACKAGE__, # key
            50,          # priority
            sub {        # hook
                my %hook_args = @_;
                my $logger = sub {
                    my $level = $hook_args{level};
                    my $msg = $_[1];
                    if ($formatter) {
                        $msg = $formatter->($msg);
                    }
                    hook_before_log({ _fh=>$handle }, $msg);
                    if ($use_color) {
                        print $handle _pick_color($level), $msg, "\e[0m";
                    } else {
                        print $handle $msg;
                    }
                    hook_after_log({ _fh=>$handle }, $msg);
                };
                [$logger];
            }],
        create_logml_routine => [
            __PACKAGE__, # key
            50,          # priority
            sub {        # hook
                my %hook_args = @_; # see Log::ger::Manual::Internals/"Arguments passed to hook"
                my $logger = sub {
                    my $level = Log::ger::Util::numeric_level($_[1]);
                    return if $level > $Log::ger::Current_Level;
                    my $msg = $_[2];
                    if ($formatter) {
                        $msg = $formatter->($msg);
                    }
                    hook_before_log({ _fh=>$handle }, $msg);
                    if ($use_color) {
                        print $handle _pick_color($level), $msg, "\e[0m";
                    } else {
                        print $handle $msg;
                    }
                    hook_after_log({ _fh=>$handle }, $msg);
                };
                [$logger];
            }],
    };
}

1;
# ABSTRACT: Output log to screen

=for Pod::Coverage ^(.+)$

=head1 SYNOPSIS

 use Log::ger::Output Screen => (
     # stderr => 1,    # set to 0 to print to stdout instead of stderr
     # use_color => 0, # set to 1/0 to force usage of color, default is from NO_COLOR/COLOR or (-t STDOUT)
     # formatter => sub { ... },
 );
 use Log::ger;

 log_warn "blah...";


=head1 DESCRIPTION


=head1 CONFIGURATION

=head2 stderr

Bool, default 1. Whether to print to STDERR (the default) or st=head2 use_color
=> bool

=head2 use_color

Bool. The default is to look at the NO_COLOR and COLOR environment variables, or
1 when in interactive mode and 0 when not in interactive mode.

=head2 formatter

Coderef. When defined, will pass the formatted message (but being applied with
colors) to this custom formatter.


=head1 ENVIRONMENT

=head2 NO_COLOR

Can be set (to anything) to disable color by default, if C</use_color> is not
set. Consulted before L</COLOR>.

=head2 COLOR

Can be set to disable/enable color by default, if C</use_color> is not set.


=head1 SEE ALSO

Modelled after L<Log::Any::Adapter::Screen>.
