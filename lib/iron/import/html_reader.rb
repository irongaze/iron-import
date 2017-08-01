class Importer
  
  class HtmlReader < DataReader
    
    def initialize(importer)
      super(importer, :html)
      supports_file!
      supports_stream!
      @tables = nil
    end
    
    def init_source(mode, source)
      if mode == :stream
        @html = Nokogiri::HTML(source)
      elsif mode == :file
        @html = File.open(source) {|f| Nokogiri::HTML(f) }
      else
        add_error("Unsupported HTML mode: #{mode}")
        return false
      end
      
      if @html
        true
      else
        add_error("Failed parsing of HTML")
        false
      end
      
    rescue Exception => e
      add_exception(e)
      false
    end
    
    def load_raw(scopes, &block)
      # Default to searching all tables in the document
      if scopes.nil? || scopes.empty?
        scopes = ['table']
      end
      
      # Catch here lets us break out of the nested loop cleanly
      catch(:found) do
        # Run each scope, which should be a valid css selector
        scopes.each do |scope|
          @html.css(scope).each do |table_node|
            rows = []
            table_node.css('tr').each do |row_node|
              row = []
              row_node.children.each do |cell_node|
                if ['th', 'td'].include?(cell_node.name)
                  row << cell_node.text.strip
                  # Handle col-span values appropriately
                  span_count = cell_node.attr('colspan')
                  (span_count.to_i - 1).times do 
                    row << nil
                  end
                end
              end
              rows << row
            end
            found = block.call(rows)
            throw(:found, true) if found
          end
        end
      end

    rescue Exception => e
      # Not sure why we'd get here, but we strive for error-freedom here, yessir.
      add_exception(e)
    end
  
  end
  
end