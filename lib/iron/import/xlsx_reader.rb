class Importer
  
  # Uses the Roo gem to read in .xlsx files
  class XlsxReader < DataReader
    
    def initialize(importer)
      super(importer, :xlsx)
      supports_file!
    end
    
    def init_source(mode, source)
      if mode == :file
        @spreadsheet = Roo::Excelx.new(source, :file_warning => :ignore)
        true
      else
        @importer.add_error("Unsupported XLSX mode: #{mode}")
        false
      end
    rescue Exception => e
      @importer.add_error("Error reading file #{source}: #{e}")
      false
    end
    
    def load_raw_sheet(sheet)
      @spreadsheet.sheets.each_with_index do |name, index|
        # See if this sheet's name or index matches the requested sheet definition
        if sheet.match_sheet?(name, index)
          # Extract our raw data
          raw_rows = []
          @spreadsheet.sheet(name).each_with_index do |row, line|
            raw_rows << row
          end
          return raw_rows
        end
      end
      @importer.add_error("Unable to find sheet #{sheet}")
      return false
      
    rescue Exception => e
      # Not sure why we'd get here, but we strive for error-freedom here, yessir.
      @importer.add_error("Error loading sheet #{sheet}: #{e}")
      false
    end
    
  end
  
end