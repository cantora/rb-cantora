#!/usr/bin/env ruby

require 'optparse'
require File.join(File.expand_path(File.dirname(__FILE__)), "cantora")

#look into .pos 0x1234 directive for asm

module Cantora

class Asm

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
			options[:ops] = []	
			caller = File.basename($0)
			optparse = OptionParser.new do |opts|
				
				opts.banner = "Usage: #{(caller == "cantora")? "#{$0} CMD" : $0 } [options] OP1 [OP2 ...]"
				opts.separator ""
				
				opts.separator "commands: #{Asm::commands.join(", ")}" if caller == "cantora"

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
				argv.shift

				options[:ops] = argv
	
				raise OptionParser::ParseError.new("must provide some instructions") if options[:ops].empty?
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
		fname = "/tmp/asm_tmp.s"
		objname = "/tmp/asm_tmp.o"

		File.open(fname, "w") do |f|
			@options[:ops].each do |op|
				f << op;
				f << "\n"
			end
		end

		FileUtils.rm(objname) if File.file?(objname)
		output = `gcc -o #{objname} -c #{fname}`

		raise "failed to compile instructions: #{output.inspect}" if !File.file?(objname)

		File.open(objname, "r") do |f|
			f.seek(152, IO::SEEK_CUR)
			f.each_byte do |b|
				print sprintf("\\x%02x", b)
			end
		end

		puts
	end
	
end #Asm

end #Cantora

if $0 == __FILE__
	options = Cantora::Asm.option_parser.parse(ARGV)
	obj = Cantora::Asm.new(options)
	obj.run
end
		

