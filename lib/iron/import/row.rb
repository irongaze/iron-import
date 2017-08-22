class Importer
  
  class Row

    # Attributes
    attr_reader :line, :values, :errors
    
    # Limit our inspect to avoid dumping whole importer
    inspect_only :line, :values
    
    def initialize(importer, line, value_hash = nil)
      @importer = importer
      @line = line
      set_values(value_hash)
      
      @errors = []
    end
    
    def set_values(value_hash)
      @values = value_hash
    end
    
    # True when all columns have a non-nil value, useful in filtering out junk 
    # rows.  Pass in one or more keys to check only those keys for presence.
    def all?(*keys)
      keys.flatten!
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
    
    # True when all row columns have nil values.
    def empty?
      @values.values.all?(&:nil?)
    end
    
    # Returns the value of a column.
    def [](column_key)
      @values[column_key]
    end

    # The row's name, e.g. 'Row 4'
    def to_s
      "Row #{@line}"
    end
    
    # This row's values as a hash of :column_key => <parsed + validated value>
    def to_h
      @values.dup
    end
    def to_hash ; to_h ; end
    
    def add_error(msg)
      @importer.add_error(msg, :row => self)
    end
    
    def has_errors?
      @errors && @errors.count > 0
    end
    
    # Return a map of column key to Error, intended for use in error reporting.
    def error_map
      map = {}
      @errors.each do |err|
        map[err.column.key] = err
      end
      map
    end
    
  end
  
end