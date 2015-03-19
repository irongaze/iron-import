class Importer
  
  class XlsReader < DataReader
    
    def initialize(importer)
      super(importer, :xlsx)
    end
    
    def load_file(path)
      spreadsheet = Roo::Excel.new(path, :file_warning => :ignore)
      if spreadsheet
        # Get our list of sheet definitions, and run all the sheets in the spreadsheet
        remaining_sheets = @importer.sheets.values
        spreadsheet.sheets.each_with_index do |name, index|
          # Look for a sheet definition that matches this sheet's name/index
          sheet = remaining_sheets.detect {|s| s.match_sheet?(name, index) }
          if sheet
            # Remove from our list of remaining sheets
            remaining_sheets.delete(sheet)
            # Extract our raw data
            raw_rows = []
            spreadsheet.sheet(name).each_with_index do |row, line|
              raw_rows << row
            end
            # Let the sheet sort it out
            sheet.parse_raw_data(raw_rows)
          end
        end
        return true
      else
        @importer.add_error("Unable to read Excel file at path #{path}")
        return false
      end
      
    rescue Exception => e
      @importer.add_error("Error reading file #{path}: #{e}")
      false
    end
    
    private
    
    def load_raw_rows(sheet, raw_rows)
      # Figure out where our columns are and where our data starts
      column_map = sheet.find_header(raw_rows[0...5])
      start_row = sheet.data.start_row
      
      # Run all the raw rows and convert them to Row instances, making notes of errors along the way...
      if !@importer.has_errors?
        raw_rows.each_with_index do |raw, index|
          line = index + 1
          if line >= start_row
            row = sheet.add_row(line, raw)
          end
        end
      end
    end
    
  end
  
end