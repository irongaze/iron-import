class Importer

  # Columns represent the settings for importing a given column within a Sheet.  They do not
  # hold data, rather they capture the settings needed for identifying the column in the header,
  # how to parse and validate each of their cell's data, and so forth.
  #
  # Here's the complete list of column configuration options:
  #
  #   Importer.build do
  #     column :key do
  #       # Set a fixed position - may be a column number or a letter-based
  #       # column description, ie 'A' == 1.  In most cases, you can leave
  #       # this defaulted to nil, which will mean "look for the proper header"
  #       position 'C'
  #
  #       # Specify a regex to locate the header for this column, defaults to 
  #       # finding a string containing the key.
  #       header /(price|cost)/i
  #
  #       # Tells the data parser what type of data this column contains, one
  #       # of :integer, :string, :date, :float, or :cents.  Defaults to :string.
  #       type :cents
  #
  #       # Instead of a type, you can set an explicit parse block.  Be aware
  #       # that different source types may give you different raw values for what
  #       # seems like the "same" source value, for example an Excel source file
  #       # will give you a float value for all numeric types, even "integers"
  #       parse do |raw_value|
  #         raw_value.to_i + 1000
  #       end
  #      
  #       # You can also add a custom validator to check the value and add
  #       # an error if it's not within a given range, or whatever:
  #       validate do |parsed_value|
  #         raise "Out of range" unless (parsed_value > 0 && parsed_value < 5000)
  #       end
  #     end
  #   end
  #
  class Column

    # Holds load-time data
    class Data
      attr_accessor :index
      
      def pos
        @index ? Column::index_to_pos(@index) : 'Unknown'
      end
    end

    # Core info
    attr_reader :key
    attr_reader :data

    # Configuration
    dsl_flag :required
    dsl_accessor :header, :position, :type
    dsl_accessor :parse, :validate
   
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
   
    def initialize(sheet, key)
      # Save off our info
      @key = key
      @sheet = sheet
      @importer = @sheet.importer
      
      # Return it as a string, by default
      @type = :string
      
      # By default, we allow empty values
      @required = false
      
      # Position can be explicitly set
      @position = nil
      
      # By default, don't parse incoming data, just pass it through
      @parse = nil
      
      # Default matcher, looks for the presence of the column key as text anywhere
      # in the header string, ignoring case and using underscores as spaces, ie
      # :order_id => /\A\s*order id\s*\z/i
      @header = Regexp.new('\A\s*' + key.to_s.gsub('_', ' ') + '\s*\z', Regexp::IGNORECASE)
      
      # Reset our state to pre-load status
      reset
    end
    
    def build(&block)
      DslProxy.exec(self, &block)
    end
    
    def reset
      @data = Data.new
    end
    
    # When true, matches either the passed value or the index (if position has been explicitly set)
    def match_header?(text, index)
      res = index == self.fixed_index || (@header && !@header.match(text).nil?)
      # puts "#{@header.inspect} ~ #{text.inspect} => #{res.inspect}"
      res
    end
    
    # Use any custom parser defined to process the given value, capturing
    # errors as needed
    def parse_value(row, val)
      return val if @parse.nil?
      begin 
        @parse.call(val)
      rescue Exception => e
        @importer.add_error(row, "Error parsing #{self}: #{e}")
        nil
      end
    end
    
    def validate_value(row, val)
      return unless @validate
      begin 
        @validate.call(val)
        true
      rescue Exception => e
        @importer.add_error(row, "Validation error in #{self}: #{e}")
        false
      end
    end
    
    def fixed_index
      return nil unless @position
      if @position.is_a?(Fixnum)
        @position - 1
      elsif @position.is_a?(String)
        Column.pos_to_index(@position)
      end
    end
    
    def to_s
      'Column ' + @data.pos
    end
    
    def to_a
      @sheet.data.rows.collect {|r| r[@key] }
    end
    
    def to_h
      res = {}
      @sheet.data.rows.collect {|r| res[r.num] = r[@key] }
      res
    end
  
  end
  
end