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
# The row.all? call will verify that each row passed contains a value for all defined columns.
#
# A more realistic and complex example follows:
#
#   importer = Importer.build do
#     column :order_number do
#       match /order (num.*|id)/i
#     end
#     column :date
#     column :amount
#   end
#
class Importer 

  # Array of error message or nil for each non-header row
  attr_accessor :errors, :warnings
  attr_accessor :sheets
  attr_reader :data, :custom_reader
  # Source file/stream encoding, assumes UTF-8 if none specified
  dsl_accessor :encoding

  def self.build(options = {}, &block)
    importer = Importer.new(options)
    importer.build(&block)
    importer
  end

  def initialize(options = {})
    @encoding = 'UTF-8'
    @sheets = {}
    
    reset
  end
  
  # Takes a block, and sets self to be importer instance, so you can
  # just call #column, #sheet, etc. directly.
  def build(&block)
    DslProxy.exec(self, &block) if block
    self
  end
  
  # For the common case where there is only one "sheet", e.g. CSV files.
  def default_sheet(&block)
    sheet(1, true, &block)
  end
  
  # Access a Sheet definition by id (either number (1-N) or sheet name).
  # Used during #build calls to define a sheet with a passed block, like so:
  #
  #   Importer.build do
  #     sheet(1) do
  #       column :store_name
  #       column :store_address
  #     end
  #     sheet('Orders') do
  #       column :id
  #       column :price
  #       filter do |row|
  #         row[:price].prensent?
  #       end
  #     end
  #   end
  def sheet(id, create=true, &block)
    # Find the sheet, creating it if needed (and requested!)
    if @sheets[id].nil?
      if create
        @sheets[id] = Sheet.new(self, id)
      else
        return nil
      end
    end
    sheet = @sheets[id]
    
    # Allow customization by DSL block if requested
    sheet.build(&block) if block
    
    # Return the sheet
    sheet
  end

  # Define a custom file reader to implement your own sheet parsing.
  def on_file(&block)
    @custom_reader = CustomReader.new(self) unless @custom_reader
    @custom_reader.set_reader(:file, block)
  end
  
  def on_stream(&block)
    @custom_reader = CustomReader.new(self) unless @custom_reader
    @custom_reader.set_reader(:stream, block)
  end
  
  # Very, very commonly we only want to deal with the default sheet.  In this case,
  # let folks skip the sheet(n) do ... end block wrapper and just define columns
  # against the main importer.  Internally, proxy those calls to the first sheet.
  def column(*args, &block)
    default_sheet.column(*args, &block)
  end
  
  # Ditto for filters
  def filter(*args, &block)
    default_sheet.filter(*args, &block)
  end
  
  # Ditto for start row too
  def start_row(row_num)
    default_sheet.start_row(row_num)
  end
  
  # More facading
  def headerless!
    default_sheet.headerless!
  end
  
  # First call to a freshly #build'd importer, this will read the file/stream/path supplied,
  # validate the required values, run custom validations... basically pre-parse and
  # massage the supplied data.  It will return true on success, or false if one
  # or more errors were encountered and the import failed.
  #
  # You may supply various options for the import using the options hash.  Supported
  # options include:
  #
  #   format: one of :auto, :csv, :xls, :xlsx, defaults to :auto, forces treating the supplied
  #           source as the specified format, or auto-detects if set to :auto
  #   encoding: source encoding override, defaults to guessing based on input
  #   
  # Generally, you should be able to throw a source at it and it should work.  The
  # options exist to allow overriding in cases where the automation heuristics
  # have failed and the input type is known by the caller.
  #
  # After #import has completed successfully, you can process the resulting data
  # using #process or extract the raw data by calling #to_hash or #sheet(num).to_a
  def import(path_or_stream, options = {})
    # Clear all our load-time state, including all rows, header locations... you name it
    reset
    
    # Get the reader for this format
    default = @custom_reader ? :custom : :auto
    format = options.delete(:format) { default }
    if format == :custom
      # Custom format selected, use our internal custom reader
      @data = @custom_reader
      
    elsif format && format != :auto
      # Explicit format requested
      @data = DataReader::for_format(self, format)
      unless @data
        add_error("Unable to find format handler for format #{format} - aborting")
        return
      end
      
    else
      # Auto select
      @data = DataReader::for_source(self, path_or_stream)
    end

    # Read in the data!
    @data.load(path_or_stream)
  end

  # Process a specific sheet, or the default sheet if none is provided.  Your
  # passed block will be handed one Row at a time.
  def process(sheet_id = nil, &block)
    s = sheet(sheet_id, false) || default_sheet
    s.process(&block)
  end
  
  def add_error(context, msg = nil)
    if context.is_a?(String) && msg.nil?
      msg = context
      context = nil
    end
    @errors << Error.new(context, msg)
  end
  
  def has_errors?
    @errors.any?
  end
  
  def add_warning(context, msg)
    if context.is_a?(String) && msg.nil?
      msg = context
      context = nil
    end
    @warnings << Error.new(context, msg)
  end
  
  def has_warnings?
    @warnings.any?
  end
  
  # Returns a human-readable summary of the errors present on the importer
  def error_summary
    return nil unless has_errors?
    @errors.collect(&:summary).list_join(', ')
  end

  protected
  
  def reset
    @errors = []
    @warnings = []
    @sheets.values.each(&:reset)
  end
  
end
