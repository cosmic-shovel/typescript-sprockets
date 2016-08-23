# TypeScript-Sprockets

Please note that this is currently a *WORK-IN-PROGRESS*.

Extends Sprockets to work with TypeScript (fork of [typescript-rails](typescript-ruby/typeScript-rails)) without Rails. This should make it possible to use TypeScript with [middleman-sprockets](https://github.com/middleman/middleman-sprockets) and/or [blade](https://github.com/javan/blade).

This gem assumes you are installing TypeScript locally with npm.

The credit for the overall structure and the tests goes to the people that wrote the [typescript-rails](https://github.com/typescript-ruby/typescript-rails) Gem, since I shamelessly copy&pasted some of their code.

## Requirements

The current version requires that [node.js](http://nodejs.org/) is
installed on the system.

## Installation

Add this line to your application's Gemfile:

    gem 'typescript-sprockets', 'git: 'https://github.com/preetpalS/typescript-sprockets.git', tag: 'LATEST VERSION TAG', require: 'typescript-sprockets'

And then execute:

    $ bundle

## Usage

After the sprockets gem (and this gem) is loaded, add the following lines of code:

    require 'sprockets' # might not be necessary depending on when/where this line of code is executed
    require 'typescript-sprockets' # might not be necessary depending on when/where this line of code is executed
    ::Typescript::Sprockets::TypescriptProcessor.register

Then just add a `.js.ts` file in your `app/assets/javascripts` directory and include it just like you are used to do.

Configurations:

```
# Its defaults are `['--removeComments', '--noImplicitAny', '--noEmitOnError']`.
::Typescript::Sprockets::TypescriptProcessor.options(compiler_flags: ['--removeComments', '--noImplicitAny', '--noEmitOnError'], compiler_command: 'node node_modules/typescript/bin/tsc')
```

## Referenced TypeScript dependencies

`typescript-rails` recurses through all [TypeScript-style](https://github.com/teppeis/typescript-spec-md/blob/master/en/ch11.md#1111-source-files-dependencies) referenced files and tells its [`Sprockets::Context`](https://github.com/sstephenson/sprockets/blob/master/lib/sprockets/context.rb) that the TS file being processed [`depend`s`_on`](https://github.com/sstephenson/sprockets#the-depend_on-directive) each file listed as a reference. This activates Sprocket’s cache-invalidation behavior when any of the descendant references of the root TS file is changed.

Support for Sprockets lookup paths for TypeScript import statements (e.g. `import * as package from "packages"`) is not supported/planned (this might not be feasible to support because of ambient module declarations).
Therefore, Sprocket's cache invalidation will not work for TypeScript import statements. Note that this library creates temporary preprocessed (with all relative references in `/// <reference ... />` replaced with absolute file references) versions of your TypeScript
files within their parent directory so that TypeScript import statements will work for local references (ambient module declarations should also work).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Maintainers

Preetpal Sohal

## Authors

Preetpal Sohal <preetpal.sohal@gmail.com>

Authors of the original repository that this is repository is a fork of:

FUJI Goro <gfuji@cpan.org>
Klaus Zanders <klaus.zanders@gmail.com>
