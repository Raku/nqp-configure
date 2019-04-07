# NQP::Config Macro Expansion

NQP::Config expands template files using a pretty simple macro expansion. A
macro is:

* enclosed in symbols `@` or `@@`
* has a name which a combination of word chars (`\w` in regexp terms) and colons
  `:` 
* can be either a configuration variable or a macro function

In this document we will call macro functions just _macro_s in this document.

For macros and variables defined with `@@` all spaces in their resulting value
will be quoted with backslash char (`\`).

## Configuration Variables

A configuration variable is set either from CLI options, or as a result of
detection process performed by the `Configure.pl` script, or any other source of
information.

For example, `@libdir@` could either be set with `--libdir` option of
`Configure.pl`, or set to a default value using a value from `@prefix@`
variable.

A number of variables are fetched from `NQP` and `MoarVM`. Those will have
`nqp::` and `moar::` prefixes respectively.

## Macro Functions

A common format for a macro is:

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
```

`nfp` stands for _normalize file path_. It converts a Unix-style path into
a format suitable for the OS we build on. The problem is that we know that
`@prefix@` is already normalized. Lets assume that `@custom_macro()@` does so
too, and `@file@`... Generally saying, the result of normalization migh be not
what we would expect from it if it performed on pre-normalized path names.

One solutions would to use `@slash@` instead of `/`. Ugly and possibly
unreliable. Wrapping each `/` with `nfp`?? Well, no!..

```
@expand(@!nfp(@prefix@/@custom_macro()@/@file@)@)@
```

This is considered to be the most reliable solution.

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

### include(template)

_Pre-expanded_

Finds a template file, expands it and returns the result.
