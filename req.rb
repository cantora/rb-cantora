#!/usr/bin/env ruby

require 'optparse'
require File.join(File.expand_path(File.dirname(__FILE__)), "cantora")
require 'rubygems'
require 'cgi'
require 'rest-open-uri'
require 'socket'

class OptionParser

	def on_invalid_option(&bloc)
		@on_invalid_option = bloc
	end

	class InvalidOption
		attr_accessor :option
	end

	def old_complete(typ, opt, icase = false, *pat)
		if pat.empty?
			search(typ, opt) {|sw| return [sw, opt]} # exact match or...
		end
		raise AmbiguousOption, catch(:ambiguous) {
			visit(:complete, typ, opt, icase, *pat) {|o, *sw| return sw}
			e = InvalidOption.new(opt)
			e.option = opt
			raise e
		}
	end
	private :old_complete

	def complete(*args)
		retried = false
		#puts "complete: #{args.inspect}"
		result = begin
			old_complete(*args)
		rescue InvalidOption => e
			if !@on_invalid_option.nil?
				result = @on_invalid_option.call(e.option)
				if result && retried == false
					retried = true
					retry
				end
			end

			raise e
		end

		#puts "result: #{result.inspect}"

		return result
	end
	
end

module Cantora

class Req

	include Cantora::Logger
	
	class << self
		include Cantora::CmdUtility
	end

	def self.commands
		return ["get", "post"]
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
				
				opts.separator "commands: #{Req::commands.join(", ")}" if caller == "cantora"

				opts.separator ""
				opts.separator "Common options:"

				opts.on_invalid_option do |name|
					case_result = true
					case name
					when /^h-/
						opts.on("--#{name} VAL", "HTTP header key/value pair") do |val|
							options[:headers] ||= {}
							options[:headers][name[2..-1]] = val
						end
					when /^q-/
						opts.on("--#{name} VAL", "query key/value pair") do |val|
							options[:query] ||= {}
							options[:query][name[2..-1]] = val
						end
					else
						case_result = false
					end
	
					case_result
				end

				opts.on("-u", "--url URL", "url to make the request to") do |url|
					options[:url] = url
				end

				opts.on("--bloc BLOC", "a bloc which will be passed the options hash") do |code|
					options[:bloc] = eval(code)
					raise "invalid bloc does not respond to call" if !options[:bloc].respond_to?(:call)
				end

				opts.on("-q", "--query STR", "query string") do |val|
					options[:query_str] = val
				end

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

				options[:cmd] = argv.shift
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
		if @options[:verbose]
			Net::BufferedIO.class_exec do
				alias_method :old_write0, :write0
				def write0(str)
					print str
					return old_write0(str)
				end
			end
		end
		
		if !@options[:cmd].nil? && !@options[:cmd].empty? && self.respond_to?(@options[:cmd].to_sym)
			self.send(@options[:cmd].to_sym)
		else
			raise "invalid command #{@options[:cmd].inspect}"
		end
	end

	def post
		uri = URI.parse(@options[:url]) rescue nil
		raise "invalid url: #{@options[:url].inspect}" if uri.nil?
		
		q = if !@options[:query_str].nil?
			@options[:query_str]
		else
			@options[:query] || {}
		end
		output = do_post(uri, q, @options[:headers] || {}, \
					{}, true, &@options[:bloc])
		puts "\n\n"
		puts output
	end

	def do_get(url, query, headers, options, escape_query=true)
		query_str = self.class::query_string(query, {:escape => escape_query})
		url += "?" + query_str if !query_str.empty?

		raise "invalid headers: #{headers.inspect}" if !headers.is_a?(Hash)
		raise "invalid options: #{options.inspect}" if !options.is_a?(Hash)

		return send_request(url, headers.merge(options))
	end

	def do_post(url, query, headers, options, escape_query=true, &bloc)
		raise "invalid headers: #{headers.inspect}" if !headers.is_a?(Hash)
		raise "invalid options: #{options.inspect}" if !options.is_a?(Hash)
		
		body = if query.is_a?(Hash)
			 self.class::query_string(query, {:escape => escape_query})
		else
			query
		end

		options.merge!({:body => body, :method => :post})
		options = headers.merge(options)
		bloc.call(options) if !bloc.nil?
		return send_request(url, options)
	end

	def send_request(url, options)
		puts "url: #{url.inspect}" if @options[:verbose]
		puts "options: #{options.inspect}" if @options[:verbose]

		return open(url, options) do |f|
			f.readlines.join
		end
	end

	def self.query_string(query, options={:escape => true})
		raise "invalid query: #{query.inspect}" if !query.is_a?(Hash)

		return query.collect do |k,v| 
			key = options[:escape]? CGI::escape(k) : k
			val = options[:escape]? CGI::escape(v) : v

			"#{key}=#{val}"
		end.join("&")
	end

	
end #Req

end #Cantora

if $0 == __FILE__
	options = Cantora::Req.option_parser.parse(ARGV)
	obj = Cantora::Req.new(options)
	obj.run
end
		

