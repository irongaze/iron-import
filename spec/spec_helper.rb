# Set up development requirements
require 'roo'

# Require our library
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'iron', 'import'))

# Config RSpec options
RSpec.configure do |config|
  config.color = true
  config.add_formatter 'documentation'
  config.backtrace_exclusion_patterns = [/rspec/]
end

module SpecHelper
  
  # Helper to find sample file paths
  def self.sample_path(file)
    File.expand_path(File.join(File.dirname(__FILE__), 'samples', file))
  end
  
end
