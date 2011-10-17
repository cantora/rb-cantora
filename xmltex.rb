#!/usr/bin/env ruby

require 'optparse'
require File.join(File.expand_path(File.dirname(__FILE__)), "cantora")

require 'rexml/document'
require 'digest/md5'

module Cantora

class XmlTex

	include Cantora::Logger
	
	class << self
		include Cantora::CmdUtility
	end

	def self.commands
		return ["srs", "cheat-sheet"]
	end
		
	def self.option_parser 
		return Opts
	end

	class Opts < Cantora::Opts

		def self.parse(argv)
			options = super(argv)
			
			caller = File.basename($0)									
			optparse = OptionParser.new do |opts|
				opts.banner = "Usage: #{caller} CMD [options] OUTPUT "
				opts.separator ""
				opts.separator "commands: #{XmlTex::commands.join(", ")}"

				opts.separator ""
				opts.separator "srs options:"

				options[:tex2im] = "tex2im"
				opts.on("--tex2im PATH", "specify the path to tex2im shell file. default: #{options[:tex2im].inspect}") do |path|
					options[:tex2im] = path
				end

				options[:clobber] = false
				opts.on("--[no-]clobber", "when creating image files overwrite any existing image files that were previously created. default: #{options[:clobber].inspect}") do |clob|
					options[:clobber] = clob
				end
				
				opts.separator ""
				opts.separator "cheat-sheet options:"

				options[:reformat] = true
				opts.on("--[no-]reformat", "reformat for better readability. default: #{options[:reformat].inspect}") do |ref|
					options[:reformat] = ref
				end
				
				opts.separator ""
				opts.separator "Common options:"
				options[:verbose] = false

				opts.on("-f", "--input-file FILE", "specify the xml file with latex elements") do |file|
					options[:file] = file
				end

				opts.on("-d", "--header-file FILE", "specify a latex header file") do |file|
					options[:tex_header] = file
				end

				opts.on("-x", "--latex-xpath XPATH", "specify the xpath of questions and/or answer elements. default: #{options[:latex].inspect}") do |latex|
					options[:latex] = latex
				end
				
				opts.on('-v', '--verbose', 'verbose output' ) do
					options[:verbose] = true
				end

				opts.on('-h', '--help', 'display this message' ) do
					raise ShowHelp.new
				end
			end
			
			begin
				optparse.parse!(argv)

				options[:command] = argv.shift
				options[:output] = argv.shift
				
				raise OptionParser::MissingArgument.new("must supply a valid command: #{XmlTex::commands.join(", ")}") if options[:command].nil? || !XmlTex::commands.include?(options[:command])
				raise OptionParser::MissingArgument.new("must supply a valid input file") if options[:file].nil? || !File.file?(options[:file])
				raise OptionParser::MissingArgument.new("must supply an output path") if options[:output].nil? 
				
				if options[:command] == "srs"
					FileUtils.mkdir options[:output] if !File.directory?(options[:output])
				end
				
			rescue OptionParser::ParseError => e
				puts e.message 
				puts optparse
				
				exit
			end	
			
			return options
		end  # parse()

	end	  

	EQUATION = "equation"
	LATEX = "latex"
	HEBREW = "hebrew"  
	LATEX_TYPES = [EQUATION, HEBREW]
	NON_EQN_TYPES = [HEBREW]
	
	HEADERS = {
		HEBREW => "\\usepackage{ucs}   % package to add unicode support \n\\usepackage[utf8x]{inputenc}  % adding the UTF-8 encoding \n\\usepackage[english,hebrew]{babel}  % telling babel: english & hebrew in doc. \n\\usepackage{hebfont}  % Adding a selection of fonts. \n \\fontfamily{miriam}\\selectfont",
		EQUATION => "\\usepackage{amsmath} \n \\usepackage{amsfonts}"
		}
	
	PREFIXES = {
		HEBREW => "\\fontfamily{franknikud}\\selectfont"
		}
	
	def initialize(options)
		@options = options
		
		log @options.inspect if @options[:verbose] == true		

		@pretty_xml = REXML::Formatters::Pretty.new
	end
		
	MAX_WIDTH = 256
	MAX_HEIGHT = 180
		
	def create_latex_png(latex_code, file_path, equation, headers)
		#puts "create latex png with code:\n #{latex_code.inspect}"
		latex = File::open("/tmp/xml2srs_latex.tmp", "w")
		latex << latex_code
		latex << "\n"
		latex.close		
		
		header = File::open("/tmp/xml2srs_header.tmp", "w")
		header << headers
		header.close
		
		intermediate = file_path+".tmp"
		
		FileUtils.rm file_path if File.file?(intermediate)
				
		#"#{@options[:tex2im]} -f png -a -z -r 1000x1000 -o #{intermediate} #{latex.path}"
		cmd = "#{@options[:tex2im]} #{(equation == true)? "" : "-n" } -f png -x #{header.path} -b red -r 1000x1000 -o #{intermediate} #{latex.path}" #"#{@options[:tex2im]} -f png -a -z -t red -r 1000x1000 -o #{intermediate} #{latex.path}"
		#
		log "create latex png with cmd: #{cmd.inspect}" if @options[:verbose] == true
		
		system(cmd)
		raise "#{cmd.inspect} did not produce the intended output file #{intermediate}" if !File.file?(intermediate)
		
		FileUtils.rm file_path if File.file?(file_path)
		convert_cmd = "convert #{intermediate} -resize #{MAX_WIDTH}x#{MAX_HEIGHT} #{file_path}"
		#exit		
		log "convert latex png with cmd: #{convert_cmd.inspect}" if @options[:verbose] == true
		
		system(convert_cmd)

		FileUtils.rm intermediate
		raise "#{convert_cmd.inspect} did not produce the intended output file #{file_path}" if !File.file?(file_path)
		
		return true
	end
	
	def log_xml(node)
		print_string = ""
		@pretty_xml.write(node, print_string)
		log print_string
	end
	
	def create_latex_element(src_e, deckname, equation, headers, prefix)
		
		md5 = Digest::MD5::hexdigest(src_e.text)
		png_name = "latex_#{md5}.png"
		filepath = File.join(@options[:output], png_name)
		
		#log src_e.text
		
		create_latex_png(prefix + src_e.text, filepath, equation, headers) unless @options[:clobber] == false && File.file?(filepath)
		
		new_e = REXML::Element.new(src_e.name)
		new_e.add_attributes({"image" => File.join("/NDSRS", "data", "img", deckname, png_name)})
		new_e.text = ""
		
		return new_e
	end

	def run
		case @options[:command]
		when "srs"
			srs
		when "cheat-sheet"
			cheat_sheet
		else
			raise "invalid command"
		end
	end

	def self.get_headers(card_element, equation)
		eqn = equation
		ce = card_element

		headers = []
		HEADERS.each do |k,v|
			if (!ce.attributes[k].nil? && (ce.attributes[k] == "true")	) || (k == EQUATION && eqn == true)
				headers << v
			end
		end

		return headers
	end

	def self.get_prefix(card_element)
		ce = card_element
		prefix = ""

		PREFIXES.each do |k,v|
			if !ce.attributes[k].nil? && (ce.attributes[k] == "true")	
				prefix << "\n" + v + "\n"
			end
		end

		return prefix					
	end

	def self.equation?(card_element)
		ce = card_element
		eqn = true
		eqn = false if !ce.attributes[EQUATION].nil? && ce.attributes[EQUATION] == "false" # assume equation is true for legacy reasons
		
		return eqn
	end

	def self.eqn_conflict?(card_element)
		ce = card_element

		NON_EQN_TYPES.each do |name|
			return name if !ce.attributes[name].nil? && ce.attributes[name] == "true" 
		end

		return nil
	end

	def self.latex_conflict?(card_element)
		ce = card_element
		LATEX_TYPES.each do |name|
			return name if !ce.attributes[name].nil? && (ce.attributes[name] == "true")
		end
		
		return nil				
	end

	def self.card_is_latex?(card_element)
		ce = card_element
		return !ce.attributes[LATEX].nil? && (ce.attributes[LATEX] == "true")
	end

	CS_TMP_FILE_BASE = "/tmp/#{File.basename(__FILE__, ".rb")}.cheat-sheet"
	CS_TMP_TEX = CS_TMP_FILE_BASE + ".tex"
	CS_TMP_DVI = CS_TMP_FILE_BASE + ".dvi"
	CS_TMP_PS = CS_TMP_FILE_BASE + ".ps"

	CS_SCRIPT_PREFIX = <<GOGOGOGO 
cd #{File.dirname(CS_TMP_FILE_BASE)}
rm -v #{CS_TMP_DVI} #{CS_TMP_PS}
latex #{CS_TMP_TEX}
dvips -t a4 -Ppdf #{CS_TMP_DVI}
GOGOGOGO

	def cheat_sheet
		
		cards = []
		all_headers = {}

		File::open(@options[:file], "r") do |f|
			d = REXML::Document.new(f)
			
			count = 0

			d.root.get_elements("/deck/card").each do |e| 
				count += 1
				
				card_text = ""
				e.each_element do |ce|
					prefix_lines = []
					suffix_lines = []
					log_xml ce if @options[:verbose] == true
						
					eqn = self.class::equation?(ce)

					#puts "eqn: #{eqn.inspect}"
					if eqn == true
						conflicting_attr = self.class::eqn_conflict?(ce)
						raise "#{conflicting_attr} cannot be true while 'equation' = 'true' " if !conflicting_attr.nil?
			
						prefix_lines << "\\begin{math}"
						suffix_lines << "\\end{math}"
					end
					
					headers = self.class::get_headers(ce, eqn)
					
					#puts headers.inspect
					
					headers.each do |h|
						all_headers[h] = true
					end
					#puts ce.text
					suffix_lines << "\n"

					ce_text = if @options[:reformat] == true
						ce.text.gsub("\\\\", "\\mbox{ }")
					else
						ce.text
					end

					puts ce_text
					#readline
					card_text << (prefix_lines + [ce_text] + suffix_lines).join("\n") + "\n"
				end
				
				cards << [card_text, "\\vspace{10 mm}"].join("\n") + "\n"
			end #elements.each
			
		end #file

		#puts cards.size

		#puts all_headers.keys.inspect

		File::open(CS_TMP_TEX, "w") do |f|
			f << "\\documentclass{article}\n"
			f << "\\usepackage[parfill]{parskip}\n"
			f << all_headers.keys.join("\n") + "\n"

			f << "\\begin{document}\n"
			
			cards.each do |c|
				f << c + "\n"
			end

			f << "\\end{document}\n"
		end #tmp_tex

		output_path = File.expand_path(@options[:output])

		script = [CS_SCRIPT_PREFIX, "cp -fv #{CS_TMP_PS} #{output_path}"].join("\n")
		#puts script

		Kernel.exec(script)
	end

	def srs
		deckname = File.basename(@options[:file]).split(/\.[^\.]+$/)[0]
		
		File::open(@options[:file], "r") do |f|
			d = REXML::Document.new(f)
			
			out = REXML::Document.new("<deck></deck>")
			
			count = 0
			d.root.get_elements("/deck/card").each do |e| 
				count += 1
											
				card = REXML::Element.new(e.name)
				e.each_element do |ce|
					log_xml ce if @options[:verbose] == true

					if !ce.attributes[LATEX].nil? && (ce.attributes[LATEX] == "true")
						eqn = true
						eqn = false if !ce.attributes[EQUATION].nil? && ce.attributes[EQUATION] == "false" # assume equation is true for legacy reasons
						
						#puts "eqn: #{eqn.inspect}"
						NON_EQN_TYPES.each do |name|
							raise "#{name} cannot be true while 'equation' = 'true' " if !ce.attributes[name].nil? && ce.attributes[name] == "true" 
						end if eqn == true
						
						headers = ""
						
						HEADERS.each do |k,v|
							if (!ce.attributes[k].nil? && (ce.attributes[k] == "true")	) || (k == EQUATION && eqn == true)
								headers << "\n" + v + "\n"
							end
						end
						
						prefix = ""
						PREFIXES.each do |k,v|
							if !ce.attributes[k].nil? && (ce.attributes[k] == "true")	
								prefix << "\n" + v + "\n"
							end
						end
						
						#puts headers.inspect									
						new_e = create_latex_element(ce, deckname, eqn, headers, prefix)
						
						#log_xml new_e if @options[:verbose] == true
						card.root.add_element(new_e)
					else
						LATEX_TYPES.each do |name|
							raise "invalid attr #{attr} for non-latex element" if !ce.attributes[name].nil? && (ce.attributes[name] == "true")
						end
						
						card.root.add_element(ce)
					end						
				end
				
				out.root.add_element(card)
			
				
				log "wrote #{count} card"
			end #elements.each
						
			fmt = REXML::Formatters::Default.new
			File::open(File.join(@options[:output], deckname+".srs"), "w") do |outfile|
				fmt.write(out, outfile)
			end
		end #file
	end
	
end #XmlTex

end #Cantora

if $0 == __FILE__
	options = Cantora::XmlTex.option_parser.parse(ARGV)
	obj = Cantora::XmlTex.new(options)
	obj.run
end
		

