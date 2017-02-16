class Importer
  
  # Uses the Roo gem to read in .xlsx files
  class XlsxReader < ExcelReader
    
    def initialize(importer)
      super(importer, :xlsx)
    end
 
  end
  
end