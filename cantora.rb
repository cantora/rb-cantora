
module Cantora

	module Logger
		def log(s="")
			print_log(s + "\n")		
		end
		
		def print_log(s="")
			#prefix="#{Time.now.to_s[0..-12]}:"
			#print prefix+s.to_s
			print s.to_s
			$stdout.flush
			$stderr.flush
		end
	end

	class Opts
		def self.parse(argv)
			return {}
		end

	end

	module CmdUtility
		
		def commands
			return []
		end

		def option_parser
			return Cantora::Opts
		end
	end

end