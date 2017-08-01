class Importer
  
  # Special data reader that allows you to define a block to do the import yourself for cases
  # where you have an odd text-based format or something else you want to be able to process
  # using this gem.  Check out Importer#on_file and Importer#on_stream to see how to use
  # this reader type.
  class CustomReader < DataReader
    
    attr_accessor :readers
    
    def initialize(importer)
      super(importer, :custom)
      @readers = {}
    end

    # Called by the importer to add a handler for the given mode
    def set_reader(mode, block)
      @readers[mode] = block
      @supports << mode
    end
    
    def init_source(mode, source)
      @mode = mode
      @source = source
    end
    
    def load_raw(scopes, &block)
      # Default to just running one scope passing nil
      if scopes.nil? || scopes.empty?
        scopes = [nil]
      end
      
      # Get the proper reader
      reader = @readers[@mode]
      scopes.each do |scope|
        rows = DslProxy.exec(self, @source, scope, &reader)
        if rows.is_a?(Array) && !@importer.has_errors?
          found = block.call(rows)
          break if found
        end
      end
      
    rescue Exception => e
      # Catch any exceptions thrown and note them with helpful stacktrace info for debugging custom readers
      add_exception(e)
    end
    
  end
  
end