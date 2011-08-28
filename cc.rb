#!/usr/bin/env ruby

require 'optparse'
require File.join(File.expand_path(File.dirname(__FILE__)), "cantora")
require 'fileutils'

module Cantora

class CC

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
												
			optparse = OptionParser.new do |opts|
				opts.banner = "Usage: #{CC::commands.join(" | ")} [options] C-CODE"
				opts.separator ""

				options[:includes] = []
				opts.on('-I', '--include INCLUDE', '#include <INCLUDE>' ) do |include|
					options[:includes] << include
				end
		
				options[:quoted_includes] = []
				opts.on('-i', '--quoted-include INCLUDE', '#include "INCLUDE"' ) do |include|
					options[:quoted_includes] << include
				end
						
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

				options[:code] = argv.shift
			
				raise "invalid code: #{options[:code].inspect}" if options[:code].nil? || options[:code].strip.empty?
				
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
	
	CMAIN_PREFIX = "int main() {"

	CMAIN_SUFFIX = "return 0;}"

	HOME = File.expand_path(ENV["HOME"])
	TMP_DIR = File.join(HOME, ".rubycc")
	MAIN = File.join(TMP_DIR, "rubycc_main")
	
	def run
	
		main = self.class::generate_main(@options[:code], include_string)
		log main if @options[:verbose] == true

		write_main(main)

		gcc_output = compile

		log gcc_output if @options[:verbose] == true

		result = `#{MAIN}`

		puts result		
	end

	def self.generate_main(code, includes)
		code = [includes, CMAIN_PREFIX, code, CMAIN_SUFFIX].join("\n")
		
		return code
	end	
		
	def compile()
				
		gcc_result = `gcc -o #{MAIN} #{MAIN+".c"}`
		raise "gcc did not produce output: #{gcc_result}" if !File.file?(MAIN)

		return gcc_result 
	end

	def write_main(code)
		setup_dir
		File.open(MAIN+".c", "w") {|f| f << code}

	end

	def setup_dir
		FileUtils.mkdir_p(TMP_DIR)
		FileUtils.rm(MAIN) if File.file?(MAIN)
		
	end

	def include_string
		return ((["stdio.h"] + @options[:includes]).collect {|i| "#include <#{i}>"} + @options[:quoted_includes].collect {|i| "#include \"#{i}\""}).join("\n")
	end

end #CC

end #Cantora

if $0 == __FILE__
	options = Cantora::CC::Opts.parse(ARGV)
	obj = Cantora::CC.new(options)
	obj.run
end
		

