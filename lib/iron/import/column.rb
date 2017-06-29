class Importer

  # Columns represent the settings for importing a given column within a Sheet.  They do not
  # hold data, rather they capture the settings needed for identifying the column in the header,
  # how to parse and validate each of their cell's data, and so forth.
  #
  # Here's the complete list of column configuration options:
  #
  #   Importer.build do
  #     column :key do
  #       # Mark this column as optional, i.e. if the header isn't found, the import will
  #       # work without error and the imported row will simply not contain this column's data.
  #       optional!
  #
  #       # Set a fixed position - may be a column number or a letter-based
  #       # column description, ie 'A' == 1.  In most cases, you can leave
  #       # this defaulted to nil, which will mean "look for the proper header"
  #       position 'C'
  #
  #       # Specify a regex to locate the header for this column, defaults to 
  #       # finding a string containing the key, ignored if position is set.
  #       header /(price|cost)/i
  #
  #       # Tells the data parser what type of data this column contains, one
  #       # of :integer, :string, :date, :float, or :cents.  Defaults to :string.
  #       type :cents
  #
  #       # Instead of a type, you can set an explicit parse block.  Be aware
  #       # that different source types may give you different raw values for what
  #       # seems like the "same" source value, for example an Excel source file
  #       # will give you a float value for all numeric types, even "integers", while
  #       # CSV and HTML values are always strings.
  #       parse do |raw_value|
  #         val = raw_value.to_i + 1000
  #         # NOTE: we're in a block, so don't do this:
  #         return val
  #         # Instead, use implied return:
  #         val
  #       end
  #      
  #       # You can also add a custom validator to check the value and add
  #       # an error if it's not within a given range, or whatever.  To fail validation,
  #       # return false, raise an exception, or use #add_error
  #       validate do |parsed_value, row|
  #         add_error "Out of range" unless (parsed_value > 0 && parsed_value < 5000)
  #       end
  #
  #       # Mark a column as _virtual_, meaning it won't be looked for in the source
  #       # file/stream, and instead will be calculated using #calculate.  When set,
  #       # causes importer to ignore position/header/type/parse settings.
  #       virtual!
  #
  #       # When #virtual! is set, gets called to calculate each row's value for this
  #       # column using the row's parsed values.
  #       calculate do |row|
  #         row[:some_col] + 5
  #       end
  #     end
  #   end
  #
  class Column

    # Holds load-time data
    class Data
      attr_accessor :index, :header_text, :errors
      
      def initialize
        @errors = []
      end
      
      def pos
        @index ? Column::index_to_pos(@index) : 'Not Found'
      end
    end

    # Core info
    attr_reader :key
    attr_reader :data

    # Configuration
    dsl_accessor :header, :position, :type
    dsl_accessor :parse, :validate, :calculate
    dsl_flag :optional, :virtual
   
    def self.pos_to_index(pos)
      raise 'Invalid column position: ' + pos.inspect unless pos.is_a?(String) && pos.match(/\A[a-z]{1,3}\z/i)
      vals = pos.upcase.bytes.collect {|b| b - 64}
      total = 0
      multiplier = 1
      vals.reverse.each do |val|
        total += val * multiplier
        multiplier *= 26
      end
      total - 1
    end
    
    # Convert a numeric index to an Excel-like column position, e.g. 3 => 'C'
    def self.index_to_pos(index)
      val = index.to_i
      raise 'Invalid column index: ' + index.inspect if (!index.is_a?(Fixnum) || index.to_i < 0)
      
      chars = ('A'..'Z').to_a
      str = ''
      while index > 25
        str = chars[index % 26] + str
        index /= 26
        index -= 1
      end
      str = chars[index] + str
      str
    end     

    # Create a new column definition with the key for the column,
    # and an optional set of options.  The options supported are the same as those supported
    # in block/builder mode.
    def initialize(importer, key, options_hash = {})
      # Save off our info
      @key = key
      @importer = importer

      # Are we optional?
      @optional = options_hash.delete(:optional) { false }
      
      # Are we virtual?
      @virtual = options_hash.delete(:virtual) { false }
      
      # Return it as a string, by default
      @type = options_hash.delete(:type) { :string }
      
      # Position can be explicitly set
      @position = options_hash.delete(:position)
      
      # By default, don't parse incoming data, just pass it through
      @parse = options_hash.delete(:parse)
      
      # Custom validation, anyone?
      @validate = options_hash.delete(:validate)
      
      # Custom validation, anyone?
      @calculate = options_hash.delete(:calculate)
      
      # Default matcher, looks for the presence of the column key as text anywhere
      # in the header string, ignoring case and treating underscores as spaces, ie
      # :order_id => /\A\s*order id\s*\z/i
      @header = options_hash.delete(:header) {
        Regexp.new('\A\s*' + key.to_s.gsub('_', ' ') + '\s*\z', Regexp::IGNORECASE)
      }
      
      # Reset our state to pre-load status
      reset
    end
    
    # Customize ourselves using block syntax
    def build(&block)
      DslProxy.exec(self, &block)
    end
    
    # Deletes all stored data in prep for an import run
    def reset
      @data = Data.new
    end

    # When true, our header definition or index match the passed text or column index.
    def match_header?(text, test_index)
      return false if virtual?
      return true if test_index == self.fixed_index
      if @header.is_a?(Regexp)
        return !@header.match(text).nil?
      else
        return @header.to_s.downcase == text
      end
    end
    
    # Returns the fixed index of this column based on the set position.
    # In other words, a position of 2 would return an index of 1 (as
    # indicies are 0-based), where a position of 'C' would return 2.
    def fixed_index
      return nil if virtual?
      return nil unless @position
      if @position.is_a?(Fixnum)
        @position - 1
      elsif @position.is_a?(String)
        Column.pos_to_index(@position)
      end
    end
    
    # Applies any custom parser defined to process the given value, capturing
    # errors as needed
    def parse_value(row, raw_val)
      return raw_val if @parse.nil?

      res = nil
      had_error = Error.with_context(@importer, row, self, raw_val) do
        res = DslProxy.exec(@importer, raw_val, &@parse)
      end
      had_error ? nil : res
    end
    
    def calculate_value(row)
      return nil if @calculate.nil?
      res = nil
      had_error = Error.with_context(@importer, row, self, nil) do
        res = DslProxy.exec(@importer, row, &@calculate)
      end
      had_error ? nil : res
    end
    
    # Applies any validation to a parsed value
    def validate_value(row, parsed_val)
      return true unless @validate

      valid = false
      had_error = Error.with_context(@importer, row, self, parsed_val) do
        valid = DslProxy.exec(@importer, parsed_val, row, &@validate)
      end
      if had_error
        return false
      elsif valid.is_a?(FalseClass)
        @importer.add_error("Invalid value: #{parsed_val.inspect}", :row => row, :column => self, :value => parsed_val)
        return false
      else
        return true
      end
    end
    
    # Index of the column in the most recent import, if found, or
    # nil if not present.
    def index
      @data.index
    end
    
    # When true, column was found in the last import, eg:
    #
    #   importer.process do |row|
    #     puts "Size: #{row[:size]}" if column(:size).present?
    #   end
    def present?
      !@data.index.nil?
    end
    
    # Sugar, simply the opposite of #present?
    def missing?
      !present?
    end
    
    def parses?
      !@parse.nil?
    end
    
    def validates?
      !@validate.nil?
    end
    
    def calculates?
      !@calculate.nil?
    end
    
    def errors
      @data.errors
    end
    
    def error_values
      errors.collect(&:value).uniq
    end

    def error_values?
      error_values.any?
    end
    
    # Pretty name for ourselves
    def to_s
      if !virtual? && @data.header_text.blank?
        "Column #{@data.pos}"
      else
        name = virtual? ? key.to_s : @data.header_text
        name = name.gsub(/(^[a-z]|\s[a-z])/) {|m| m.capitalize } 
        "#{name} Column"
      end
    end
    
    # Extracts the imported values for this column and returns them in an array.
    # Note that the array indices ARE NOT row indices, as the rows may have been
    # filtered and any header rows have been skipped.
    def to_a
      @importer.data.rows.collect {|r| r[@key] }
    end
    
    # Extracts the values for this column and returns them in a hash of
    # row num => value for all non-filtered, non-header rows.
    def to_h
      res = {}
      @importer.data.rows.collect {|r| res[r.num] = r[@key] }
      res
    end
    def to_hash ; to_h ; end
  
  end
  
end