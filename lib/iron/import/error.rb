class Importer
  
  class Error
    
    attr_reader :row, :column, :value, :text
    
    # Block wrapper to set error context for any errors generated within the block
    def self.with_context(importer, row, column, val)
      # Set new context
      old_row = @context_row
      @context_row = row
      old_col = @context_column
      @context_column = column
      old_val = @context_value
      @context_value = val
      old_err = @error_occurred
      @error_occurred = false
      
      # Run the block, catch raised exceptions as errors
      begin
        yield
      rescue RuntimeError => e
        # Old-style way of registering errors was to just raise 'foo'
        importer.add_error(e.to_s)
      end
      had_error = @error_occurred
      
      # Reset to old context
      @context_row = old_row
      @context_column = old_col
      @context_value = old_val
      @error_occurred = old_err
      
      return had_error
    end
    
    def self.context_row
      @context_row
    end
    
    def self.context_column
      @context_column
    end
    
    def self.context_value
      @context_value
    end
    
    def self.error_occurred!
      @error_occurred = true
    end
    
    def initialize(text, context = {})
      @text = text.to_s
      @row = context[:row] || Error.context_row
      @column = context[:column] || Error.context_column
      @value = context[:value] || Error.context_value
      
      @row.errors << self if @row
      @column.errors << self if @column
      
      Error.error_occurred!
    end
    
    def summary
      summary = ''
      if @row
        summary += "#{@row}: "
      end
      summary + @text
    end

    def to_s
      summary
    end
    
    # Returns the level at which this error occurred, one of
    # :row, :importer
    def level
      return :row if @row
      return :importer
    end
    
    def row_level?
      level == :row
    end
    
    def importer_level?
      level == :importer
    end

    # Returns true if this error is for the given context, where
    # context can be a Row or Importer instance.
    def for_context?(context)
      case context
      when Row
        return @row == context
      else
        return true
      end  
    end
    
  end
  
end