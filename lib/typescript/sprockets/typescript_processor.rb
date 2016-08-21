
# Standard Library References
require 'open3'
require 'tmpdir'

module Typescript
  module Sprockets
    class TypescriptProcessor
      @@options = {
        compiler_flags: ['--removeComments', '--noImplicitAny', '--noEmitOnError'],
        compiler_command: 'node node_modules/typescript/bin/tsc'
      }

      class << self
        def options(options = {})
          @@options = @@options.merge(options)
        end

        def register
          if ::Sprockets.respond_to? :register_transformer
            ::Sprockets.register_transformer 'text/typescript', 'application/javascript', ::Typescript::Sprockets::TypescriptProcessor
          end

          if ::Sprockets.respond_to? :register_mime_type
            ::Sprockets.register_mime_type 'text/typescript', extensions: ['.js.ts']
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

        # Get all references
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

        # @param [String] ts_path
        # @param [String] source TypeScript source code
        # @param [Sprockets::Context] sprockets context object
        # @return [String] compiled JavaScript source code
        def compile(ts_path, source, context=nil, input)
          if context
            get_all_reference_paths(File.expand_path(ts_path), source) do |abs_path|
              context.depend_on abs_path
            end
          end

          Dir.mktmpdir do |tmpdir|
            tmpfile = "#{tmpdir}/out"
            tmpfile2 = "#{tmpdir}/in.ts"
            s = replace_relative_references(ts_path, source)
            File.write(tmpfile2, s)
            stdout_str, stderr_str, status = Open3.capture3 "#{@@options[:compiler_command]} #{@@options[:compiler_flags].join ' '} --outFile #{tmpfile} #{tmpfile2}"

            if status.success?
              return { data: File.read(tmpfile) }
            else
              fail "TypeScript error in '#{input[:filename]}': #{stderr_str}\n\n#{stdout_str}"
            end
          end
        end

        def call(input)
          source  = input[:data]
          ts_path = input[:filename]
          context = input[:environment].context_class.new(input)

          compile(ts_path, source, context, input)
        end
      end
    end
  end
end
