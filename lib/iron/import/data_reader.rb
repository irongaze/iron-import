class Importer

  # Base class for our input reading - dealing with the raw file/stream,
  # and extracting raw values.  In addition, we provide the base
  # data coercion/parsing for our derived classes.
  class DataReader

    # Attributes
    attr_reader :format

    def self.verify_roo!
      if Gem::Specification.find_all_by_name('roo', '~> 1.13.0').empty?
        raise "You are attempting to use the iron-import gem to import an Excel file.  Doing so requires installing the roo gem, version 1.13.0 or later."
      else
        require 'roo'
      end
    end

    def self.verify_nokogiri!
      if Gem::Specification.find_all_by_name('nokogiri', '~> 1.6.0').empty?
        raise "You are attempting to use the iron-import gem to import an HTML file.  Doing so requires installing the nokogiri gem, version 1.6.0 or later."
      else
        require 'nokogiri'
      end
    end

    # Implement our automatic reader selection, based on the import source
    def self.for_source(importer, source)
      data = nil
      if is_stream?(source)
        data = DataReader::for_stream(importer, source)
        unless data
          importer.add_error("Unable to find format handler for stream")
        end
      else
        data = DataReader::for_path(importer, source)
        unless data
          importer.add_error("Unable to find format handler for file #{source}")
        end
      end
      data
    end

    # Factory method to build a reader from an explicit format selector
    def self.for_format(importer, format)
      case format
      when :csv
        CsvReader.new(importer)
      when :xls
        verify_roo!
        XlsReader.new(importer)
      when :xlsx
        verify_roo!
        XlsxReader.new(importer)
      when :html
        verify_nokogiri!
        HtmlReader.new(importer)
      else
        nil
      end
    end
    
    # Figure out which format to use for a given path based on file name
    def self.for_path(importer, path)
      format = path.to_s.extract(/\.(csv|html?|xlsx?)\z/i)
      if format
        format = format.downcase
        format = 'html' if format == 'htm'
        format = format.to_sym
        for_format(importer, format)
      else
        nil
      end
    end
    
    # Figure out which format to use based on a stream's source file info
    def self.for_stream(importer, stream)
      path = path_from_stream(stream)
      for_path(importer, path)
    end
    
    # Attempt to determine if the given source is a stream
    def self.is_stream?(source)
      # For now, just assume anything that has a #read method is a stream, in
      # duck-type fashion
      source.respond_to?(:read)
    end

    # Try to find the original file name for the given stream,
    # as in the case where a file is uploaded to Rails and we're dealing with an
    # ActionDispatch::Http::UploadedFile.
    def self.path_from_stream(stream)
      if stream.respond_to?(:original_filename)
        stream.original_filename
      elsif stream.respond_to?(:path)
        stream.path
      else
        nil
      end
    end
    
    def initialize(importer, format)
      @importer = importer
      @format = format
      @supports = []
    end

    def supports?(mode)
      @supports.include?(mode)
    end
    
    def supports_stream!
      @supports << :stream
    end
    
    def supports_file!
      @supports << :file
    end
    
    def supports_file?
      supports?(:file)
    end
    
    def supports_stream?
      supports?(:stream)
    end
    
    # Core data reader method.  Takes a given input source (either a stream or
    # a file path) and attempts to load it.  Returns true if successful, false
    # if not.  If false, there will be one or more errors explaining what went
    # wrong.
    #
    # Passed scopes are interpreted by each derived class as makes sense, but
    # generally are used to target seaching in multi-block formats such as
    # Excel spreadsheets (sheet name/index) or HTML documents (css selectors,
    # xpath selectors).  If scopes is nil, all possible blocks will be checked.
    #
    # Each block is read in as raw data from the source, and passed to the
    # given block as an array of arrays.  If the block returns true, processing
    # is stopped and no further blocks will be checked.
    def load(path_or_stream, scopes = nil, &block)
      # Figure out what we've been passed, and handle it
      if self.class.is_stream?(path_or_stream)
        # We have a stream (open file, upload, whatever)
        if supports_stream?
          # Stream loader defined, run it
          load_each(:stream, path_or_stream, scopes, &block)
        else
          # Write to temp file, as some of our readers only read physical files, annoyingly
          file = Tempfile.new(['importer', ".#{format}"])
          file.binmode
          begin
            file.write path_or_stream.read
            file.close
            load_each(:file, file.path, scopes, &block)
          ensure
            file.close
            file.unlink
          end
        end
        
      elsif path_or_stream.is_a?(String)
        # Assume it's a path
        is_path = File.exist?(path_or_stream) rescue false
        if is_path
          if supports_file?
            # We're all set, load up the given path
            load_each(:file, path_or_stream, scopes, &block)
          else
            # No file handler, so open the file and run the stream processor
            file = File.open(path_or_stream, 'rb')
            load_each(:stream, file, scopes, &block)
          end
        else
          add_error("Unable to locate source file with path #{path_or_stream.slice(0,200)}")
        end
        
      else
        add_error("Unable to load data source - not a file path or stream: #{path_or_stream.inspect}")
      end
      
      # Return our status
      !@importer.has_errors?
    end
    
    # Load up the sheet in the correct mode
    def load_each(mode, source, scopes, &block)
      # Handle some common error cases centrally
      if mode == :file && !File.exist?(source)
        add_error("File not found: #{source}")
        return
      end
      
      # Let our derived classes open the file, etc. as they need
      if init_source(mode, source)
        # Once the source is set, run through each defined sheet, pass it to
        # our sheet loader, and have the sheet parse it out.
        load_raw(scopes, &block)
      end
    end
    
    # Override this method in derived classes to set up
    # the given source in the given mode
    def init_source(mode, source)
      raise "Unimplemented method #init_source in data reader #{self.class.name}"
    end
    
    # Override this method in derived classes to take the given sheet definition,
    # find that sheet in the input source, and read out the raw (unparsed) rows
    # as an array of arrays.  Return false if the sheet cannot be loaded.
    def load_raw(scopes, &block)
      raise "Unimplemented method #load_raw in data reader #{self.class.name}"
    end
    
    # Provides default value parsing/coersion for all derived data readers.  Attempts to be clever and
    # handle edge cases like converting '5.00' to 5 when in integer mode, etc.  If you find your inputs aren't
    # being parsed correctly, add a custom #parse block on your Column definition.
    def parse_value(val, type)
      return nil if val.nil? || val.to_s.strip == ''
      
      case type
      when :raw then
        val
        
      when :string then
        if val.is_a?(Float)
          # Sometimes float values come in for "integer" columns from Excel,
          # so if the user asks for a string, strip off that ".0" if present
          val.to_s.gsub(/\.0+$/, '')
        else
          # Strip whitespace and we're good to go
          val.to_s.strip
        end
        
      when :integer, :int then 
        if val.class < Numeric
          # If numeric, verify that there's no decimal places to worry about
          if (val.to_f % 1.0 == 0.0)
            val.to_i
          else
            nil
          end
        else 
          # Convert to string, strip off trailing decimal zeros
          val = val.to_s.strip.gsub(/\.0*$/, '')
          if val.integer?
            val.to_i
          else
            nil
          end
        end
        
      when :float then
        if val.class < Numeric
          val.to_f
        else 
          # Clean up then verify it matches a valid float format & convert
          val = val.to_s.strip
          if val.match(/\A-?[0-9]+(?:\.[0-9]+)?\z/)
            val.to_f
          else
            nil
          end
        end
        
      when :cents then
        if val.is_a?(String)
          val = val.gsub(/\s*\$\s*/, '')
        end
        intval = parse_value(val, :integer)
        if !val.is_a?(Float) && intval
          intval * 100
        else
          floatval = parse_value(val, :float)
          if floatval
            (floatval * 100).round
          else
            nil
          end
        end
        
      when :date then
        # Pull out the date part of the string and convert
        date_str = val.to_s.extract(/[0-9]+[\-\/][0-9]+[\-\/][0-9]+/)
        date_str.to_date rescue nil
        
      else
        raise "Unknown column type #{type.inspect} - unimplemented?"
      end
    end
    
    def add_error(*args)
      @importer.add_error(*args)
    end
    
    def add_exception(*args)
      @importer.add_exception(*args)
    end
    
  end
  
end