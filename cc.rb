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
		return [File.basename(__FILE__, ".rb"), "asm"]
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
				
				options[:cc_opts] = ""
				opts.on('-o', '--cc-opts OPTS', 'options to pass to compiler' ) do |cc_opts|
					options[:cc_opts] = cc_opts
				end
				
				
				options[:util_binary] = false
				opts.on('--util-binary', 'define: void printbits(int n)' ) do |butil|
					options[:util_binary] = true
				end
						
				options[:auto_main] = true
				opts.on('--[no-]auto-main', "automatically define main and insert code into main body. default: #{options[:auto_main].inspect}") do |auto_main|
					options[:auto_main] = auto_main
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
				
				options[:cmd] = argv.shift
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
	
		main = generate_main(@options[:code], include_string)
		log main if @options[:verbose] == true

		write_main(main)

		if @options[:cmd] == "asm"		
			@options[:cc_opts] ||= ""
			@options[:cc_opts] += "-O0 -S "
		end

		gcc_output = compile

		log gcc_output if @options[:verbose] == true

		case @options[:cmd]
		when "cc"
			result = `#{MAIN}`
		when "asm"
			result = File.read(MAIN)
		else
			raise "invalid command: #{@options[:cmd].inspect}"
		end

		puts result		
	end

	def generate_main(code, includes)
		cmain_prefix, cmain_suffix = if @options[:auto_main]
			[CMAIN_PREFIX, CMAIN_SUFFIX]
		else
			["", ""]
		end

		code = [includes, function_defs, cmain_prefix, code, cmain_suffix].join("\n")
		
		return code
	end	

	def function_defs
		s = ""
		s << BINARY_UTIL if @options[:util_binary]

		return s
	end
	
	def gcc_command
		cmd = "gcc "

		cmd << (@options[:cc_opts] || "")
		cmd << " -o #{MAIN} #{MAIN+'.c'}"

		return cmd
	end
		
	def compile()
		cmd = gcc_command	
		
		#puts gcc_command.inspect
		gcc_result = `#{cmd}`
		raise "gcc did not produce output:\n#{gcc_command}\n#{gcc_result}" if !File.file?(MAIN)

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

	BINARY_UTIL = <<QWERQWER
void printbits(int n, int groupsize) {
	unsigned int i, step;

	if (0 == n) { /* For simplicity's sake, I treat 0 as a special case*/
		printf("0000");
		return;
	}

	i = 1<<(sizeof(n) * 8 - 1);

	step = -1; /* Only print the relevant digits */
	step >>= groupsize; 
	while (step >= n) {
		i >>= groupsize;
		step >>= groupsize;
	}

	/* At this point, i is the smallest power of two larger or equal to n */
	while (i > 0) {
		if (n & i)
			printf("1");
		else
			printf("0");
		i >>= 1;
	}
}

void print32bits(int n) {
	unsigned int i, step;

	i = 1<<(sizeof(n) * 8 - 1);

	while (i > 0) {
		if (n & i)
			printf("1");
		else
			printf("0");
		i >>= 1;
	}
}

void pb(int n, int msb_i, int lsb_i) {
	unsigned int i;
	unsigned int lsb_bound;
	lsb_bound = (1<<lsb_i) - 1; 
	i = 1<<msb_i;
	//printf("i: %u, lsb_bound: %u\\n", i, lsb_bound);
	while (i > lsb_bound) {
		if (n & i)
			printf("1");
		else
			printf("0");
		i >>= 1;
	}
}

void pb64(long long n, int msb_i, int lsb_i) {
     	int i = 0;
	int amt = msb_i - lsb_i;
        long long mask = (0x01LL << msb_i);
        
	for(i = 0; i < amt+1; i++) {
		if (mask & n)
			printf("1");
		else
			printf("0");
		n <<= 1;
	}
}

void pbf(float f) {
	int *n = (int *) &f;
	pb(*n, 31, 31);
	printf(" ");
	pb(*n, 30, 23);
	printf(" ");
	pb(*n, 22, 0);

}

void pbd(double d) {
	long long *n = (long long *) &d;
	pb64(*n, 63, 63);
	printf(" ");
	pb64(*n, 62, 62-10);
	printf(" ");
	pb64(*n, 62-11, 0);

}

QWERQWER

end #CC

end #Cantora

if $0 == __FILE__
	options = Cantora::CC::Opts.parse(ARGV)
	obj = Cantora::CC.new(options)
	obj.run
end
		

