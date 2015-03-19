class Importer
  
  class Error
     
    attr_reader :sheet, :row, :text
    
    def initialize(context, text)
      if context.is_a?(Importer::Sheet)
        @sheet = context
      elsif context.is_a?(Importer::Row)
        @row = context
        @sheet = context.sheet
      end
      @text = text.to_s
    end
    
    def summary
      summary = ''
      if @row
        summary += "#{@sheet} #{@row}: "
      elsif @sheet
        summary += "#{@sheet}: "
      end
      summary + @text
    end

    def to_s
      summary
    end
    
    # Returns the level at which this error occurred, one of
    # :row, :sheet, :importer
    def level
      return :row if @row
      return :sheet if @sheet
      return :importer
    end
    
    def row_level?
      level == :row
    end
    
    def sheet_level?
      level == :sheet
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
      when Sheet
        return @sheet == context
      else
        return true
      end  
    end
    
  end
  
end