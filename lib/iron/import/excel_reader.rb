class Importer
  
  # Uses the Roo gem to read in .xls files
  class ExcelReader < DataReader
    
    def initialize(importer, format)
      super(importer, format)
      supports_file!
    end
    
    def init_source(mode, source)
      if mode == :file
        if @format == :xls
          @spreadsheet = Roo::Excel.new(source, :file_warning => :ignore)
          true
        elsif @format == :xlsx
          @spreadsheet = Roo::Excelx.new(source, :file_warning => :ignore)
          true
        else
          add_error("Unknown format for Excel file: :#{@format}")
          false
        end
      else
        add_error("Unsupported #{@format.to_s.upcase} mode: #{mode}")
        false
      end
    rescue Exception => e
      add_error("Error reading file #{source}: #{e}")
      false
    end
    
    def load_raw(scopes, &block)
      @spreadsheet.sheets.each_with_index do |name, index|
        # See if this sheet's name or index matches the requested sheet definition
        if include_sheet?(scopes, name, index)
          # Extract our raw data
          raw_rows = []
          @spreadsheet.sheet(name).each_with_index do |row, line|
            raw_rows << row
          end
          # Yield our raw rows for this sheet
          found = block.call(raw_rows)
          # If we've found a working sheet, stop
          return if found
        end
      end

    rescue Exception => e
      # Not sure why we'd get here, but we strive for error-freedom here, yessir.
      @importer.add_error("Error loading Excel data: #{e}")
    end
  
    # When true, the given sheet name or zero-based index
    # is a match with our id.
    def include_sheet?(scopes, name, index)
      return true if scopes.nil? || scopes.empty?
      scopes.each do |scope|
        if scope.is_a?(Fixnum)
          return true if scope.to_i == index+1
        else
          return true if scope.to_s.downcase == name.downcase
        end
      end
      false
    end

  end
  
end