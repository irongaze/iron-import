class Importer
  
  class Error
     
    attr_reader :row, :text
    
    def initialize(context, text)
      if context.is_a?(Importer::Row)
        @row = context
      end
      @text = text.to_s
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
    # context can be a Row, Sheet or Importer instance.
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