package Text::CSV;

################################################################################
# HISTORY
#
# Text::CSV was written by:
#    Alan Citterman <alan[at]mfgrtl[dot]com>
#
# Text::CSV_XS was written by:
#    Jochen Wiedmann <joe[at]ispsoft[dot]de>
#
# And extended by:
#    H.Merijn Brand (h.m.brand[at]xs4all[dot]nl)
#
# For pure perl version of Text::CSV_XS, Text::CSV_PP was written by:
#    Makamaka Hannyaharamitu (makamaka[at]donzoko[dot]net)
#
# And Text::CSV become a wrapper module to Text::CSV_XS and Text::CSV_PP.
#
############################################################################


use strict;
use Carp ();

BEGIN {
    $Text::CSV::VERSION = '0.99_05';
    $Text::CSV::DEBUG   = 0;
}

# if use CSV_XS, requires version 0.32
my $Module_XS  = 'Text::CSV_XS';
my $Module_PP  = 'Text::CSV_PP';
my $XS_Version = '0.32';

# used in _load_xs and _load_pp
my $Install_Dont_Die = 1; # When _load_xs fails to load XS, don't die.
my $Install_Only     = 2; # Don't call _set_methods()


my @PublicMethods = qw/
    version types quote_char escape_char sep_char eol always_quote binary allow_whitespace
    keep_meta_info allow_loose_quotes allow_loose_escapes verbatim meta_info is_quoted is_binary eof
    getline print parse combine fields string error_diag error_input status
    PV IV NV
/;

my @UndocumentedXSMethods = qw/Combine Parse/;

my @UndocumentedPPMethods = qw//; # Currently empty


# Check the environment variable to decide worker module. 

unless ($Text::CSV::Worker) {
    $Text::CSV::DEBUG and  Carp::carp("Check used worker module...");

    if ( exists $ENV{TEXT_CSV_XS} ) {
        if ($ENV{TEXT_CSV_XS} == 0) {
            _load_pp();
        }
        elsif ($ENV{TEXT_CSV_XS} == 1) {
            _load_xs($Install_Dont_Die) or _load_pp();
        }
        elsif ($ENV{TEXT_CSV_XS} == 2) {
            _load_xs();
        }
        else {
            Carp::croak "The value of environmental variable 'TEXT_CSV_XS' is invalid.";
        }
    }
    else {
        _load_xs($Install_Dont_Die) or _load_pp();
    }

}


my $compile_dynamic_mode = sub {
    my ($class, $worker) = @_;

    local $^W;
    no strict qw(refs);

    for my $method (@PublicMethods) {
        eval qq|
            *{"$class\::$method"} = sub {
                my \$self = shift;
                \$self->{_MODULE} -> $method(\@_);
            };
        |;
    }

    *Text::CSV::new = \&_new_dynamic;
};


sub import {
    my ($class, $option) = @_;
    if ($option and $option eq '-dynamic') {
        $compile_dynamic_mode->($class => $Text::CSV::Worker);
        $Text::CSV::DEBUG and  Carp::carp("Dynamic worker module mode."), "\n";
    }
}


sub _new_dynamic {
    my $proto  = shift;
    my $class  = ref($proto) || $proto or return;
    my $module = $Text::CSV::Worker;

    if (ref $_[0] and $_[0]->{module}) {
        $module = delete $_[0]->{module}; # Caution! deleted from original hashref too.

        my $installed = $module . '.pm';
        $installed =~ s{::}{/};

        unless ($INC{ $installed }) { # Not yet installed
            if ($module eq $Module_XS) {
                _load_xs($Install_Only);
            }
            elsif ($module eq $Module_PP) {
                _load_pp($Install_Only);
            }
            else {
            }
        }

    }

    if ( my $obj = $module->new(@_) ) {
        my $self = bless {}, $class;
        $self->{_MODULE} = $obj;
        return $self;
    }
    else {
        return;
    }

}


sub new { # normal mode
    my $proto = shift;
    my $class = ref($proto) || $proto or return;

    if (ref $_[0] and $_[0]->{module}) {
        Carp::croak("Can't set 'module' in non dynamic mode.");
    }

    if ( my $obj = $Text::CSV::Worker->new(@_) ) {
        $obj->{_MODULE} = $Text::CSV::Worker;
        bless $obj, $class;
    }
    else {
        return;
    }

}


sub module {
    my $proto = shift;
    return   !ref($proto)            ? $Text::CSV::Worker
           :  ref($proto->{_MODULE}) ? ref($proto->{_MODULE}) : $proto->{_MODULE};
}




sub AUTOLOAD {
    my $self = $_[0];
    my $attr = $Text::CSV::AUTOLOAD;
    $attr =~ s/.*:://;
    return unless $attr =~ /^_/;

    my $pkg = $Text::CSV::Worker;

    my $method = "$pkg\::$attr";

    $Text::CSV::DEBUG and Carp::carp("'$attr' is private method, so try to autoload...");

    local $^W;
    no strict qw(refs);

    *{"Text::CSV::$attr"} = *{"$pkg\::$attr"};

    goto &$attr;
}



sub _load_xs {
    my $opt = shift;

    $Text::CSV::DEBUG and Carp::carp "Load $Module_XS.";

    eval qq| use $Module_XS $XS_Version |;

    if ($@) {
        if (defined $opt and $opt & $Install_Dont_Die) {
            $Text::CSV::DEBUG and Carp::carp "Can't load $Module_XS...($@)";
            return 0;
        }
        Carp::croak $@;
    }

    unless (defined $opt and $opt & $Install_Only) {
        _set_methods( $Text::CSV::Worker = $Module_XS );
    }

    return 1;
};


sub _load_pp {
    my $opt = shift;

    $Text::CSV::DEBUG and Carp::carp "Load $Module_PP.";

    eval qq| require $Module_PP |;
    if ($@) {
        Carp::croak $@;
    }

    unless (defined $opt and $opt & $Install_Only) {
        _set_methods( $Text::CSV::Worker = $Module_PP );
    }
};




sub _set_methods {
    my $class = shift;

    local $^W;
    no strict qw(refs);

    for my $method (@PublicMethods) {
        *{"Text::CSV::$method"} = \&{"$class\::$method"};
    }

    for my $method (@UndocumentedXSMethods) {
        *{"Text::CSV::$method"} = \&{"$Module_XS\::$method"};
    }

    for my $method (@UndocumentedPPMethods) {
        *{"Text::CSV::$method"} = \&{"$Module_PP\::$method"};
    }

}



1;
__END__

=pod

=head1 NAME

Text::CSV - comma-separated values manipulator (using XS or PurePerl)


=head1 SYNOPSIS

 use Text::CSV;
 
 $csv = Text::CSV->new();              # create a new object
 
 # If you want to handle non-ascii char.
 $csv = Text::CSV->new({binary => 1});
 
 $status = $csv->combine(@columns);    # combine columns into a string
 $line   = $csv->string();             # get the combined string
 
 $status  = $csv->parse($line);        # parse a CSV string into fields
 @columns = $csv->fields();            # get the parsed fields
 
 $status       = $csv->status ();      # get the most recent status
 $bad_argument = $csv->error_input (); # get the most recent bad argument
 $diag         = $csv->error_diag ();  # if an error occured, explains WHY
 
 $status = $csv->print ($io, $colref); # Write an array of fields
                                       # immediately to a file $io
 $colref = $csv->getline ($io);        # Read a line from file $io,
                                       # parse it and return an array
                                       # ref of fields
 $eof = $csv->eof ();                  # Indicate if last parse or
                                       # getline () hit End Of File
 
 $csv->types(\@t_array);               # Set column types


=head1 DESCRIPTION

Text::CSV provides facilities for the composition and decomposition of
comma-separated values using L<Text::CSV_XS> or its pure-Perl version.

An instance of the Text::CSV class can combine fields into a CSV string
and parse a CSV string into fields.

The module accepts either strings or files as input and can utilize any
user-specified characters as delimiters, separators, and escapes so it is
perhaps better called ASV (anything separated values) rather than just CSV.


=head2 HISTORY AND WORKER MODULES

This module, L<Text::CSV> was firstly written by Alan Citterman which could deal with
B<only ascii characters>. Then, Jochen Wiedmann wrote L<Text::CSV_XS> which has
the B<binary mode>. This XS version is maintained by H.Merijn Brand. And L<Text::CSV_PP>
written by Makamaka was pure-Perl version of Text::CSV_XS.

Now, Text::CSV was rewritten by Makamaka and become a wrapper to Text::CSV_XS or Text::CSV_PP.
Text::CSV_PP was renamed to L<Text::CSV_PP> when it was bundled in this distribution.

When you use Text::CSV, it calls other worker module - L<Text::CSV_XS> or L<Text::CSV_PP>.
By default, Text::CSV tries to use Text::CSV_XS which must be complied and installed properly.
If this call is fail, Text::CSV uses L<Text::CSV_PP>.

The required Text::CSV_XS version is I<0.32> in Text::CSV version 1.00.

If you set an enviornment variable C<TEXT_CSV_XS>, The calling action will be changed.

=over

=item TEXT_CSV_XS == 0

Always use Text::CSV_PP

=item TEXT_CSV_XS == 1

(The default) Use compiled Text::CSV_XS if it is properly compiled & installed,
otherwise use Text::CSV_PP

=item TEXT_CSV_XS == 2

Always use compiled Text::CSV_XS, die if it isn't properly compiled & installed.

=back

These ideas come from L<DBI::PurePerl> mechanism.

example:

 BEGIN { $ENV{TEXT_CSV_XS} = 0 }
 use Text::CSV; # always uses Text::CSV_PP


=head2 BINARY MODE

The default behavior is to only accept ascii characters.
In many cases, you should create a Text::CSV object with
binary mode.

 my $csv = Text::CSV->new({binary => 1});

See to L<Text::CSV_XS/Embedded newlines>.


=head1 SPECIFICATION

See to L<Text::CSV_XS/SPECIFICATION>.


=head1 FUNCTIONS

These methods are common between XS and puer-Perl.
Most of the documentation was shamelessly copied and replaced from Text::CSV_XS.

=over 4

=item version

(Class method) Returns the current module version. Not worker module version.
If you want the worker module version, you can use C<module> method.

 print Text::CSV->version;         # This module version
 print Text::CSV->module->version; # The version of the worker module

=item new(\%attr)

(Class method) Returns a new instance of Text::CSV. The objects
attributes are described by the (optional) hash ref C<\%attr>.
Currently the following attributes are available:

=over 4

=item eol

An end-of-line string to add to rows, usually C<undef> (nothing,
default), C<"\012"> (Line Feed) or C<"\015\012"> (Carriage Return,
Line Feed).

See to L<Text::CSV_XS>.

=item sep_char

The char used for separating fields, by default a comma. (C<,>).
Limited to a single-byte character, usually in the range from 0x20
(space) to 0x7e (tilde).

The separation character can not be equal to the quote character.
The separation character can not be equal to the escape character.

=item allow_whitespace

When this option is set to true, whitespace (TAB's and SPACE's)
surrounding the separation character is removed when parsing. So
lines like:

  1 , "foo" , bar , 3 , zapp

are now correctly parsed, even though it violates the CSV specs.

See to L<Text::CSV_XS>.

=item quote_char

The char used for quoting fields containing blanks, by default the
double quote character (C<">). A value of undef suppresses
quote chars. (For simple cases only).
Limited to a single-byte character, usually in the range from 0x20
(space) to 0x7e (tilde).

The quote character can not be equal to the separation character.

=item allow_loose_quotes

By default, parsing fields that have C<quote_char> characters inside
an unquoted field, like

 1,foo "bar" baz,42

would result in a parse error. Though it is still bad practice to
allow this format, we cannot help there are some vendors that make
their applications spit out lines styled like this.

=item escape_char

The character used for escaping certain characters inside quoted fields.
Limited to a single-byte character, usually in the range from 0x20
(space) to 0x7e (tilde).

The C<escape_char> defaults to being the literal double-quote mark (C<">)
in other words, the same as the default C<quote_char>. This means that
doubling the quote mark in a field escapes it:

  "foo","bar","Escape ""quote mark"" with two ""quote marks""","baz"

If you change the default quote_char without changing the default
escape_char, the escape_char will still be the quote mark.  If instead 
you want to escape the quote_char by doubling it, you will need to change
the escape_char to be the same as what you changed the quote_char to.

The escape character can not be equal to the separation character.

=item allow_loose_escapes

By default, parsing fields that have C<escape_char> characters that
escape characters that do not need to be escaped, like:

 my $csv = Text::CSV->new ({ escape_char => "\\" });
 $csv->parse (qq{1,"my bar\'s",baz,42});

would result in a parse error. Though it is still bad practice to
allow this format, this option enables you to treat all escape character
sequences equal.

=item binary

If this attribute is TRUE, you may use binary characters in quoted fields,
including line feeds, carriage returns and NULL bytes. (The latter must
be escaped as C<"0>.) By default this feature is off.

=item types

A set of column types; this attribute is immediately passed to the
I<types> method below. You must not set this attribute otherwise,
except for using the I<types> method. For details see the description
of the I<types> method below.

=item always_quote

By default the generated fields are quoted only, if they need to, for
example, if they contain the separator. If you set this attribute to
a TRUE value, then all fields will be quoted. This is typically easier
to handle in external applications. 

=item keep_meta_info

By default, the parsing of input lines is as simple and fast as
possible. However, some parsing information - like quotation of
the original field - is lost in that process. Set this flag to
true to be able to retrieve that information after parsing with
the methods C<meta_info ()>, C<is_quoted ()>, and C<is_binary ()>
described below.  Default is false.

=item verbatim

See to L<Text::CSV_XS>.

=back

To sum it up,

 $csv = Text::CSV->new ();

is equivalent to

 $csv = Text::CSV->new ({
     quote_char          => '"',
     escape_char         => '"',
     sep_char            => ',',
     eol                 => '',
     always_quote        => 0,
     binary              => 0,
     keep_meta_info      => 0,
     allow_loose_quotes  => 0,
     allow_loose_escapes => 0,
     allow_whitespace    => 0,
     verbatim            => 0,
 });

For all of the above mentioned flags, there is an accessor method
available where you can inquire for the current value, or change
the value

 my $quote = $csv->quote_char;
 $csv->binary (1);

It is unwise to change these settings halfway through writing CSV
data to a stream. If however, you want to create a new stream using
the available CSV object, there is no harm in changing them.

=item combine

 $status = $csv->combine (@columns);

This object function constructs a CSV string from the arguments, returning
success or failure.  Failure can result from lack of arguments or an argument
containing an invalid character.  Upon success, C<string ()> can be called to
retrieve the resultant CSV string.  Upon failure, the value returned by
C<string ()> is undefined and C<error_input ()> can be called to retrieve an
invalid argument.

=item print

 $status = $csv->print ($io, $colref);

Similar to combine, but it expects an array ref as input (not an array!)
and the resulting string is not really created, but immediately written
to the I<$io> object, typically an IO handle or any other object that
offers a I<print> method. Note, this implies that the following is wrong:

 open FILE, ">", "whatever";
 $status = $csv->print (\*FILE, $colref);

The glob C<\*FILE> is not an object, thus it doesn't have a print
method. The solution is to use an IO::File object or to hide the
glob behind an IO::Wrap object. See L<IO::File(3)> and L<IO::Wrap(3)>
for details.

For performance reasons the print method doesn't create a result string.
In particular the I<$csv-E<gt>string ()>, I<$csv-E<gt>status ()>,
I<$csv->fields ()> and I<$csv-E<gt>error_input ()> methods are meaningless
after executing this method.

=item string

 $line = $csv->string ();

This object function returns the input to C<parse ()> or the resultant CSV
string of C<combine ()>, whichever was called more recently.

=item parse

 $status = $csv->parse ($line);

This object function decomposes a CSV string into fields, returning
success or failure.  Failure can result from a lack of argument or the
given CSV string is improperly formatted.  Upon success, C<fields ()> can
be called to retrieve the decomposed fields .  Upon failure, the value
returned by C<fields ()> is undefined and C<error_input ()> can be called
to retrieve the invalid argument.

You may use the I<types ()> method for setting column types. See the
description below.

=item getline

 $colref = $csv->getline ($io);

This is the counterpart to print, like parse is the counterpart to
combine: It reads a row from the IO object $io using $io->getline ()
and parses this row into an array ref. This array ref is returned
by the function or undef for failure.

The I<$csv-E<gt>string ()>, I<$csv-E<gt>fields ()> and I<$csv-E<gt>status ()>
methods are meaningless, again.

=item eof

 $eof = $csv->eof ();

If C<parse ()> or C<getline ()> was used with an IO stream, this
method will return true (1) if the last call hit end of file, otherwise
it will return false (''). This is useful to see the difference between
a failure and end of file.

=item types

 $csv->types (\@tref);

This method is used to force that columns are of a given type. For
example, if you have an integer column, two double columns and a
string column, then you might do a

 $csv->types ([Text::CSV::IV (),
               Text::CSV::NV (),
               Text::CSV::NV (),
               Text::CSV::PV ()]);

Column types are used only for decoding columns, in other words
by the I<parse()> and I<getline()> methods.

You can unset column types by doing a

 $csv->types (undef);

or fetch the current type settings with

 $types = $csv->types ();

=over 4

=item IV

Set field type to integer.

=item NV

Set field type to numeric/float.

=item PV

Set field type to string.

=back

=item fields

 @columns = $csv->fields ();

This object function returns the input to C<combine ()> or the resultant
decomposed fields of C<parse ()>, whichever was called more recently.

=item meta_info

 @flags = $csv->meta_info ();

This object function returns the flags of the input to C<combine ()> or
the flags of the resultant decomposed fields of C<parse ()>, whichever
was called more recently.

For each field, a meta_info field will hold flags that tell something about
the field returned by the C<fields ()> method or passed to the C<combine ()>
method. The flags are bitwise-or'd like:

=over 4

=item 0x0001

The field was quoted.

=item 0x0002

The field was binary.

=back

See the C<is_*** ()> methods below.

=item is_quoted

  my $quoted = $csv->is_quoted ($column_idx);

Where C<$column_idx> is the (zero-based) index of the column in the
last result of C<parse ()>.

This returns a true value if the data in the indicated column was
enclosed in C<quote_char> quotes. This might be important for data
where C<,20070108,> is to be treated as a numeric value, and where
C<,"20070108",> is explicitly marked as character string data.

=item is_binary

  my $binary = $csv->is_binary ($column_idx);

Where C<$column_idx> is the (zero-based) index of the column in the
last result of C<parse ()>.

This returns a true value if the data in the indicated column
contained any byte in the range [\x00-\x08,\x10-\x1F,\x7F-\xFF]

=item status

 $status = $csv->status ();

This object function returns success (or failure) of C<combine ()> or
C<parse ()>, whichever was called more recently.

=item error_input

 $bad_argument = $csv->error_input ();

This object function returns the erroneous argument (if it exists) of
C<combine ()> or C<parse ()>, whichever was called more recently.

=item error_diag

 $csv->error_diag ();
 $error_code  = 0  + $csv->error_diag ();
 $error_str   = "" . $csv->error_diag ();
 ($cde, $str) =      $csv->error_diag ();

If (and only if) an error occured, this function returns the diagnostics
of that error.

If called in void context, it will print the internal error code and the
associated error message to STDERR.

If called in list context, it will return the error code and the error
message in that order.

If called in scalar context, it will return the diagnostics in a single
scalar, a-la $!. It will contain the error code in numeric context, and
the diagnostics message in string context.

Depending on the used worker module, returned diagnostics is diffferent.

Text::CSV_XS parses csv strings by dividing one character while Text::CSV_PP
by using the regular expressions. That difference makes the different cause
of the failure.

=back

Some methods are Text::CSV only.

=over

=item module

(Class method) Returns the module name called by Text::CSV.

(Object method) Returns the used module name in creating it.

At current, the worker module is decided once when Text::CSV is used in a program.

=back


=head1 DIAGNOSTICS

If an error occured, $csv->error_diag () can be used to get more information
on the cause of the failure. Note that for speed reasons, the internal value
is never cleared on success, so using the value returned by error_diag () in
normal cases - when no error occured - may cause unexpected results.

This function changes depending on the used module (XS or PurePerl).

See to L<Text::CSV_XS/DIAGNOSTICS> and L<Text::CSV_PP/DIAGNOSTICS>.


=head1 DYNAMIC MODE

When Text::CSV is installed, used worker module's methods are
copied into Text::CSV symbol tables.

But If you C<use> Text::CSV specifying C<-dynamic>, you can set C<module> option
in C<new> which changes the worker module.

 use Text::CSV -dynamic; # the worker module is Text:CSV_XS

 my $csv = Text::CSV->new({module => 'Text::CSV_PP'});


C<$csv> used Text::CSV_PP. This feature is so experimental that may be removed.

Note:

 %attr = (module => 'Text::CSV_PP');
 my $csv = Text::CSV->new(\%attr);

The hash key 'module' is C<delete>d in C<new()>, so it is also deleted from %attr.

If you specify 'module' in non-dynamic mode, Text::CSV C<croak>s.

=head1 TODO

=over

=item Wrapper mechanism

Currently the wrapper mechanism is to change symbolic table for speed.

 for my $method (@PublicMethods) {
     *{"Text::CSV::$method"} = \&{"$class\::$method"};
 }

But how about it - calling worker module object?

 sub parse {
     my $self = shift;
     $self->{_WORKER_OBJECT}->parse(@_); # XS or PP CSV object
 }

In version 0.99_05, 'dynamic mode' was introduced experimentally.
See to L</DYNAMIC MODE>


=item Simple option

 $csv = Text::CSV->simple;

is equivalent to

 $csv = Text::CSV->new ({
     quote_char          => '"',
     escape_char         => '"',
     sep_char            => ',',
     eol                 => '',
     binary              => 1,
     allow_loose_quotes  => 1,
     allow_loose_escapes => 1,
     allow_whitespace    => 1,
 });

Is it needless?


=back

See to L<Text::CSV_XS/TODO> and L<Text::CSV_PP/TODO>.


=head1 SEE ALSO

L<Text::CSV_PP(3)> and L<Text::CSV_XS(3)>.


=head1 AUTHORS and MAINTAINERS

Alan Citterman F<E<lt>alan[at]mfgrtl.comE<gt>> wrote the original Perl
module. Please don't send mail concerning Text::CSV to Alan, as
he's not a present maintainer.

Jochen Wiedmann F<E<lt>joe[at]ispsoft.deE<gt>> rewrote the encoding and
decoding in C by implementing a simple finite-state machine and added
the variable quote, escape and separator characters, the binary mode
and the print and getline methods. See ChangeLog releases 0.10 through
0.23.

H.Merijn Brand F<E<lt>h.m.brand[at]xs4all.nlE<gt>> cleaned up the code,
added the field flags methods, wrote the major part of the test suite,
completed the documentation, fixed some RT bugs. See ChangeLog releases
0.25 and on.

Makamaka Hannyaharamitu, E<lt>makamaka[at]cpan.orgE<gt> wrote Text::CSV_PP
which is pure perl version of Text::CSV_XS.

New Text::CSV (since 0.99) is maintained by Makamaka.


=head1 COPYRIGHT AND LICENSE

Text::CSV

Copyright (C) 1997 Alan Citterman. All rights reserved.
Copyright (C) 2007 Makamaka Hannyaharamitu.


Text::CSV_PP:

Copyright (C) 2005-2007 Makamaka Hannyaharamitu.


Text:CSV_XS:

Copyright (C) 2007-2007 H.Merijn Brand for PROCURA B.V.
Copyright (C) 1998-2001 Jochen Wiedmann. All rights reserved.
Portions Copyright (C) 1997 Alan Citterman. All rights reserved.


This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
