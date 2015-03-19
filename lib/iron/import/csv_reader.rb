require 'csv'

class Importer
  
  class CsvReader < DataReader
   
    def initialize(importer)
      super(importer, :csv)
    end
   
    def load_stream(stream)
      text = stream.read
      encoding = @importer.encoding || 'UTF-8'
      raw_rows = CSV.parse(text, :encoding => "#{encoding}:UTF-8")
      @importer.default_sheet.parse_raw_data(raw_rows)
    end
    
    def load_file(path)
      encoding = @importer.encoding || 'UTF-8'
      raw_rows = CSV.read(path, :encoding => "#{encoding}:UTF-8")
      @importer.default_sheet.parse_raw_data(raw_rows)
    end
    
  end
  
end