#!/usr/bin/env ruby

require 'optparse'
require File.join(File.expand_path(File.dirname(__FILE__)), "cantora")

module Cantora

class RB-CANTORA-TEMPLATE

	include Cantora::Logger
	
	class << self
		include Cantora::CmdUtility
	end

	def self.commands
		return [File.basename(__FILE__, ".rb")]
	end
		
	def self.option_parser 
		return Opts
	end

	class Opts < Cantora::Opts

		def self.parse(argv)
			options = super(argv)
			
			caller = File.basename($0)
			optparse = OptionParser.new do |opts|
				
				opts.banner = "Usage: #{(caller == "cantora")? "#{$0} CMD" : $0 } [options] "
				opts.separator ""
				
				opts.separator "commands: #{RB-CANTORA-TEMPLATE::commands.join(", ")}" if caller == "cantora"

				opts.separator ""
				opts.separator "Common options:"
				options[:verbose] = false

				opts.on('-v', '--verbose', 'verbose output' ) do
					options[:verbose] = true
				end

				opts.on('-h', '--help', 'display this message' ) do
					raise ShowHelp.new, ""
				end
			end
			
			begin
				optparse.parse!(argv)
				
			rescue OptionParser::ParseError => e
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
	options = Cantora::RB-CANTORA-TEMPLATE.option_parser.parse(ARGV)
	obj = Cantora::RB-CANTORA-TEMPLATE.new(options)
	obj.run
end
		

