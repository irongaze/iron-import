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
    
    def load_raw_sheet(sheet)
      reader = @readers[@mode]
      res = DslProxy.exec(self, @source, sheet, &reader)
      if !res.is_a?(Array) || @importer.has_errors?
        false
      else
        res
      end
      
    rescue Exception => e
      # Catch any exceptions thrown and note them with helpful stacktrace info for debugging custom readers
      @importer.add_error("Error in custom reader when loading #{sheet}: #{e} @ #{e.backtrace.first}")
      false
    end
    
  end
  
end