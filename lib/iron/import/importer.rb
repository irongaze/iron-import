# Implements the entry-point for our importing system.  To use, construct
# an importer using the builder syntax (examples below), then run one or more
# files or streams through the import system.
#
# Constructing a simple importer:
#
#   importer = Importer.build do
#     column :order_number
#     column :date
#     column :amount
#   end
#
# To use this importer simply call:
#
#   if importer.import('/path/to/file.xls')
#     importer.process do |row|
#       puts "Order #{row[:order_number]: #{row[:amount]} on #{row[:date]}"
#     end
#   end
#
# A more realistic and complex example follows:
#
#   Importer.build do
#     # Define our columns and settings
#     column :order_number do
#       header /order (num.*|id)/i
#       type :int
#     end
#     column :date do
#       type :date
#     end
#     column :amount do
#       type :cents
#     end
#  
#     # Filter out any rows missing an order number
#     filter do |row|
#       !row[:order_number].nil?
#     end
#
#   end.import('/path/to/file.csv', format: :csv) do |row|
#     # Process each row as basically a hash of :column_key => value,
#     # only called on import success
#     Order.create(row.to_hash)
#
#   end.on_error do
#     # If we have any errors, do something
#     raise error_summary
#   end
#
class Importer 

  # Inner class for holding load-time data that gets reset on each load call
  class Data
    attr_accessor :start_row, :rows
    def initialize
      @start_row = nil
      @rows = []
    end
  end

  # Array of defined columns
  attr_reader :columns
  # Array of error messages collected during an import/process run
  attr_accessor :errors
  # Custom reader, if one has been defined using #on_file or #on_stream
  attr_reader :custom_reader
  # Set to the format selected during past import
  attr_reader :format
  # Import data
  attr_reader :data
  # Missing headers post-import
  attr_reader :missing_headers

  # When true, skips header detection
  dsl_flag :headerless
  # Explicitly sets the row number (1-indexed) where data rows begin,
  # usually left defaulted to nil to automatically start after the header
  # row.
  dsl_accessor :start_row
  # Set to a block/lambda taking a parsed but unvalidated row as a hash,
  # return true to keep, false to skip.
  dsl_accessor :filter
  # Source file/stream encoding, assumes UTF-8 if none specified
  dsl_accessor :encoding

  # Create a new importer!  See #build for details on what to do
  # in the block.
  def self.build(options = {}, &block)
    importer = Importer.new(options)
    importer.build(&block)
    importer
  end

  # Ye standard constructor!
  def initialize(options = {})
    @scopes = {}
    @encoding = 'UTF-8'
    @headerless = false

    @filter = nil
    @columns = []
    
    reset
  end
  
  # Call to define the importer's column configuration and other setup options.
  #
  # The following builder options are available:
  # 
  #   importer = Importer.build do
  #     # Don't try to look for a header using column definitions, there is no header
  #     headerless!
  #
  #     # Manually set the start row for data, defaults to nil
  #     # indicating that the data rows start immediatly following the header.
  #     start_row 4
  #
  #     # Define a filter that will skip unneeded rows.  The filter command takes
  #     # a block that receives the parsed (but not validated!) row data as an 
  #     # associative hash of :col_key => <parsed value>, and returns 
  #     # true to keep the row or false to exclude it.
  #     filter do |row|
  #       row[:id].to_i > 5000
  #     end
  #
  #     # If you need to process a type of input that isn't built in, define
  #     # a custom reader with #on_file or #on_stream
  #     on_file do |path|
  #       ... read file at path, return array of each row's raw column values ...
  #     end
  #
  #     # Got a multi-block format like Excel or HTML?  You can optionally limit 
  #     # searching by setting a scope or scopes to search:
  #     scope :xls, 'Sheet 2'
  #     # Or set a bunch of scopes in one go:
  #     scopes :html => ['div > table.data', 'table.aux-data'],
  #            :xls => [2, 'Orders']
  #
  #     # Of course, the main thing you're going to do is to define columns.  See the
  #     # Column class' notes for options when defining a column.  Note that
  #     # you can define columns using either hash-style:
  #     column :id, :type => :integer
  #     # or builder-style:
  #     column :name do
  #       header /company\s*name/i
  #       type :string
  #     end
  #   end
  def build(&block)
    DslProxy.exec(self, &block) if block
    self
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
  
  # Limit the search scope for a single format (:xls, :xlsx, :html, :custom)
  # to the given value or values - the meaning and format of scopes is determined
  # by that format's data reader.
  def scope(format, *scopes)
    @scopes[format] = scopes.flatten
  end
  
  # Limit the search scope for more than one format at a time.  For example, if
  # you support both XLS and XLSX formats (and why wouldn't you?) then you
  # could tell the importer to look only at the sheets named "Orders" and
  # "Legacy Orders" like so:
  #
  #   scopes :xls => ['Orders', 'Legacy Orders'],
  #          :xlsx => ['Orders', 'Legacy Orders']
  #
  def scopes(map = :__read__)
    if map == :__read__
      return @scopes
    else
      map.each_pair do |format, scope|
        scope(format, scope)
      end
    end
  end

  # Define a custom file reader to implement your own parsing.  Pass
  # a block accepting a file path, and returning an array of arrays (rows of
  # raw column values).  Use #add_error(msg) to add a reading error.
  # 
  # Adding a custom stream parser will change the importer's default
  # format to :custom, though you can override it when calling #import as 
  # usual.
  #
  # Only one of #on_file or #on_stream needs to be implemented - the importer
  # will cross convert as needed!
  #
  # Example:
  #
  #   on_file do |path|
  #     # Read a file line by line
  #     File.readlines(path).collect do |line|
  #       # Each line has colon-separated values, so split 'em up
  #       line.split(/\s*:\s*/)
  #     end
  #   end
  #
  def on_file(&block)
    @custom_reader = CustomReader.new(self) unless @custom_reader
    @custom_reader.set_reader(:file, block)
  end
  
  # Just like #on_file, but for streams.  Pass
  # a block accepting a stream, and returning an array of arrays (rows of
  # raw column values).  Use #add_error(msg) to add a reading error.
  # 
  # Example:
  #
  #   on_stream do |stream|
  #     # Stream contains rows separated by a | char
  #     stream.readlines('|').collect do |line|
  #       # Each line has 3 fields of 10 characters each
  #       [line[0...10], line[10...20], line[20...30]]
  #     end
  #   end
  #
  def on_stream(&block)
    @custom_reader = CustomReader.new(self) unless @custom_reader
    @custom_reader.set_reader(:stream, block)
  end
  
  # First call to a freshly #build'd importer, this will read the file/stream/path supplied,
  # validate the required values, run custom validations... basically pre-parse and
  # massage the supplied data.  It will return true on success, or false if one
  # or more errors were encountered and the import failed.
  #
  # You may supply various options for the import using the options hash.  Supported
  # options include:
  #
  #   format: one of :auto, :csv, :html, :xls, :xlsx, defaults to :auto, forces treating the supplied
  #           source as the specified format, or attempts to auto-detect if set to :auto
  #   scope: specify the search scope for the data/format, overriding any scope set with #scope
  #   encoding: source encoding override, defaults to guessing based on input
  #   
  # Generally, you should be able to throw a path or stream at it and it should work.  The
  # options exist to allow overriding in cases where the automation heuristics
  # have failed and the input type is known by the caller.
  #
  # If you're trying to import from a raw string, use Importer#import_string instead.
  #
  # After #import has completed successfully, you can process the resulting data
  # using #process or extract the raw data by calling #to_a to get an array of row hashes
  #
  # Note that as of version 0.7.0, there is a more compact operation mode enabled by passing 
  # a block to this call:
  #
  #    importer.import(...) do |row|
  #      # Process each row here
  #    end
  #
  # In this mode, the block is called with each row as in #process, conditionally on no
  # errors.  In addition, when a block is passed, true/false is not returned (as the
  # block is already conditionally called).  Instead, it will return the importer to allow
  # chaining to #on_error or other calls.
  def import(path_or_stream, options = {}, &block)
    # Clear all our load-time state, including all rows, header locations... you name it
    reset
    
    # Get the reader for this format
    default = @custom_reader ? :custom : :auto
    @format = options.delete(:format) { default }
    if @format == :custom
      # Custom format selected, use our internal custom reader
      @reader = @custom_reader
      
    elsif @format && @format != :auto
      # Explicit format requested
      @reader = DataReader::for_format(self, @format)
      
    else
      # Auto select
      @reader = DataReader::for_source(self, path_or_stream)
      @format = @reader.format
    end

    # Verify we got one
    unless @reader
      add_error("Unable to find format handler for format :#{format} on import of #{path_or_stream.class.name} source - aborting")
      return
    end
    
    # What scopes (if any) should we limit our searching to?
    scopes = options.delete(:scope) { @scopes[@format] }
    if scopes && !scopes.is_a?(Array)
      scopes = [scopes]
    end

    # Read in the data!
    @reader.load(path_or_stream, scopes) do |raw_rows|
      # Find our column layout, start of data, etc
      if find_header(raw_rows)
        # Now, run all the data and add it as a Row instance
        raw_rows.each_with_index do |raw, index|
          row_num = index + 1
          if row_num >= @data.start_row
            add_row(row_num, raw)
          end
        end
        # We've found a workable sheet/table/whatever, stop looking
        true
        
      else
        # This sheet/table/whatever didn't have the needed header, try
        # the next one (if any)
        false
      end
    end
    
    # If we have any missing headers, note that fact
    if @missing_headers && @missing_headers.count > 0
      add_error("Unable to locate required column header for column(s): " + @missing_headers.collect{|c| ":#{c}"}.list_join(', '))
    end
    
    # If we're here with no errors, we rule!
    success = !has_errors?
    
    if block
      # New way, if block is passed, process it on success
      process(&block) if success
      self
    else
      # Old way, return result
      success
    end
  end

  # Use this form of import for the common case of having a raw CSV or HTML string.
  def import_string(string, options = {}, &block)
    # Get a format here if needed
    if options[:format].nil?
      if @custom_reader
        format = :custom
      else
        format = string.include?('<table') && string.include?('</tr>') ? :html : :csv
      end
      options[:format] = format
    end
    
    # Do the import, converting the string to a stream
    import(StringIO.new(string), options, &block)
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
        add_error(row, e.to_s)
      end
    end
  end
  
  def on_error(&block)
    raise 'Invalid block passed to Importer#on_error: block may accept 0, 1 or 2 arguments' if block.arity > 2
    
    if has_errors?
      case block.arity
      when 0 then DslProxy.exec(self, &block)
      when 1 then DslProxy.exec(self, @errors, &block)
      when 2 then DslProxy.exec(self, @errors, error_summary, &block)
      end
    end
    
    self
  end
  
  # Process the raw values for the first rows in a sheet,
  # and attempt to build a map of the column layout, and
  # detect the first row of real data
  def find_header(raw_rows)
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
      @missing_headers = nil
      return true
      
    else
      # Match by testing
      missing = nil
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
          # Found all columns, have a map, update our start row to be the next line and return!
          @data.start_row = @start_row || i+2
          @missing_headers = nil
          return true
        else
          missing = remaining if (missing.nil? || missing.count > remaining.count)
        end
      end
      
      # If we get here, we're hosed
      @missing_headers = missing.collect(&:key) if @missing_headers.nil? || @missing_headers.count > missing.count
      false
    end
  end

  # Add a new row to our stash, parsing/filtering/validating as we go!
  def add_row(line, raw_data)
    # Gracefully handle custom parsers that return nil for a row's data
    raw_data ||= []
    # Add the row
    row = Row.new(self, line)
    
    # Parse out the values
    values = {}
    @columns.each do |col|
      index = col.data.index
      raw_val = raw_data[index]
      if col.parse
        # Use custom parser if this row has one
        val = col.parse_value(row, raw_val)
      else
        # Otherwise use our standard parser
        val = @reader.parse_value(raw_val, col.type)
      end
      values[col.key] = val
    end

    # Set the values and filter if needed
    row.set_values(values)
    return nil if @filter && !@filter.call(row)

    # Row is desired, now validate values
    @columns.each do |col|
      val = values[col.key]
      col.validate_value(row, val)
    end
    
    # We is good
    @data.rows << row
    row
  end

  # When true, one or more errors have been recorded during this import/process
  # cycle.
  def has_errors?
    @errors.any?
  end
  
  # Add an error to our error list.  Will result in a failed import.
  def add_error(context, msg = nil)
    if context.is_a?(String) && msg.nil?
      msg = context
      context = nil
    end
    @errors << Error.new(context, msg)
  end
  
  # Returns a human-readable summary of the errors present on the importer, or
  # nil if no errors are present
  def error_summary
    # Simple case
    return nil unless has_errors?

    # Group by error text - we often get the same error dozens of times
    list = {}
    @errors.each do |err|
      errs = list[err.text] || []
      errs << err
      list[err.text] = errs
    end
    
    # Build summary & return
    list.values.collect do |errs|
      summary = errs.first.summary
      if errs.count == 1
        summary
      else
        errs.count.to_s + ' x ' + summary
      end
    end.list_join(', ')
  end
  
  # After calling #import, you can dump the final values for each row
  # as an array of hashes.  Useful in debugging!  For general processing,
  # use #process or the block form of #import instead.
  def to_a
    @data.rows.collect(&:values)
  end

  protected
  
  def reset
    @errors = []
    @missing_headers = nil
    @format = nil
    @reader = nil
    @data = Data.new
  end
  
end
