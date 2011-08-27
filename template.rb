#!/usr/bin/env ruby

require 'optparse'
require File.join(File.expand_path(File.dirname(__FILE__)), "cantora")

module Cantora

class RB-CANTORA-TEMPLATE

	include Cantora::Logger
	
	COMMANDS = [File.basename(__FILE__, ".rb")]

	class Opts < Cantora::Opts

		def self.parse(argv)
			options = super(argv)
												
			optparse = OptionParser.new do |opts|
				opts.banner = "Usage: #{COMMANDS.join(" | ")} [options] "
				opts.separator ""
				
				opts.separator ""
				opts.separator "Common options:"
				options[:verbose] = false

				opts.on('-v', '--verbose', 'verbose output' ) do
					options[:verbose] = true
				end

				opts.on('-h', '--help', 'display this message' ) do
					raise ""
				end
			end
			
			begin
				optparse.parse!(argv)
				
			rescue Exception => e
				puts e.message
				puts optparse
				
				exit
			end	
			
			return options
		end  # parse()

	end	  
	
	def initialize(options)
		@options = options
		
		log @options.inspect if @options[:verbose] == true		
	end
		
	def run
		
	end
	
end #RB-CANTORA-TEMPLATE

end #Cantora

if $0 == __FILE__
	options = Cantora::RB-CANTORA-TEMPLATE::Opts.parse(ARGV)
	obj = Cantora::RB-CANTORA-TEMPLATE.new(options)
	obj.run
end
		

