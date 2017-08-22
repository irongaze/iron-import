# Set up development requirements
require 'roo'
require 'nokogiri'

# Require our library
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'iron', 'import'))

# Config RSpec options
RSpec.configure do |config|
  config.color = true
  config.add_formatter 'documentation'
  config.backtrace_exclusion_patterns = [/rspec/]
  # Allow us to use: it '...', :focus do ... end 
  # rather than needing: it '...', :focus => true do ... end
  config.treat_symbols_as_metadata_keys_with_true_values = true
  # If everything is filtered, run everything - used if no :focus element is present
  config.run_all_when_everything_filtered = true
end

module SpecHelper
  
  # Helper to find sample file paths
  def self.sample_path(file)
    File.expand_path(File.join(File.dirname(__FILE__), 'samples', file))
  end
  
end
