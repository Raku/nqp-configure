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

A `NQP::Config` object manages a collection of configurations stored as a list. Whenever a configuration variable is
requested its being searched in the list from the bottom to the top. The topmost configuration does not belong to the
list and stored in `config` key on the object itself. Each entry in the list is called _context_ because it might be
created by some configuration subsystems for a limited period of time and be destroyed when no long needed. So, we can
say that a configuration variable has a value in a certain context.

However, contexts are a little more than chunks of configuration. A context is a hash where configuration is defined by
`configs` key. Other key names are not reserved by now and can be used for holding any useful information. They're
called _properties_ and can be requested with method `prop`. From this point of view attribute keys on the configuration
object itself are the top-level properties, similar to `config` key been the top-level configuration.

Note that configuration keys is using plural form of its name `configs`. This is because it is a list too, a list of
configuration hashes in this case. Though it seems somewhat overcomplicated but there is a good explanation for this:
sometimes a context config chunk is being assembled from several pieces; while merging of hashrefs in Perl5 is
terrible...

Another tricky part is that chunks in the context list are searched for a variable in top-to-bottom order. This is
because the first chunk in the context is considered the base to which other chunks can only append missing variables.

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

- `config` the top-level hash of configuration variables
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
