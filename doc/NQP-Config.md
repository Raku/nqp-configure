# NAME

NQP::Config

# SYNOPSIS

```
use NQP::Config;
use NQP::Config::Rakudo; # The language we're building

my $cfg = NQP::Config::Rakudo->new;

my $config = $cfg->config( no_ctx => 1 );

$config->{a_variable} = "a value"; # This can be later expanded as @a_variable@ by macros in a template.

$cfg->configure_paths;
$cfg->configure_from_options;

...

$cfg->expand_template;

...
```

# DESCRIPTION

This is a helper module for build a language from NQP/Perl6 family. It provides basic utility methods,
`configure_`-family methods for presetting environment-dependent values, and methods to manipulate this data.

`NQP::Config` is a base (_abstract_) class which has to be inherited and completed by a language-specific class. See
[`NQP::Config::NQP`](https://github.com/perl6/nqp/blob/master/tools/lib/NQP/Config/NQP.pm) and
[`NQP::Config::Rakudo`](https://github.com/rakudo/rakudo/blob/master/tools/lib/NQP/Config/Rakudo.pm) classes from `nqp`
and `rakudo` implementations.

## Concepts

### Configuration

A hash of _configuration variables_ as keys with their values.

### Configuration Context

Usually referred as just _context_.

A `NQP::Config` object manages a collection of configurations stored as a stack-like list. Whenever a configuration
variable is requested its being searched in the list from top to bottom. The bottommost configuration does not belong to
the list and is stored in `config` key on the object itself. Each entry in the list is called _context_ because it might
be created by some configuration subsystems for a limited period of time and be destroyed when no long needed. So, we
can say that a configuration variable has a value in a context.

However, contexts are a little more than chunks of configuration. A context is a hash where configuration is defined by
`configs` key. Other key names are not reserved by now and can be used for holding any useful information. They're
called _properties_ and can be requested with method `prop`. From this point of view attribute keys on the configuration
object itself are the bottom-level properties, similar to `config` key been the bottom-level configuration.

Note that configuration keys is using plural form of its name `configs`. This is because it is a list too, a list of
configuration hashes in this case. Though it seems somewhat overcomplicated but there is a good explanation for this:
sometimes a context config chunk is being assembled from several pieces; while merging of hashrefs in Perl5 is
terrible...

Another tricky part is that chunks in the context list are searched for a variable in start-to-end order. This is
because the first chunk in the context is considered the base to which other chunks can only append missing variables.

### Backends



### Options

They should be called 'command line options', but a short form is a short form! It's too attractive for lazy ones...

_Note_ that options can only be set from the command line and their alteration is better be avoided at any cost. This is
our initial status which is to be used as the ground for all decisions we make. If an option or its default value is
needed to be reconsidered during configuration process then it's value must be cloned and either stored on the
configuration object itself; or used as a configuration variable. The latter is preferable. If the value is a boolean
and the option of setting a configuration variable is chosen then it is recommended to use some user-readable values.
For example, marking a relocatable build variable `relocatable` is set to `reloc`; and to `nonreloc` otherwise. Though
this might complicate some code a bit it provides a better way to use these variable in templates when necessary:

```
@template(nqp-m-@relocatable@)@
```

Nobody would object that having `nqp-m-reloc` and `nqp-m-nonreloc` template files is preferable over `nqp-m-1` and
`nqp-m-0`.

### Scoping Object

An instance of `NQP::Config::_Scoping` class which would execute a callback when destroyed. Usually used to auto-delete
a context when code is leaving a scope.

# ATTRIBUTES

Because `NQP::Class` is build using barebones Perl5 OO implementation, there're no attributes as such. We're listing
here keys on a `NQP::Class` instance.

_Some irrelevant and internally used keys would miss a description. They're only listed here to avoid being accidentally
used by a child class._

- `config` the main (bottommost) hash of configuration variables
- `quiet` is a boolean; _true_ if minimal output is requested by a user
- `backend_prefix` - mapping of full backend names into short aliases
- `abbr_to_backend` – reverse mapping of `backend_prefix`
- `backend_order` - default order (kinda priority) of backends
- `active_backends_order`
- `options` - a hash of parsed command line options (see `Getopt::Long`). Must be set by a `Configure` script:

  ```
  GetOptions( $cfg->options, ... );
  ```

  _Note_ that as it was already stated _Options_ section, values in this hash are not to be changed unless absolutely,
  unavoidably necessary.

- `contexts` - list of contexts
- `repo_maps`
- `impls` contains data structures related to backend implementations
- `backend_errors`
- `expand_as_is` - boolean; _true_ if template must be expanded as-is, without adding informational comments
- `out_header`
- `template` is a file which is being expanded
- `out` is a file where expanded output is send to

Use of the keys directly should be avoided as much as possible by external scripts and reduced to reasonable levels by
child classes. Methods are always preferable.

# METHODS

## Class Level

### `new(%params)`

Constructor

### `init(%params)`

Initializer. Called by `new`. Can be overriden by a child class but must not be called manually.

## Utility Methods

### `msg(@message)`

Outputs a message to the console unless `quiet` attribute is true. Usually recommended over `say` or `print` unless
`note` or `sorry` methods apply.

### `mute($on)`

Sets `quiet` attribute-flag to `$on` or to a _true_ value if used without an argument.

### `note($type, @message)`

For cases where a notice must be output which is not a subject for `quiet`ness and requires user attention. `$type` is
a short message explaining what type of notice we're printing. It's a free-form, but words like `ATTENTION` or 'WARNING'
are recommended. A typical output would look like:

```
===ATTENTION===
  The information we want the user to see
  goes here and it is indented for clearer look.
```

### `sorry(@messages)`

This method outputs a `===SORRY!===` message. For historical reasons it treats it's parameters differently. Where `note`
considers them a single message, `sorry` expects a list of messages. Each will be output on a new lines with on common
`===SORRY!===` prefix.

Usually, calling `sorry` causes a script to die unless `ignore-errors` [option](#Options) is set.

### `shell_cmd`

Return current platform's shell. Basically, `cmd` for Win* and `sh` for others.

### `batch_file($file)`

Takes a single parameter and forms a valid script name depending on the current platform. I.e. will append `.bat` on
Win* if needed.

### `make_cmd`

Determines what command is to be used as `make` depending on the current platform. Would mostly result in `make`,
`nmake` on Win*, and may return `gmake` on BSD family.

### `options`

Return `options` hash.

### `option($opt)`

Returns a option `$opt` or _undef_ if its doesn't exists.

### `has_option($opt)`

Returns _true_ if option `$opt` exists. It may not necessarily be defined though.

### `validate_backend($backend, $method)`

Dies if `$backend` is not supported. Error message would inform method name if `$method` is defined.

Returns `$backend`

### `known_backends`

Return a list of supported backends.

### `known_backend($backend)`

Returns _true_ if `$backend` is supported.

### `known_abbrs`

Returns a list of short names of supported backends.

### `abbr_to_backend($backend_abbreviation)`

Maps short backend name to its full form. Like _"j"_ -> _"jvm"_.

### `backend_abbr($backend)`

Returns `$backend` short name.

### `backend_config($backend [, %config])`

If supplied with `key => value` pairs (`%config`) then this method will store them in a backend-specific configuration
hash. If a key already exists it will be overwritten.

Returns backend-specific configuration hash.

### `use_backend($backend)`

Activates a `$backend` for build. This includes:

- appending of the backend to the list of active ones. It means `active_backends_order` content depends in what order
  the backends were activated.
- if no other backends were activated yet, the `default_backend` configuration variable is set to `$backend`

If the method is called for the second time with the same parameters it returns without any actions taken.

### `active_backends`

Returns a list of activated backends.

### `active_backend($backend)`

Returns _true_ if `$backend` is activate.

### `active_abbrs`

Returns a list of short names of active backends.

### `base_path($relative_path)`

Takes a relative path and prepends it with `base_dir`. If the parameter happens to be an absolute path it is returned as
is then.

### `configure_platform`

The only method of `configure_*` family which is used by `NQP::Config` itself. It presets configuration values specific
to the current platform.

### `configure_*`

Methods from this family are to be used by a `Configure.pl` script to actually perform configuration tasks. Of those

- `configure_backends`
- `configure_misc`

are _abstract_ and have to be implemented by child classes.

### `parse_backends($cli_backends)`

Parses what is passed with `--backends`.

### `backend_error($backend, @msgs)`

Stores error messages related to a `$backend`.

### `backend_errors($backend)`

Returns a list or arrayref (context dependant) of stored errors for a `$backend`.

### `expand_template`

Expands the default template (see [attribute](#ATTRIBUTES) `template`). The result of expansion goes into file specified
by `out` attribute. If `out_header` attribute is defined it's prepended to the expanded text.

See more details in [macro expansion docs](https://github.com/perl6/nqp-configure/blob/master/doc/Macros.md).

### `save_config_status`

Creates `config.status` file in `base_dir` using content of `@lclang@_config_status` configuration variable.

### `opts_for_configure(@opts)`

Generate command line options for subsequent `Configure.pl` calls based on the information collected so far; mostly
on based upon user-specified command line options.

Returns list of options or space-concatenated string made of the list depending on the call context.

_NOTE:_ Subsequent calls are the calls made after the main run which creates `Makefile`. They're made by the `Makefile`
receipts and currently their sole purpose is to expand other templates the way they would be expanded by the main run
but at the time of the build process.

### `make_option($opt[, no_quote => 1])`

Generates a command line option for a subsequent call to a `Configure.pl` based on options provided by the user. The
option value is shell-quoted unless `no_quote` parameter is _true_.

### `ignorable_opts`

Returns a list of options to be ignored when building a command line for subsequent calls to `Configure.pl`.

A language-specific child class can override this method.

### `is_win`, `is_solaris`, `is_bsd`, `isa_unix`

Shortcuts for checking what our platform is.

### `is_executable($file)`

Returns _true_ if `$file` is an executable.

### `github_url($protocol, $user, $repo)`

Builds URL for a github repository based on requested protocol. The protocol could be either _"git"_ or _"https"_.
`$user` is github's user account which owns the repository `$repo`.

### `repo_url($repo_alias[, %params])`

Higher level github URL builder. `$repo_alias` is a key from `repo_maps` attribute: one of _moar_, _nqp_, _rakudo_, or
_roast_ values. The following keys can be used in `%params`:

- `action` – `git` action we're requesting the URL for. For now only _push_ and _pull_ are supported.
- `protocol` – `git` protocol. See `github_url`

_Note_ that for `push` action only `git` protocol is valid.

### `find_file_path($short_name, %params)`

Finds a file defined `$short_name` in specified subdirectories. Returns file name with path if found or empty string
otherwise.

`%params` can have the following keys:

- `where` - which base directory we're lookin in. Currently it could be either _templates_ or _build_. But any other
  word can be used as long as there is a configuration variable `${where}_dir`.
- `subdir` – single directory name to look in. Appended to `$where` directory.
- `subdirs` - a list of directories.
- `subdirs_only` – boolean. If _true_ then file isn't searched in `$where` dir itself, only in subdirectories of it.
  For example, one can limit the search of a `Makefile` template by platform of backend directories avoiding the
  universal `Makefile` template.
- `suffix` - suffix to be appended to `$short_name`.
- `suffixes` - list of `suffix`'es. To look for a file without a suffix too this list must contain an empty string.
- `required` - if its _true_ then the method dies when no file is found.

Implicitly the routine is also using `ctx_subdir` configuration variable as a `subdir`. It can be set by iterators which
create contexts to look in a context-specific location. For example, an iterator over active backends can set this
variable on a per-context basis and execute a callback where a template is requested. The callback doesn't need to worry
about where to look for its templates as this would be done automatically.

### `template_file_path($template, %params)`

A shortcut to call:

```
$cfg->find_file_path(
    $template,
    where    => 'templates',
    suffixes => [ ".$platform", ".in", "" ],
    %params
);
```

### `build_file_path($file_name, %params)`

A shortcut to call:

```
$cfg->find_file_path(
    $file_name,
    where    => 'build',
    suffixes => [ qw<.pl .nqp .p6>, "" ],
    %params
);
```

### `fill_template_file($infile, $outfile, %params)`

Expand `$infile` into `$outfile`. `$outfile` could be a file name or an opened file handle. `$infile` could be a single
template name or an arrayref of templates. If `$infile` is a list then all templates are expanded into a single
`$outfile`.

For each template being expanded the method creates a context with `template_file` property and a configuration variable
of the same name. Both are holding the template file path.

In the output result of each template file expansion is wrapped into a pair of _"# Generated from <template>"_ /
_"# (end of section generated from <template>)"_ commetns unless `as_is` key in `%params` is _true_.

The actual expansion is done by `fill_template_text` method.

### `fill_template_text($text, %params)`

Expands `$text` by creating an instance of `NQP::Macros` class and calling its `expand` method on the text. Passes
`$self` as the configuration object for the `NQP::Macros` instance.

If the expanded text contains _"nqp::makefile"_ string then additionally passes it through `fixup_makefile` method.

Returns the expanded text.

### `fixup_makefile($text)`

This method tries to prepend commands in `Makefile` receipts with `time` utility if `makefile_timing` configuration
variable is _true_. Must be replaced with a dedicated macro.

### `git_checkout($repo, $dir, $branch)`

Checkouts a repository specified by its short name `$repo` (see `repo_maps` attribute) into a directory `$dir`. By
_checkout_ we mean either `clone` or `fetch`, depending on the existence of `$dir`.

`$branch` defined what specific branch is requested if defined.

Method dies if `git` command fails.

### `contexts`

Returns a list of context hashes. For the simplicity of searching, the list is returned in reverse order so that when
searching for a property or a configuration variable iteration could be done in strait direction.

### `cur_ctx`

Returns currently active context.

### `push_ctx($ctx)`

Pushes a context hash to the list. Returns a scoping object which upon destruction will delete the context from the
list. So, normally adding a context is:

```
foreach my $backend ( $self->active_backends ) {
    my $scoping = $self->push_ctx(
            {
                configs => [ { backend => $backend } ],
            }
    );

    ... # Do our work
}
```

As soon as a single loop iteration ends `$scoping` will go out of scope and will be destroyed effectively deactivating
the context.

_NOTE_ that strictly saying contexts are not a stack because it is possible for the scoping object to either be
preserved and used outside of a scope or be deleted any time, even if other contexts were pushed later. So, the only
reason to consider the list as a stack-like structure is the way we look for data in it.

### `pop_ctx`

Deletes last pushed context. Usually is not needed.

### `push_config({ $config | %config })`

Shortcut for pushing just a single configuration hash onto the context list. Parameters could be either a hashref or
list of `key => value` pairs.

Returns a scoping object.

### `config(%params)`

Returns a configuration hash. Depending on a parameter the hash could be:

- the `config` attribute itself, no contexts added, `no_ctx` parameter is _true_.
- otherwise it's a result of summing up the base configuration hash with all currently active contexts.

### `cfg($variable, %params)`

Fetches a configuration variable. The variable is looked through contexts first then in the `config` attribute. If
parameter `strict` is _true_ and no variable is found then method dies.

Returns the value of the variable or _undef_ if not found and `strict` is not set. In array context if `with_ctx`
parameter is set will return a list of the value and the context hash where the variable was located.

### `set($variable, $value[, in_ctx => 1])`

Set a configuration variable. If `in_ctx` parameter is set the variable will be set in the topmost context. Otherwise
the value in the `config` attribute is changed.

### `prop($property[, strict => 1])`

Looks for a `$property` in the contexts. If not found then tries the configuration object itself. If property is not
found but `strict` is set then dies.

### `in_ctx($property, $value)`

Locates the context where `$property` is defined and has value `$value`.

Returns the context hash.

### `shell_quote_filename($filename)`

Quotes/escapes `$filename` in accordance to the current platform's rules.

### `nfp($filename)`

The name stands for Normalize File Path. Takes a file path in Unix-like format and converts it to match the current
platform rules. For example, for Windows it means replacing `/` directory seprators with `\`.

Returns normalized file name.

### `c_escape_string($string)`

Escapes a string for use in `C` source code.

# ROUTINES

### `slash`

Returns platform-specific path separator.

### `slurp($file)`

Returns `$file` content as a single line.

### `os2platform([$os])`

Maps operation system to a family of platforms. For example, Windows and OS/2 would map into family `windows`.

See `%os_platforms` hash in the beginning of the module source.

### `rm_l`

Similar to `ExtUtils::Command` `rm_*` exports. Deletes symlinks.

### `system_or_die(@cmd)`

Tries to execute `@cmd` with `system` routine. Dies if exit code is not 0.

### `run_or_die($cmd, %params)`

Intended as a replacement for `qx{command}`. Returns command output or dies if exit code is not 0.

### `parse_revision($rev)`

Parses standard revisions of `MoarVM`, `NQP`, `Rakudo`.

Returns a list of revision components.

### `cmp_rev($rev_a, $rev_b)`

Compares two revisions.

### `read_config(@sources)`

Iterates over `@sources`, treats them as executables capable of `--show-config` command line option. Reads their output,
parses and combines the result into a configuration hash which is then returned.

# SEE ALSO

- [Building Rakudo](https://github.com/rakudo/rakudo/blob/master/docs/Building-Rakudo.md)
- [Macro Expansion](https://github.com/perl6/nqp-configure/blob/master/doc/Macros.md)
