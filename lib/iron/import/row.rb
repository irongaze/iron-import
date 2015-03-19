class Importer
  
  class Row

    attr_reader :sheet, :line, :values
    
    def initialize(sheet, line, value_hash = nil)
      @sheet = sheet
      @line = line
      @values = value_hash
    end
    
    def set_values(value_hash)
      @values = value_hash
    end
    
    # True when all columns have a non-nil value, useful in filtering out junk 
    # rows
    def all?(*keys)
      if keys.any?
        # Check only the specified keys
        valid = true
        keys.each do |key|
          unless @values.has_key?(key)
            raise "Unknown column key :#{key} in call to Row#all?"
          end
          valid = valid && !@values[key].nil?
        end
        valid
      else
        # Check all value keys
        @values.values.all? {|v| !v.nil? }
      end
    end
    
    def empty?
      @values.values.all?(&:nil?)
    end
    
    # Returns the value of a column
    def [](column_key)
      @values[column_key]
    end
    
    def to_s
      "Row #{@line}"
    end
    
    def add_error(msg)
      @sheet.importer.add_error(self, msg)
    end
    
    def add_warning(msg)
      @sheet.importer.add_warning(self, msg)
    end
    
  end
  
end