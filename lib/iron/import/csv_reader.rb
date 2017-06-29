require 'csv'

class Importer
  
  class CsvReader < DataReader
   
    def initialize(importer)
      super(importer, :csv)
      supports_file!
      supports_stream!
    end
    
    def init_source(mode, source)
      if mode == :stream
        # For streams, we just read 'em in and parse 'em
        text = source.read
        encoding = @importer.encoding || 'UTF-8'
        @raw_rows = CSV.parse(text, :encoding => "#{encoding}:UTF-8")
        true
        
      elsif mode == :file
        # Files have a different path
        encoding = @importer.encoding || 'UTF-8'
        @raw_rows = CSV.read(source, :encoding => "#{encoding}:UTF-8")
        true
        
      else
        @importer.add_error("Unsupported CSV mode: #{mode}")
        false
      end
    end
   
    def load_raw(scopes, &block)
      # Normally, we'd check the scopes and return the proper data, but for CSV files, 
      # there's only one scope...
      block.call(@raw_rows)
    end
    
  end
  
end