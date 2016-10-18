
# Standard Library References
require 'find'
require 'open3'
require 'pathname'
require 'securerandom'
require 'tmpdir'
require 'uri'

module Typescript
  module Sprockets
    # Intended to support Sprockets 2, 3 and 4 (only tested against Sprockets 3.7+ interface during initial development)
    class TypescriptProcessor
      @@options = {
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
        compilation_system_command_generator: ->(options, outdir, source_file_path, support_jsx) { # @@options is passed in as an argument
          "#{options[:compiler_command]} #{(support_jsx ? options[:jsx_compiler_flags] : options[:compiler_flags]).join ' '} --outDir #{outdir} #{source_file_path}"
        },
        extensions: ['.js.ts', '.ts'],
        jsx_extensions: ['.js.tsx', '.tsx'],
        search_sprockets_load_paths_for_references: true,
        logging: true
      }

      # Taken from: https://github.com/rails/sprockets/blob/master/guides/extending_sprockets.md#supporting-all-versions-of-sprockets-in-processors
      # The library also uses the MIT license.
      def initialize(filename, &block)
        @filename = filename
        @source   = block.call
      end

      # Taken from: https://github.com/rails/sprockets/blob/master/guides/extending_sprockets.md#supporting-all-versions-of-sprockets-in-processors
      # The library also uses the MIT license.
      def render(context, empty_hash_wtf)
        self.class.run(@filename, @source, context)
      end

      class << self
        def options(options = {})
          @@options = @@options.merge(options)
        end

        def register
          if ::Sprockets.respond_to? :register_transformer

            # Typescript/TSX -> JavaScript/JSX
            ::Sprockets.register_transformer 'text/typescript', 'application/javascript', ::Typescript::Sprockets::TypescriptProcessor
            ::Sprockets.register_transformer 'text/tsx', 'application/jsx', ::Typescript::Sprockets::TypescriptProcessor

            # ERB -> TypeScript/TSX
            ::Sprockets.register_transformer 'application/typescript+ruby', 'text/typescript', ::Sprockets::ERBProcessor
            ::Sprockets.register_transformer 'application/tsx+ruby', 'text/tsx', ::Sprockets::ERBProcessor
          end

          if ::Sprockets.respond_to? :register_mime_type
            ::Sprockets.register_mime_type 'text/typescript', extensions: @@options[:extensions]
            ::Sprockets.register_mime_type 'text/tsx', extensions: @@options[:jsx_extensions]

            ::Sprockets.register_mime_type 'application/typescript+ruby', extensions: @@options[:extensions].map { |ext| "#{ext}.erb" }
            ::Sprockets.register_mime_type 'application/tsx+ruby', extensions: @@options[:jsx_extensions].map { |ext| "#{ext}.erb" }
          end
        end

        # Replace relative paths specified in /// <reference path="..." /> with absolute paths.
        #
        # @param [String] ts_path Source .ts path
        # @param [String] source. It might be pre-processed by erb.
        # @return [String] replaces source
        def replace_relative_references(ts_path, source)
          ts_dir = File.dirname(File.expand_path(ts_path))
          escaped_dir = ts_dir.gsub(/["\\]/, '\\\\\&') # "\"" => "\\\"", '\\' => '\\\\'

          # Why don't we just use gsub? Because it display odd behavior with File.join on Ruby 2.0
          # So we go the long way around.
          (source.each_line.map do |l|
             if l.start_with?('///') && !(m = %r!^///\s*<reference\s+path=(?:"([^"]+)"|'([^']+)')\s*/>\s*!.match(l)).nil?
               matched_path = m.captures.compact[0]
               l = l.sub(matched_path, File.join(escaped_dir, matched_path))
             end
             next l
           end).join
        end

        # Replace relative paths specified in /// <reference path="..." /> with absolute paths (reference
        # lookup goes through Sprocket load paths unless the reference begins with a dot (.)).
        #
        # @param [String] ts_path Source .ts path
        # @param [String] source. It might be pre-processed by erb.
        # @return [String] replaces source
        def replace_relative_references2(ts_path, source, context)
          ts_dir = File.dirname(File.expand_path(ts_path))
          escaped_dir = ts_dir.gsub(/["\\]/, '\\\\\&') # "\"" => "\\\"", '\\' => '\\\\'

          # Why don't we just use gsub? Because it display odd behavior with File.join on Ruby 2.0
          # So we go the long way around.
          (source.each_line.map do |l|
             if l.start_with?('///') && !(m = %r!^///\s*<reference\s+path=(?:"([^"]+)"|'([^']+)')\s*/>\s*!.match(l)).nil?
               matched_path = m.captures.compact[0]
               if matched_path.start_with? '.'
                 abs_path = File.join(escaped_dir, matched_path)
               else
                 abs_path = File.expand_path(URI.parse(context.resolve(matched_path)).path)
               end

               l = l.sub(matched_path, abs_path)
             end
             next l
           end).join
        end

        # Get all references.
        #
        # @param [String] path Source .ts path
        # @param [String] source. It might be pre-processed by erb.
        # @yieldreturn [String] matched ref abs_path
        def get_all_reference_paths(path, source, visited_paths=Set.new, &block)
          visited_paths << path
          source ||= File.read(path)
          source.each_line do |l|
            if l.start_with?('///') && !(m = %r!^///\s*<reference\s+path=(?:"([^"]+)"|'([^']+)')\s*/>\s*!.match(l)).nil?
              matched_path = m.captures.compact[0]
              abs_matched_path = File.expand_path(matched_path, File.dirname(path))
              unless visited_paths.include? abs_matched_path
                block.call abs_matched_path
                get_all_reference_paths(abs_matched_path, nil, visited_paths, &block)
              end
            end
          end
        end

        # Get all references (reference lookup goes through Sprocket load paths unless the reference begins with a dot (.)).
        #
        # @param [String] path Source .ts path
        # @param [String] source. It might be pre-processed by erb.
        # @yieldreturn [String] matched ref abs_path
        def get_all_reference_paths2(path, source, context, visited_paths=Set.new, &block)
          visited_paths << path
          source ||= File.read(path)
          source.each_line do |l|
            if l.start_with?('///') && !(m = %r!^///\s*<reference\s+path=(?:"([^"]+)"|'([^']+)')\s*/>\s*!.match(l)).nil?
              matched_path = m.captures.compact[0]
              if matched_path.start_with? '.'
                abs_matched_path = File.expand_path(matched_path, File.dirname(path))
                puts "Working with relative file reference (#{matched_path}) which resolves to: #{abs_matched_path}" if @@options[:logging]
              else
                abs_matched_path = File.expand_path(URI.parse(context.resolve(matched_path)).path)
                puts "Working with absolute file reference (#{matched_path}) which resolves to: #{abs_matched_path}" if @@options[:logging]
              end

              unless visited_paths.include? abs_matched_path
                block.call abs_matched_path
                get_all_reference_paths2(abs_matched_path, nil, context, visited_paths, &block)
              end
            end
          end
        end

        # @param [String] ts_path (filename)
        # @param [String] source TypeScript source code
        # @param [Sprockets::Context] sprockets context object
        # @return [String] compiled JavaScript source code
        def run(ts_path, source, context=nil)
          puts "TypeScript Sprockets is compiling: #{ts_path}" if @@options[:logging]
          if context
            if @@options[:search_sprockets_load_paths_for_references]
              get_all_reference_paths2(File.expand_path(ts_path), source, context) do |abs_path|
                context.depend_on abs_path
              end
            else
              get_all_reference_paths(File.expand_path(ts_path), source) do |abs_path|
                context.depend_on abs_path
              end
            end
          end

          support_jsx = ts_path.end_with?('tsx')
          Dir.mktmpdir do |tmpdir|
            # Writing to a tempfile within directory of TypeScript file so that TypeScript import statements work for local files.
            # Support for Sprockets lookup paths for TypeScript import statements (e.g. `import * as Package from "packages"`) is not currently supported/planned.
            filename_without_ext_or_dir = "#{SecureRandom.hex(16)}.typescript-sprockets"
            tmpfile2 = File.join("#{Pathname.new(ts_path).parent}", "#{filename_without_ext_or_dir}.ts#{'x' if support_jsx}")
            tmpfile2_out = File.join(tmpdir, "#{filename_without_ext_or_dir}.js#{'x' if support_jsx}")

            s = ''
            if @@options[:search_sprockets_load_paths_for_references] && context
              s = replace_relative_references2(ts_path, source, context)
            else
              s = replace_relative_references(ts_path, source)
            end

            begin
              File.write(tmpfile2, s)
              cmd = @@options[:compilation_system_command_generator].call(@@options, tmpdir, tmpfile2, support_jsx)
              stdout_str, stderr_str, status = Open3.capture3 cmd

              if status.success?
                searched_paths = [] # Only for debugging errors.
                Find.find(tmpdir) do |path|
                  pn = Pathname.new(path)
                  searched_paths.push path # Only for debugging errors.
                  searched_paths.push pn.inspect # Only for debugging errors.
                  if pn.file? && (pn.realpath.basename.to_s == "#{filename_without_ext_or_dir}.js#{'x' if support_jsx}")
                    return File.read(pn)
                  end
                end

                fail <<ERROR_MESSAGE
typescript-sprockets ERROR: Could not find compiled file, how embarassing...

Was compiling the file #{ts_path}.
This was the command executed on command line: #{cmd}
Failed reading the output file (which was: #{tmpfile2_out}) from the command.

Searched paths: #{searched_paths.inspect}
ERROR_MESSAGE
              else
                fail "TypeScript error in '#{ts_path}': #{stderr_str}\n\n#{stdout_str}"
              end
            ensure
              File.delete(tmpfile2) if File.exist?(tmpfile2)
              File.delete(tmpfile2_out) if File.exist?(tmpfile2_out)
            end
          end
        end

        def call(input)
          source  = input[:data]
          ts_path = input[:filename]
          context = input[:environment].context_class.new(input)

          result = run(ts_path, source, context)
          context.metadata.merge(data: result)
        end
      end
    end
  end
end
