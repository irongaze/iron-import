class Importer
  
  # The Sheet class handles building the sheet's column configuration and other
  # setup, then holds all load-time row data.
  class Sheet
    
    # Inner class for holding load-time data that gets reset on each load call
    class Data
      attr_accessor :start_row, :rows
      def initialize
        @start_row = nil
        @rows = []
      end
    end
    
    # Key data
    attr_reader :importer
    attr_reader :columns
    attr_reader :data

    # Settings
    dsl_flag :headerless
    dsl_accessor :id
    dsl_accessor :start_row
    dsl_accessor :filter
    
    def initialize(importer, id)
      @importer = importer
      @id = id

      @headerless = false
      @start_row = nil
      @filter = nil
      
      @columns = []
      
      reset
    end

    def build(&block)
      DslProxy.exec(self, &block)
    end
    
    def process
      @data.rows.each do |row|
        begin
          yield row
        rescue Exception => e
          @importer.add_error(row, e.to_s)
        end
      end
    end
    
    def column(key, &block)
      col = @columns.detect {|c| c.key == key }
      unless col
        col = Column.new(self, key)
        @columns << col
      end
      
      DslProxy::exec(col, &block) if block
      
      col
    end
    
    # Reset for load attempt
    def reset
      @data = Data.new
    end
    
    def parse_raw_data(raw_rows)
      # Find our column layout, start of data, etc
      if parse_header(raw_rows)
        # Now, run all the data and add it as a Row instance
        raw_rows.each_with_index do |raw, index|
          line = index + 1
          if line >= @data.start_row
            add_row(line, raw)
          end
        end
      end
    end
    
    # Add a new row to our stash
    def add_row(line, raw_data)
      # Add the row
      row = Row.new(self, line)
      
      # Parse out the values
      values = {}
      @columns.each do |col|
        index = col.data.index
        raw_val = raw_data[index]
        if col.parse
          val = col.parse_value(row, raw_val)
        else
          val = @importer.data.parse_value(raw_val, col.type)
        end
        values[col.key] = val
      end

      # Set the values and filter if needed
      row.set_values(values)
      return nil unless !@filter || @filter.call(row)
      
      # Row is solid, now check for missing required vals
      @columns.each do |col|
        val = values[col.key]
        if col.validate_value(row, val)
          if col.required?
            if values[col.key].nil?
              @importer.add_error(row, "Missing required value for #{col}")
            end
          end
        end
      end
      
      # We is good
      @data.rows << row
      row
    end
    
    # Process the raw values for the first rows in a sheet,
    # and attempt to build a map of the column layout, and
    # detect the first row of real data
    def parse_header(raw_rows)
      if headerless?
        # Use implicit or explicit column position when told to not look for a header
        next_index = 0
        @columns.each do |col|
          if col.index.present?
            next_index = col.index
          end
          col.data.index = next_index
          next_index += 1
        end
        @data.start_row = @start_row || 1
        return true
        
      else
        # Match by testing
        raw_rows.each_with_index do |row, i|
          # Set up for this iteration
          remaining = @columns.dup
      
          # Step through this row's raw values, and look for a matching column for all columns
          row.each_with_index do |val, i|
            col = remaining.detect {|c| c.match_header?(val.to_s, i) }
            if col
              remaining -= [col]
              col.data.index = i
            end
          end
          
          if remaining.empty?
            # Found the cols, have a map, update our start row to be the next line and return!
            @data.start_row = @start_row || i+2
            return true
          end
        end
        
        # If we get here, we're hosed
        @importer.add_error(self, "Unable to locate required column header(s) in sheet")
        false
      end
    end
    
    def match_sheet?(name, index)
      if @id.is_a?(Fixnum)
        @id.to_i == index+1
      else
        @id.to_s == name
      end
    end

    def to_s
      "Sheet #{@id}"
    end
    
    def dump
      @data.rows.collect(&:values)
    end

  end
  
end
