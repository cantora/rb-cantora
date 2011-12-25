#!/usr/bin/env ruby

require 'optparse'
require File.join(File.expand_path(File.dirname(__FILE__)), "cantora")
require 'rubygems'
require 'cgi'
require 'rest-open-uri'
require 'socket'

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

	def self.get(url, query, headers, options, escape_query=true)
		query_str = query_string(query, {:escape => escape_query})
		url += "?" + query_str if !query_str.empty?

		raise "invalid headers: #{headers.inspect}" if !headers.is_a?(Hash)
		raise "invalid options: #{options.inspect}" if !options.is_a?(Hash)

		return send_request(url, headers.merge(options))
	end

	def self.post(url, query, headers, options)
		query_str = query_string(query)
		
		raise "invalid headers: #{headers.inspect}" if !headers.is_a?(Hash)
		raise "invalid options: #{options.inspect}" if !options.is_a?(Hash)
		
		options.merge!({:body => query_string(query), :method => :post})
		return send_request(url, headers.merge(options))
	end

	def self.send_request(url, options)
		puts "url: #{url.inspect}"
		puts "options: #{options.inspect}"

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
		

