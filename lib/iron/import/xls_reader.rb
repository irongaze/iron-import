class Importer
  
  # Uses the Roo gem to read in .xls files
  class XlsReader < ExcelReader
    
    def initialize(importer)
      super(importer, :xls)
    end
    
  end
  
end