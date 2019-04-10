#
use v5.10.1;
use strict;
use warnings;

package NQP::Macros::_Err;
use Scalar::Util qw<blessed>;
use Carp qw<longmess>;
use Data::Dumper;

our @CARP_NOT = qw<NQP::Macros::_Err>;

sub new {
    my $class = shift;
    my $msg   = shift;
    my $self  = bless {
        err       => $msg,
        callstack => longmess(""),
        @_,
    }, $class;
    return $self;
}

sub throw {
    my $self = shift;

    unless ( blessed($self) ) {
        if ( ref( $_[0] ) && UNIVERSAL::isa( $_[0], __PACKAGE__ ) ) {
            $_[0]->throw;
        }
        $self = $self->new(@_);
    }

    die $self;
}

sub message {
    my $self = shift;
    my $err  = $self->{err};
    chomp $err;
    my @msg    = $err;
    my $level  = 1;
    my $indent = sub {
        my $spcs = "  " x $level;
        return map { $spcs . $_ } split /\n/s, shift;
    };

    my $file = "*no file?*";
    my @contexts =
      $self->{contexts}
      ? @{ $self->{contexts} }
      : ( $self->{macro_obj} ? ( $self->{macro_obj}->cfg->contexts ) : () );
    for my $ctx (@contexts) {
        if ( my $newfile = $ctx->{including_file} || $ctx->{template_file} ) {
            $file = $newfile;
        }
        if ( $ctx->{current_macro} ) {
            push @msg,
              $indent->(
"... in macro $ctx->{current_macro}($ctx->{current_param}) at $file"
              );
            $level++;
        }
    }

    push @msg, $indent->( $self->{callstack} );
    return join( "\n", @msg );
}

package NQP::Macros;
use Text::ParseWords;
use File::Spec;
use Data::Dumper;
use Carp qw<longmess>;
use IPC::Cmd qw<can_run run>;
require NQP::Config;

my %preexpand = map { $_ => 1 } qw<
  include include_capture
  insert insert_capture insert_filelist
  expand template ctx_template script ctx_script
  sp_escape nl_escape fixup uc lc nfp abs2rel

>;

# Hash of externally registered macros.
my %external;

sub new {
    my $class = shift;
    my $self  = bless {}, $class;
    return $self->init(@_);
}

sub init {
    my $self   = shift;
    my %params = @_;

    $self->{config_obj} = $params{config};

    for my $p (qw<on_fail>) {
        $self->{$p} = $params{$p} if $params{$p};
    }

    return $self;
}

sub register_macro {
    my $self = shift;
    my ( $name, $sub, %params ) = @_;

    die "Bad macro name '$name'" unless $name && $name =~ /^\w+$/;
    die "Macro sub isn't a code ref" unless ref($sub) eq 'CODE';

    $external{$name}  = $sub;
    $preexpand{$name} = !!$params{preexpand};
}

sub cfg { $_[0]->{config_obj} }

sub fail {
    my $self = shift;
    my $err  = shift;

    my $msg;
    if ( ref($err) && $err->isa('NQP::Macros::_Err') ) {
        $msg = $err->message;
    }
    else {
        $msg = $err;
    }

    if ( ref( $self->{on_fail} ) eq 'CODE' ) {
        $self->{on_fail}->($msg);
    }

    die $msg;
}

sub throw {
    my $self = shift;
    my $err  = shift;
    if ( ref($err) && $err->isa('NQP::Macros::_Err') ) {
        $err->throw;
    }
    NQP::Macros::_Err->throw(
        $err,
        macro_obj => $self,
        contexts  => [ $self->cfg->contexts ],    # copy the list
        @_
    );
}

sub execute {
    my $self       = shift;
    my $macro      = shift;
    my $param      = shift;
    my $orig_param = $param;
    my %params     = @_;
    my $cfg        = $self->{config_obj};
    my $file = $cfg->prop('including_file') || $cfg->prop('template_file');

    $self->throw("Macro name is missing in call to method execute()")
      unless $macro;

    my $s = $cfg->push_ctx(
        {
            current_macro => $macro,
            current_param => $orig_param,
            configs       => [
                {
                    current_macro => $macro,
                },
            ],
        }
    );

    my $method;

    if ( $external{$macro} ) {
        $method = $external{$macro};
    }
    else {
        $method = $self->can("_m_$macro");
    }

    $self->throw("Unknown macro $macro") unless ref($method) eq 'CODE';

    if ( !$params{no_preexapnd} && $preexpand{$macro} ) {
        $param = $self->_expand($param);
    }

    my $out;
    eval { $out = $self->$method($param); };
    if ($@) {
        $self->throw( $@, callstack => longmess("") );
    }
    return $out;
}

sub expand {
    my $self = shift;
    my $out;
    eval { $out = $self->_expand(@_) };
    if ($@) {
        $self->fail($@);
    }
    return $out;
}

sub _expand {
    my $self = shift;
    my $text = shift;

    $self->throw("Can't expand undefined value") unless defined $text;
    return $text if index( $text, '@' ) < 0;

    my %params = @_;

    my $cfg    = $self->{config_obj};
    my $config = $cfg->{config};

    my $mobj = $self;

    if ( $params{isolate} ) {
        $mobj = NQP::Macros->new( config => $cfg );
    }

    my $text_out = "";

    # @mfunc()@ @!mfunc()@
    while (
        $text =~ /
                 (?<text>.*? (?= @ | \z))
                 (
                     (?<msym> (?: @@ | @))
                     (?:
                         (?<macro_var> \w [:\w]* )
                       | (?: (?<mfunc_noexp>!)? (?<macro_func> \w [:\w]* )
                           (?>
                             \( 
                               (?<mparam>
                                 (
                                     (?2)
                                   | [^\)]
                                   | \) (?! \k<msym> )
                                   | \z (?{ $self->throw( "Can't find closing \)$+{msym} for macro '$+{macro_func}' after $+{text}" ) })
                                 )*
                               )
                             \) 
                           )
                       )
                       | \z
                     )
                     \k<msym>
                 )?
                /sgcx
      )
    {
        my %m = %+;
        $text_out .= $m{text} // "";
        my $chunk;
        if ( $m{macro_var} ) {
            $chunk = $cfg->cfg( $m{macro_var} ) // '';

            #$self->throw( "No configuration variable '$m{macro_var}' found" )
            #  unless defined $chunk;
        }
        elsif ( $m{macro_func} ) {
            my %params;
            $params{no_preexapnd} = !!$m{mfunc_noexp};
            $chunk = $mobj->execute( $m{macro_func}, $m{mparam}, %params );
        }

        if ( defined $chunk ) {
            $text_out .=
                $m{msym} eq '@@'
              ? $mobj->_m_sp_escape($chunk)
              : $chunk;
        }
    }

    return $text_out;
}

sub inc_comment {
    my $self    = shift;
    my $comment = shift;

    chomp $comment;

    my $len = length($comment) + 4;
    my $bar = '#' x $len;
    return "$bar\n# $comment #\n$bar\n";
}

sub cur_file {
    my $self = shift;
    my $cfg  = $self->{config_obj};
    return $cfg->prop('including_file') || $cfg->prop('template_file');
}

sub is_including {
    my $self = shift;
    my $file = shift;
    my $cfg  = $self->{config_obj};

    for my $ctx ( $cfg->contexts ) {
        return 1
          if $ctx->{including_file}
          && File::Spec->rel2abs( $ctx->{including_file} ) eq
          File::Spec->rel2abs($file);
    }
    return 0;
}

sub include {
    my $self      = shift;
    my $filenames = shift;
    my @filenames = ref($filenames) ? @$filenames : shellwords($filenames);
    my %params    = @_;
    my $text      = "";
    my $cfg       = $self->{config_obj};

    $params{required} //= 1;

    my %tmpl_params;
    for my $p (qw<subdir subdirs subdirs_only>) {
        $tmpl_params{$p} = $params{$p} if $params{$p};
    }

    for my $file ( map { $self->_m_unescape($_) } @filenames ) {
        next unless $file;
        $file = $cfg->template_file_path( $file, required => 1, %tmpl_params );
        my $ctx = $cfg->cur_ctx;
        $self->throw( "Circular dependency detected on including $file"
              . $cfg->include_path )
          if $self->is_including;
        $ctx->{including_file} = $file;
        $text .= $self->inc_comment("Included from $file")
          unless $params{as_is};
        $text .= $self->_expand( NQP::Config::slurp($file) )
          unless $params{no_expand};
        $text .= $self->inc_comment("End of section included from $file")
          unless $params{as_is};
    }
    return $text;
}

sub not_in_context {
    my $self = shift;
    my $cfg  = $self->{config_obj};
    my ( $ctx_name, $ctx_prop ) = @_;
    if ( $cfg->prop($ctx_prop) ) {
        my $tip = "";
        if ( $cfg->in_ctx( current_macro => 'include' ) ) {
            $tip =
              " Perhaps you should use ctx_include macro instead of include?";
        }
        $self->throw("Re-entering $ctx_name context is not allowed.$tip");
    }
}

sub backends_iterate {
    my $self = shift;
    my $cfg  = $self->{config_obj};

    $self->not_in_context( backends => 'backend' );

    my $cb = shift;

    for my $be ( $cfg->active_backends ) {
        my %config = (
            ctx_subdir     => $be,
            backend_subdir => $be,
            backend        => $be,
            backend_abbr   => $cfg->backend_abbr($be),
            backend_prefix => $cfg->backend_abbr($be),
        );
        my $be_ctx = {
            backend => $be,
            configs => [ $cfg->{impls}{$be}{config}, \%config ],
        };
        my $s = $cfg->push_ctx($be_ctx);
        $cb->(@_);
    }
}

sub find_filepath {
    my $self      = shift;
    my $filenames = shift;
    my %params    = @_;
    my @filenames = shellwords($filenames);
    my $cfg       = $self->{config_obj};
    my @out;

    my $where = $params{where} // 'templates';
    delete $params{where};

    for my $src (@filenames) {
        if ( $where eq 'build' ) {
            push @out, $cfg->build_file_path( $src, required => 1, %params );
        }
        else {
            push @out, $cfg->template_file_path( $src, required => 1, %params );
        }
    }

    return join " ", @out;
}

# include(file1 file2)
# Include a file. Parameter is expanded first, then the result is used a the
# file name. File content is expanded.
# Multiple filenames are split by spaces. If file path contains a space in it it
# must be quoted with \
sub _m_include {
    shift->include(shift);
}

# insert(file1 file2)
# Similar to include() but insert files as-is, no comments added.
sub _m_insert {
    shift->include( shift, as_is => 1 );
}

# ctx_include(file1 file2)
# Same as include but only looks in the current context subdir.
sub _m_ctx_include {
    shift->include( shift, subdirs_only => 1 );
}

# ctx_insert(file1 file2)
# Same as insert but only looks in the current context subdir.
sub _m_ctx_insert {
    shift->include( shift, as_is => 1, subdirs_only => 1 );
}

# for_backends(text)
# Iterates over active backends and expands text in the context of each backend.
sub _m_for_backends {
    my $self = shift;
    my $text = shift;

    my $out = "";

    my $cb = sub {
        $out .= $self->_expand($text);
    };

    $self->backends_iterate($cb);

    return $out;
}

# expand(text)
# Simply expands the text. Could be useful when:
# @expand(@!nfp(@build_dir@/@macro(...)@)@)@
# In this case under windows @!nfp()@ will result in @build_dir@\@macro(...)@
# line.  @expand()@ will then finish the expansion. This is important because
# @build_dir@ under Windows will already have backslashes in the path.
# NOTE that the input of expand() is pre-expanded first. So, use with extreme
# care!
sub _m_expand {
    my $self = shift;
    my $text = shift;
    my $out  = $self->_expand($text);
}

# template(file1 file2)
# Finds corresponding template file for file names in parameter. Templates are
# been searched in templates_dir and possibly ctx_subdir if under a context.
sub _m_template {
    my $self = shift;
    return $self->find_filepath( shift, where => 'template', );
}

# ctx_template(file1 file2)
# Similar to template but looks only in the current context subdir
sub _m_ctx_template {
    my $self = shift;
    return $self->find_filepath(
        shift,
        where        => 'template',
        subdirs_only => 1,
    );
}

# script(file1 file2)
# Similar to the template above but looks in tools/build directory for files
# with extensions .pl, .nqp, .p6.
sub _m_script {
    my $self = shift;
    return $self->find_filepath( shift, where => 'build', );
}

# ctx_script(file1 file2)
# Similar to script but looks only in the current context subdir
sub _m_ctx_script {
    my $self = shift;
    return $self->find_filepath( shift, where => 'build', subdirs_only => 1, );
}

# include_capture(command line)
# Captures output of the command line and includes it.
sub _m_include_capture {
    my $self = shift;
    my $text = $self->_m_insert_capture(@_);
    return
        "\n"
      . $self->inc_comment("Included from `$_[0]`")
      . $text
      . $self->inc_comment("End of section included from `$_[0]`");
}

# insert_capture(command line)
# Captures output of the command line and inserts it.
sub _m_insert_capture {
    my $self     = shift;
    my $cfg      = $self->{config_obj};
    my $cmd_line = shift;
    my $cmd      = ( shellwords($cmd_line) )[0];
    $self->throw("No executable '$cmd' found") unless can_run($cmd);
    my $out;
    my ( $ok, $err ) = run( command => $cmd_line, buffer => \$out );
    $self->throw("Failed to execute '$cmd_line': $err\nCommand output:\n$out")
      unless $ok;
    return $self->_expand($out);
}

# fixup(makefile rules)
# Fixup input makefile rules. I.e. changes dir separators / for current OS and
# install timing measure where needed.
sub _m_fixup {
    my $self = shift;
    my $text = shift;
    return $self->{config_obj}->fixup_makefile($text);
}

# insert_filelist(filename)
# Inserts a list of files defined in file filename. File content is not
# expanded.
# All file names in the list will be indented by 4 spaces except for the first
# one.
sub _m_insert_filelist {
    my $self   = shift;
    my $cfg    = $self->{config_obj};
    my $indent = " " x ( $cfg->{config}{filelist_indent} || 4 );
    my $file   = $cfg->template_file_path( shift, required => 1 );
    my $text   = NQP::Config::slurp($file);
    my @flist  = map { NQP::Config::nfp($_) } grep { $_ } split /\s+/s, $text;
    $text = join " \\\n$indent", @flist;
    return $text;
}

# sp_escape(a string)
# Escapes all spaces in a string with \
# Implicitly called by @@ macros
sub _m_sp_escape {
    my $self = shift;
    my $str  = shift;
    $str =~ s{ }{\\ }g;
    $str;
}

# nl_escape(a string)
# Escapes all newlines in a string with \.
sub _m_nl_escape {
    my $self = shift;
    my $str  = shift;
    $str =~ s{(\n)}{\\$1}g;
    $str;
}

# unescape(a\ st\ring)
# Simlpe unescaping from backslashes. Replaces any \<char> sequence with <char>
sub _m_unescape {
    my $self = shift;
    my $str  = shift;
    $str =~ s/\\(.)/$1/g;
    return $str;
}

# Iterate over whitespace separated list and execute callback for non-ws elems.
sub _iterate_ws_list {
    my $self = shift;
    my $cb   = shift;
    $self->throw("_iterate_filelist callback isn't a code ref")
      unless ref($cb) eq 'CODE';
    my @elems = split /(\s+)/s, shift;
    my $out   = "";
    while (@elems) {
        my ( $file, $ws ) = ( shift @elems, shift @elems );
        if ($file) {    # If text starts with spaces $file will be empty
            $file = $cb->($file);
        }
        $out .= $file . ( $ws // "" );
    }
    return $out;
}

# nfp(dir/file)
# Normalizes a Unix-style file path for the current OS. Mostly for replacing
# / with \ for Win*
sub _m_nfp {
    my $self = shift;
    return $self->_iterate_ws_list( sub { NQP::Config::nfp( $_[0] ); }, shift );
}

# abs2rel(file1 file2)
# Converts absolute file path into relative to @base_dir@
sub _m_abs2rel {
    my $self     = shift;
    my $base_dir = $self->cfg->cfg('base_dir');
    return $self->_iterate_ws_list(
        sub {
            NQP::Config::nfp(
                File::Spec->abs2rel(
                    File::Spec->rel2abs( $_[0], $base_dir ), $base_dir
                )
            );
        },
        shift
    );
}

# uc(str)
# Converts string to all uppercase
sub _m_uc {
    uc $_[1];
}

# lc(str)
# Converts string to all lowercase
sub _m_lc {
    lc $_[1];
}

# varinfo(var1 var2 ...)
# Dumps information about the context where the variable is defined.
sub _valstr { defined $_[0] ? $_[0] : '*undef*' }

sub _varinfo {
    my $self  = shift;
    my $param = shift;
    my %params = @_;
    my @vars  = shellwords($param);

    my $max_key_length = 10;

    my $rep = sub {
        my ( $key, $val ) = @_;
        $max_key_length = length $key if length $key > $max_key_length;
        return [ $key, _valstr($val) ] unless ref($val);
        local $Data::Dumper::Terse = 1;
        my @lines = split /\n/s, Dumper($val);
        my @rc    = [ $key, _valstr( shift @lines ) ];
        push @rc, map { [ '', _valstr($_) ] } @lines;
        return @rc;
    };

    my $out = "\n";
    my @report;
    for my $var (@vars) {
        my ( $val, $ctx ) = $self->cfg->cfg( $var, with_ctx => 1 );
        push @report, "*** Variable $var", [ VALUE => $val ];
        if ($ctx) {
            my $from = $ctx->{'.ctx'}{from};
            push @report,
                "*** Containting context created by "
              . "$from->{sub} "
              . "at $from->{file}:$from->{line}", "*** Context keys:";
            for my $ckey ( sort keys %$ctx ) {
                next if $ckey =~ /^(?:configs|\.ctx)$/;
                push @report, $rep->( $ckey, $ctx->{$ckey} );
            }

            push @report, "*** Context configuration variables:";

            for my $config ( @{ $ctx->{configs} } ) {
                for my $ckey ( sort keys %$config ) {
                    push @report, $rep->( $ckey, $config->{$ckey} );
                }
            }
        }
        else {
            push @report, "*** Not from a context ***";
        }
        push @report, "*** End of variable $var";
    }

    for my $rline (@report) {
        my $line;
        if ( ref($rline) ) {
            $line = sprintf( "%-${max_key_length}s: %s", @$rline );
        }
        else {
            $line = $rline;
        }
        $out .= "# $line\n";
    }
    print $out if $params{console};
    return $out;
}

sub _m_varinfo {
    my $self = shift;
    return $self->_varinfo(shift);
}

sub _m_print_varinfo {
    my $self = shift;
    return $self->_varinfo(shift, console => 1);
}

1;
