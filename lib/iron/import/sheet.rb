class Importer
  
  # The Sheet class handles building the sheet's column configuration and other
  # setup, then holds all load-time row data.  In some file types (Excel mostly)
  # there may be more than one sheet definition in a given importer.  In others,
  # the default sheet is the only one (possibly implicitly) defined.
  #
  # The following builder options are available:
  # 
  #   Importer.build do
  #     sheet('Some Sheet Name') do
  #       # Don't try to look for a header using column definitions, there is no header
  #       headerless!
  #
  #       # Manually set the start row for data in this sheet, defaults to nil
  #       # indicating that the data rows start immediatly following the header.
  #       start_row 4
  #
  #       # Define a filter that will skip unneeded rows.  The filter command takes
  #       # a block that receives the parsed (but not validated!) row data as an 
  #       # associative hash of :col_key => <parsed value>, and returns 
  #       # true to keep the row or false to exclude it.
  #       filter do |row|
  #         row[:id].to_i > 5000
  #       end
  #
  #       # Of course, the main thing to do in a sheet is define columns.  See the
  #       # Column class' notes for options when defining a column.  Note that
  #       # you can define columns using either hash-style:
  #       column :id, :type => :integer
  #       # or builder-style:
  #       column :name do
  #         header /company\s*name/
  #         type :string
  #       end
  #    end
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

    # Define our columns etc. via builder-style method calling
    def build(&block)
      DslProxy.exec(self, &block)
    end
    
    # Call with a block accepting a single Importer::Row with contents that
    # look like :column_key => <parsed value>.  Any filtered rows
    # will not be present.  If you want to register an error, simply 
    # raise "some text" and it will be added to the importer's error
    # list for display to the user, logging, or whatever.
    def process
      @data.rows.each do |row|
        begin
          yield row
        rescue Exception => e
          @importer.add_error(row, e.to_s)
        end
      end
    end
    
    # Add a new column definition to our list, allows customizing the new
    # column with a builder block.  See Importer::Column docs for 
    # options.  In lieu of a builder mode, you can pass the same values
    # as key => value pairs in the options hash to this method, so:
    #
    #   column(:foo) do
    #     type :string
    #     parse do |val|
    #       val.to_s.upcase
    #     end
    #   end
    # 
    # Is equivalent to:
    #
    #   column(:foo, :type => :string, :parse => lambda {|val| val.to_s.upcase})
    #
    # Use whichever you prefer!
    def column(key, options_hash = {}, &block)
      # Find existing column with key to allow re-opening an existing definition
      col = @columns.detect {|c| c.key == key }
      unless col
        # if none found, add a new one
        col = Column.new(self, key, options_hash)
        @columns << col
      end
      
      # Customize if needed
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
          row_num = index + 1
          if row_num >= @data.start_row
            add_row(row_num, raw)
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
          unless col.position.nil?
            next_index = col.fixed_index
          end
          col.data.index = next_index
          next_index += 1
        end
        @data.start_row = @start_row || 1
        return true
        
      else
        # Match by testing
        raw_rows.each_with_index do |row, i|
          # Um, have data?
          next unless row
          
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
    
    # When true, the given sheet name or zero-based index
    # is a match with our id.
    def match_sheet?(name, index)
      if @id.is_a?(Fixnum)
        @id.to_i == index+1
      else
        @id.to_s.downcase == name.downcase
      end
    end

    def to_s
      "Sheet #{@id}"
    end
    
    # Return all parsed, filtered data in the sheet as an
    # array of arrays.
    def dump
      @data.rows.collect(&:values)
    end

  end
  
end
