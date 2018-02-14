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

      # Look at first line, count sep chars, pick the most common
      sep_char = ','
      line = text.split(/\n/, 2).first
      if line.count("\t") > line.count(',')
        sep_char = "\t"
      end

      # Parse it out
      encoding = @importer.encoding || 'UTF-8'
      options = {
        :encoding => "#{encoding}:UTF-8",
        :skip_blanks => true,
        :col_sep => sep_char
      }
      begin
        @raw_rows = CSV.parse(text, options)
      rescue Exception => e
        @importer.add_error('Error encountered while parsing CSV')
        @importer.add_exception(e)
        return false
      end

      if @raw_rows.nil? || @raw_rows.count == 0
        @importer.add_error('No rows found - unable to process CSV file')
        return false
      else
        return true
      end
    end
   
    def load_raw(scopes, &block)
      # Normally, we'd check the scopes and return the proper data, but for CSV files, 
      # there's only one scope...
      block.call(@raw_rows)
    end
    
  end
  
end