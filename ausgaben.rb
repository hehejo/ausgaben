#!/usr/bin/ruby 

require 'sqlite3'

# sanitize tags
# @param list of tags
# @return [String] sorted string of unique tags in lowercase 
def sanitize_tags(tags=Array.new)
	tags.map! {|x| x.downcase }
	tags.sort!.uniq.join(' ')
end


# parsing the actual time
# @return [Array] containing year, month
def parse_date
		now = Time.now
		t = ARGV.shift
		monat = now.month
		monat = t.to_i unless t.nil?

		t = ARGV.shift
		jahr = now.year
		jahr = t.to_i unless t.nil?
			
		return jahr, monat
end

# display the usage and exit
def usage
	puts <<EOU
Usage:	ausgaben {j,c,w}[g]add BETRAG [TAGS]
	ausgaben sum {jo|caro|wir} [MONAT] [JAHR]
	ausgaben list {jo|caro|wir} [MONAT] [JAHR]
	ausgaben ausgleich [MONAT] [JAHR]
EOU
	exit
end

# parsing name obtained from first commandline argument
# if no name of "jo caro wir" is found, jo is assumed
# @return [String] the current name to which actions apply 
def parse_name
	name = ARGV.shift
	unless %w(jo caro wir).include?(name)
		name = 'jo' 
		puts "assuming jo..."
	end
	return name
end

# parsing all the options from commandline
# @return [Hash] with :modus, :betrag, :tags, :jahr, :monat, and :name
def parse_options
main_opts = %w(jadd cadd jgadd cgadd wadd sum list ausgleich)
betrag_opts = %w(jadd cadd jgadd cgadd wadd)

	usage if ARGV.size < 1

	options = {:modus => ARGV.shift}

	usage unless main_opts.include?(options[:modus])

	if betrag_opts.include?(options[:modus])
		usage if ARGV.size < 1
		options[:betrag] = ARGV.shift.to_f
		options[:tags] = sanitize_tags(ARGV)

		options[:jahr] = Time.now.year
		options[:monat] = Time.now.month
	elsif options[:modus] == "sum" || options[:modus] == "list"
		#usage if ARGV.size < 1
		options[:name] = parse_name
		options[:jahr], options[:monat] = parse_date
	elsif options[:modus] == "ausgleich"
		options[:jahr], options[:monat] = parse_date
	end

	return options
end

# Class providing special methods to interact with database
class Ausgaben
	# short for johannes
	JOHANNES="jo"
	#short for caro
	CARO="caro"
	#short for wir
	WIR="wir"

	# initialize the class
	# @param opts the option hash obtained via parse_options
	def initialize(opts={})
		@db =  SQLite3::Database.new("/home/jo/dokumente/Ausgaben/ausgaben.db")

		@options = opts
		# lets do some metaprogramming and create a method for each possible action
		%w(jadd cadd jgadd cgadd wadd).each do |name|
				n = JOHANNES
				n = CARO if name[0] == 'c'
				if name[0] == 'w'
					n = WIR
					g = 'g'
				else
					g = name[1] == 'g' ? 'g' : 's' 
				end
				instance_eval %{
				def #{name}
					@options[:name] = "#{n}"
					@options[:gemeinsam] = "#{g}" 
					insert
				end
			}
		end

		
		return if @options.empty?
		self.send(@options.delete(:modus))
	end

	#def method_missing(method_name, *args)
	#	@options[:name] =  CARO if	method_name[0] == 'c'
	#	@options[:gemeinsam] = true if method_name[1] == 'g'
	#	insert
	#end

private 	

	# insert a new entry into ausgaben
	# using the options 
	def insert()
		@db.execute("insert into ausgaben (jahr, monat, name, betrag, gemeinsam, tags) values(:jahr, :monat, :name, :betrag, :gemeinsam, :tags)", @options)
	end


	# calculates the sum for the given options (month, year and name)
	# Sum is printed directly
	def sum
		printf("%02i.%i\n", @options[:monat], @options[:jahr])
		@db.execute("select summe, gemeinsam from sum_#{@options[:name]} where jahr = #{@options[:jahr]} and monat = #{@options[:monat]} ") do |row|
			printf("(%s) % .2f EUR \n", row[1], row[0])
		end
	end

	# create a list of ausgaben for the given options (month, year and name)
	# List is printed directly
	def list
		printf("%02i.%i\n", @options[:monat], @options[:jahr])
		@db.execute("select betrag, gemeinsam, tags from ausgaben_#{@options[:name]} where jahr = #{@options[:jahr]} and monat = #{@options[:monat]} order by jahr, monat, gemeinsam desc") do |row|
			printf("(%s) %s EUR [%s] \n", row[1], sprintf("%.2f",row[0]).rjust(7), row[2])
		end
	end
	
	# calculate the "Ausgleichzahlung" based on the entries for the given month, year
	# Ausgleich is printed directly
	def ausgleich
		sums = {}
		%w(jo caro).each do |who|
			sums[who] = @db.get_first_value("select summe from sum_#{who} where jahr = #{@options[:jahr]} and monat = #{@options[:monat]} and gemeinsam = 'g'").to_f
		end

		if(sums['jo'] == sums['caro'])
			puts "Gleichstand"
			return
		end

		ausg = ((sums['jo'] + sums['caro']) / 2 - sums['jo']).abs
		
		if(sums['jo'] > sums['caro'])
			printf("Caro an Jo: %.2f EUR\n", ausg)
		else
			printf("Jo an Caro: %.2f EUR\n", ausg)
		end
		
	end
end

if __FILE__ == $0
	opts = parse_options
	ausgaben = Ausgaben.new opts
end





