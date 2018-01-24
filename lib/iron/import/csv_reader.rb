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
        
      elsif mode == :file
        # Files have a different path
        text = File.read(source)
        
      else
        # WTF?
        @importer.add_error("Unsupported CSV mode: #{mode.inspect}")
        return false
      end

      # Fix shitty Windows line-feeds so things are standardized
      text.gsub!(/\r\n/, "\n")
      text.gsub!(/\r/, "\n")

      # Parse it out
      encoding = @importer.encoding || 'UTF-8'
      options = {
        :encoding => "#{encoding}:UTF-8",
        :skip_blanks => true
      }
      begin
        @raw_rows = CSV.parse(text, options)
      rescue Exception => e
        @importer.add_error('Error encountered while parsing CSV')
        @importer.add_exception(e)
      end
    end
   
    def load_raw(scopes, &block)
      # Normally, we'd check the scopes and return the proper data, but for CSV files, 
      # there's only one scope...
      block.call(@raw_rows)
    end
    
  end
  
end