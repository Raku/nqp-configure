# NQP::Config Macro Expansion

NQP::Config expands template files using a pretty simple macro expansion. A
macro is:

* enclosed in symbols `@` or `@@` (unless escaped with `\`)
* has a name which a combination of word chars (`\w` in regexp terms) and colons
  `:` 
* can be either a configuration variable or a macro function

In this document we will call macro functions just _macro_s in this document
unless otherwise is stated explicitly.

For macros and variables defined with `@@` all horizontal whitespaces in their
resulting value will be quoted with backslash char (`\`).

## Escaping

If accidentally some text in a template forms a macro-like sequence (by *macro*
we mean both config variables and macro functions here) then it is possible to
avoid it to be treated so by escaping `@` symbol with `\`. The latter could be
duplicated to avoid be inserted as is. For example, parsing of the following
template will fail as there is no `text` macro:

```
The following @text(?)@ looks like a macro
```

But this text will expand to the above example:

```
The following \@text(?)@ looks like a macro
```

Similarly, if we need the `\` before `@` then we write it like:


```
The following \\\@text(?)@ looks like a macro
```

The escaping is not needed if `\` is located before any other character or if
`@` doesn't fall into a macro-like construct:

```
This \text would rem@in unchanged.
```

Note though that a macro function is detected by its opening brace, thus
template

```
We fail with @this(example
```

will cause a failure of closing `)@` not found.

## Configuration Variables

A configuration variable is set either from CLI options, or as a result of
detection process performed by the `Configure.pl` script, or any other source of
information.

For example, `@perl6_home@` could either be set with `--perl6-home` option of
`Configure.pl`, or set to a default value using a value from `@prefix@`
variable.

A number of variables are fetched from `NQP` and `MoarVM`. Those will have
`nqp::` and `moar::` prefixes respectively.

## Macro Functions

A macro common format is:

```
@[!]macro(text to process)@
```

Note that a macro takes no other parameters but the text to be processed. It is
up to the macro itself how to interpret the text. Since it is possible to use
nested macros, functions are generally separated into two groups:

- One group takes the input text as-is. It is then up to the macro itself at
  which point it would do the expansion.
- For another group (named _preexpanded macros_ for convenience) the text first
  gets expanded by the macros subsystem and then passed in as the parameter. 

For example:

```
@for_backends( VAR_@backend@)@
```

This macro will loop over active backends, set configuration variables
`@backend@` and `@backend_prefix@`, and the do expanstion of its parameter. Note
that pre-expansion will make its work impossible because it would receive string
`" VAR_"` as its parameter.

In some cases it is not desirable to have input text expanded even if its passed
to a pre-expanded macro. In this case the macro name must be prepended with `!`
which implicitly turns of the pre-expansion.  Here is an example:

```
@nfp(@prefix@/@custom_macro()@/@file@)@
@nfpl(dir/file1 dir/file2)@
```

`nfp` stands for _normalize file path_. It converts a Unix-style path into
a format suitable for the OS we build on. There could be a problem if `@prefix@`
is already normalized. Lets assume that `@custom_macro()@` is too, as well as
`@file@`... Generally saying, the result of normalization migh be not what we
would expect from it if it performed on pre-normalized path names.  Normally, it
is an "Ok" situation for as far as I know but nobody can guarantee that it would
be so on any existing or a future platform.

One solutions would to use `@slash@` instead of `/`. Ugly and possibly
unreliable. Wrapping each `/` with `nfp`?? Oh, no!.. But

```
@expand(@!nfp(@prefix@/@custom_macro()@/@file@)@)@
```

is considered to be the most reliable way to get the job done.

## Contexts

Contexts are a concept of `NQP::Config` module which is heavily utilized by
`NQP::Macros`. 

A context is a state structure which keeps configuration properties and
variables. While properties are not generally available for the expansion
process, configuration variables may even change their values depending on the
current context.

Contexts are stacked. The topmost one is created and filled in by the
configuration process. The every new context is pushed to the stack and kept
there until needed. For example, the `@for_backends()@` macro mentioned above
create a new context for each backend and destroys it when expansion is done for
that backend. So, for the following case:

```
@for_backends(@include(Makefile)@)@
```

we can say that the Makefile is included in a backend context.

## List Of Macros

For simplicity, macros in this section are not enclosed with `@`.

### chomp(text)

_Pre-expand_

See Perl 5 `chomp` function.

### expand(text)

_Pre-expanded_

Simply expands its parameter. Makes sense in combination with macros returning
unexpanded text. See the example with `@!nfp()` above.

### sp_escape(text)

_Pre-expanded_

Escapes horisontal whitespaces in the parameter with `\`. This is the macro used
when parser encounters a `@@` macro call.

### nl_escape(text)

_Pre-expanded_

Escapes newlines in the parameter with `\`.

### sp_unescape(text)

Very simple unescaping. Replaces all `\<char>` sequences with `<char>`.

### nfp(path/file), nfpl(path1/file1 path2/file2 ...)

_Pre-expanded_

The macro name stands for Normalize File Path. Converts Unix-style paths with
`/` directory separator into what is suitable for the current OS. Most typical
example is Windows where slashes are replaced with backslashes. 

If a path contains whitespaces it will be quoted following the quoting rules of
the current platform. For example:

```
@nfp(a\ path/to/file)@
```

will produce:

```
'a path/to/file'
```

on a \*nix platform, and

```
"a path\to\file"
```

on a DOS-like platform.

`nfpl` is a modification of nfp which acts on a whitespace separated list of
paths. So, where `nfp` takes a path as-is even if it contains spaces, `nfpl`
requires non-separating spaces to be escaped with `\`:

```
@nfpl(a\ path/to/file and/another/file)@
```

If `nfpl` text contains another macro or a configuration variable, it is
recommended to use `@@` expansion form:

```
@nfpl(@@base-dir@@/file1 @@base_dir@@/file2)@

```

But generally, `nfpl` is recommended for use on lists of simple relative paths
like `src/Perl6/Actions.nqp src/Perl6/PodActions.nqp`.

### shquot(path/file)

_Pre-expanded_

Quotes path by using rules valid for the shell of the current
platform. 

```
target: $(DEPS)
    $(PERL5) @shquot(@script(myscript.pl)@)@ --option=@shquot(I'm ok)@
```

### abs2rel(file1 file2 ...)

_Pre-expanded_

Makes all file paths relative to `@base_dir@`.

### uc(text), lc(text)

_Pre-expanded_

Convert text into all upper/lower case respectively.

### envvar(VARNAME)

Generates environment variable in the format understood by the current platform.
I.e. for `@envvar(VAR)@` it will generate `$VAR` on \*nix and `%VAR%` on
DOS-derivatives (Windows, OS/2).

### for_backends(text)

Iterates through all active backends (i.e. defined with `--backends` command
line option), sets context for each of the backend, and expands the parameter
with each context. The following variables are set for the contexts:

- `ctx_subdir` – name of the contexts subdirectory. Same as backend name.
- `backend_subdir` - same as above. Can be used when a nested macro defines own
  context with `ctx_subdir` variable.
- `backend` – just backend name.
- `backend_abbr` – backend abbreviation. I.e. `m` for `moar`, `j` for `jvm`,
  `js` for... uhm... yes, for `js`.
- `backend_prefix` - alias for `backend_abbr`.
- `bp` - '@backend_abbr@` in uppercase followed by underscore. I.e., it is
  `@uc(@backend_abbr@_)@`
- `bext` - backend precompiled file extension.

### for_specs(text)

_Defined by `NQP::Config::Rakudo` and only available for Rakudo build._

Similar to `for_backends`, but iterates over language specification revisions
(`c`, `d`, ...). Sets the following context variables:

- `ctx_subdir` - spec subdirectory, `6.<spec-letter>`
- `spec_subdir` - same as above
- `spec` - specification revision letter
- `ucspec` – same as above, but in upper case
- `lcspec` – same as above, but in guaranteed lower case.

# bsv(MVAR), bpv(MVAR), bsm(MVAR), bpm(MVAR)

All four do similar job. Names can be expanded as:

- [b]ackend
- [s]uffixed or [p]refixed
- [v]ariable or [m]acro

Taken MVAR returns either backend prefixed (`@bp@`) or suffixed (`@uc(@backend@)@`)
makefile variable or macro (`$(VARIABLE)`). For example:

```
@bsm(MYVAR)@ -> $(M_MYVAR)
```

### include(template1 template2)

_Pre-expanded_

Finds a template file, expands it and returns the result. The macro searches for
the template file in templates directory defined by `templates_dir`
confgiguration variable (`@base_dir@/tools/templates` normally). If current
context defines `ctx_subdir` variable then this subdirectory within the
templates directory is checked first. Then if no file is found the macro falls
back to the default `@templates_dir@`. 

It is a good practice to have template's filename to end with `.in` extension.
But the actual order of filenames tried check for this extension last. First the
exact name as it is passed in is checked, then `.@platform@` is tried (which
would be `.windows`, or `.unix`, or `.vms`, or whatever the current platform
is), and only then `.in` extension is tried.

For example, within the context of `@for_backends()@` macro
`@include(Makefile)@` would check the following directories in the order:

1. `@templates_dir@/moar/Makefile` (which is actually
   `@templates_dir@/@ctx_subdir@/Makefile`)
1. `@templates_dir@/@ctx_subdir@/Makefile.@platform@`
1. `@templates_dir@/moar/Makefile.in`
1. `@templates_dir@/Makefile`
1. `@templates_dir@/Makefile.@platform@`
1. `@templates_dir@/Makefile.in`

Circular dependency is a fatal condition.

The resulting text is wrapped into comments informing about where this text was
included from at the start and declaring the end of the inclusion with the file
name at the end.

### insert(template1 template2)

_Pre-expanded_

Same as `include` above but doesn't wrap the result into comments.

### ctx_include(template1 template2), ctx_insert(template1 template2)

Same as respective macros without the `ctx_` prefix but doesn't use the default
templates directory and only searching in the `@templates_dir@/@ctx_subdir@`.
Useful when templates with the same name are contained in both default and
context directories. For example, we're expanding `Makefile.in`. The the
following line:

```
@for_backends(@include(Makefile)@)
```

May result in circular dependency if a backend doesn't have its own `Makefile`
template in the context subdirectory. So, the right thing to do would be:

```
@for_backends(@ctx_include(Makefile)@)
```

### template(templatename), ctx_template(templatename)

_Pre-expanded_

Expand to the full path of a template file. The file is searched in
`@templates_dir@` similarly to `include` macro. For example, macro:

```
@template(Makefile)@
```

would expand to
`/<your-homedir>/<path-to-sources>/tools/templates/<backend>/Makefile.in`
or to `/<your-homedir>/<path-to-sources>/tools/templates/Makefile.in`
depending on the context and where the file exists.

Like any other `ctx_` macro, `ctx_include` only checks in the context subdir.

### script(scriptname), ctx_script(scriptname)

_Pre-expanded_

Similar to `template` macros, but look in `@build_dir@`. Also, instead of `.in`
suffix this macro tries appending one of `.pl`, `.nqp`, `.p6` – in this order.

### include_capture(command)

_Pre-expanded_

Executes the command and inserts its output. For example:

```
@include_capture(ls @templates_dir@)
```

would insert list of files in the default templates directory. To execute
a build script the following form is recommended:

```
@include_capture(@script(gen-js-makefile)@)@
```

The output would include both stdout and stderr of the executed subprocess in
will be wrapped into begin/end comments.

### insert_capture(command)

_Pre-expanded_

Similar to `include`, but doesn't wrap the output into begin/end comments.

### insert_filelist(template)

Inserts a list of files from a file found in `@templates_dir@` (context subdir
is respected). The file is expanded first and then treated as a list of files.
The list is considered to be whitespace-sperated (including newlines). Each file
name in the list will be normalized (i.e. passed through `nfp`) and the
result will be formatted for use in a Makefile:

* one file per line, newlines escaped with `\`
* all lines, except the first one, indented with four spaces (unless
  configuration variable `filelist_indent` specifies another amount)

### configure_opts()

Returns command line options for Configure.pl. Any input is ignored.

### if(<condition> text)

_Pre-expanded_

Returns _text_ if `<condition>` is true. The whitespace before _text_ is handled
a bit specially so that a single space character following the `condition` would
be taken away but any other whitespace symbol would be preserved. For example:

```
A@if(truevar==true B)@C
```

will result in `ABC`. But if `B` is preceeded with a tab (_\t_):

```
A@if(truevar==true\tB)@C
```

then the output would be `A\tBC`. This feature is particularly useful for
building makefile receipes:

```
target:
    @echo "Hello!"
@if(truevar==true	@run-cmd
)@
```

Condition can be of one of the following very simple forms:

- `config_variable` – checks if a configuration variable is defined
- `!config_variable` – variable is not defined
- `config_variable==value`, `config_variable!=value` – if variable value `eq` or
  `ne` to the _value_, respectively. 
 
  _Note_ that the value is used as is, no spaces allowed and no quoting/escaping
  supported for it.

With this macro it is possible build backend-dependent file lists:

```
File1
@if(backend=jvm JavaRelatedFile
)@File2
```

### perl(code)

This macro executes a Perl code snippet and returns either what the snipped
returned explicitly or what it's left in `$out`:

```
@perl(
for (1..4) { $out .= "line$_\n" }
)@
```

For ease of use, the following variables are pre-declared:

- `$macros` – object of class `NQP::Macros` which does expansions of the current template.
- `$cfg` - object of type `NQP::Config`.
- `%config` – hash of configuration variables. Incorporates all surrounding
  contexts.
- `$out` – content of this variable will be returned as macro result unless the
  snippet returns something explicitly.

### use_prereqs(text)

_Pre-expanded_

This macro must be used within a Makefile receipe context. It doesn't modify its
parameter but stores it in the context `prereqs` variable to be used by the
receipe to build its target.

For example, let's say a fictios macro `receipe` creates a receipe context:

```
@receipe(@nfp($(GEN_DIR)/foo.nqp)@: @use_prereqs($(FOO_SOURCES))@ @@other_deps@@
    cat @prereqs@ >$@)@
```

### echo(text)

_Pre-expanded_

Produce `echo` command for Makefile. Takes into consideration current platform
and quotes text properly.
 
### nop(text)

Does nothing, returns the parameter text as is. Can be used as an escape macro
in cases like the following:

```
@q(@nop($(VAR1))@@cpsep@$(VAR2))@
```

where without `@nop()@` the closing brace of `$(VAR1)` would combine with
opening `@` and form fake closing brace for `@q(`:

```
@q($(VAR1)@cpsep@$(VAR2))@
```

Would result in:

```
'$(VAR1'cpsep@$(VAR2))@
```

## Configuration variables

The following variables are set by the `NQP::Config` as defaults:

- `perl` Perl 5 executable.
- `slash` Directory separator, used by the current OS
- `shell` Default shell
- `base_dir` Where `Configure.pl` is located. In other words, the directory
  where we do the build.
- `build_dir` Where scripts and their helper files are located. Normally it
  would be `tools/build` (where otherwise is not specified, we give paths
  related to the `base_dir`)
- `templates_dir` Where template files are located. Normally it is
  `tools/templates`
- `filelist_indent` Number of spaces to indent filelists. 4 by default.
- `lang` The language we build. `NQP` or `Rakudo`.
- `lclang` Same as above but in all lowercase.
- `exe`, `bat` Extensions of executable and batch files for the current OS.
- `cpsep` Separator of pathlists for the current OS. `;` for Windows, `:`
  otherwise.
- `runner_suffix` Set from `bat` variable for now.

