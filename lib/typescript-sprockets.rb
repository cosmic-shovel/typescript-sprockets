require 'typescript/sprockets'
require 'typescript/sprockets/typescript_processor'
require 'typescript/sprockets/version'

::Sprockets.register_mime_type 'text/typescript', extensions: ['.js.ts']
::Sprockets.register_transformer 'text/typescript', 'application/javascript', TypescriptProcessor
