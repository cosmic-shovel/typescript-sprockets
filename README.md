# TypeScript-Sprockets

Extends Sprockets to work with TypeScript (this library is a fork of [typescript-rails](typescript-ruby/typeScript-rails)) without Rails. This should make it possible to use TypeScript with [middleman-sprockets](https://github.com/middleman/middleman-sprockets) and/or [blade](https://github.com/javan/blade). The library has experimental support for compiling TSX files (see TypeScript's support for JSX (note that the compiler flag `--jsx react` is currently not supported currently); please let me know if you using this library's JSX
support as it will significantly increase the likelihood of this feature being improved/supported instead of being potentially removed in the future).

This gem assumes you are installing TypeScript locally with npm (although you can alter the `compiler_command` in the library options).

Please read the source code if you are planning on using this library (mainly `lib/typescript/sprockets/typescript_processor.rb`) as
it is very short and contribute by creating issues for any problems that you encounter and by making pull requests for documentation
and/or bug fixes.

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

Configurations (only needed to override defaults (which are all listed below)):

```
::Typescript::Sprockets::TypescriptProcessor.options(
    compiler_command: 'node node_modules/typescript/bin/tsc',
    compiler_flags: ['--forceConsistentCasingInFileNames',
                     '--noEmitOnError',
                     '--noFallthroughCasesInSwitch',
                     '--noImplicitAny',
                     '--noImplicitReturns',
                     '--noImplicitThis',
                     '--noUnusedParameters',
                     '--noUnusedLocals',
                     '--strictNullChecks'
                    ],
    jsx_compiler_flags: ['--forceConsistentCasingInFileNames',
                         '--noEmitOnError',
                         '--noFallthroughCasesInSwitch',
                         '--noImplicitAny',
                         '--noImplicitReturns',
                         '--noImplicitThis',
                         '--noUnusedParameters',
                         '--noUnusedLocals',
                         '--strictNullChecks',
                         '--jsx preserve'
                        ],
    compilation_system_command_generator: ->(options, outdir, outfile_location, source_file_path, support_jsx) { # @@options is passed in as an argument
      outfile_option = (options[:use_typescript_outfile_option] ? "--outFile #{outfile_location}" : '')
      cmd = <<CMD
#{options[:compiler_command]} #{(support_jsx ? options[:jsx_compiler_flags] : options[:compiler_flags]).join ' '} --outDir #{outdir} #{outfile_option} #{source_file_path}
CMD
      puts "Running compiler command: #{cmd}" if options[:logging]
      cmd
    },
    extensions: ['.js.ts', '.ts'],
    jsx_extensions: ['.js.tsx', '.tsx'],
    search_sprockets_load_paths_for_references: true,
    logging: true,
    use_typescript_outfile_option: false
)
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
