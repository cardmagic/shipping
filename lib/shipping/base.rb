# Author::    Lucas Carlson  (mailto:lucas@rufy.com)
# Copyright:: Copyright (c) 2005 Lucas Carlson
# License::   LGPL

module Shipping
	VERSION = "1.5.1"

	class ShippingError < StandardError; end
	class ShippingRequiredFieldError < StandardError; end

	class Base
		attr_reader :data, :response, :plain_response, :required

		attr_writer :ups_license_number, :ups_shipper_number, :ups_user, :ups_password, :ups_url, :ups_tool
		attr_writer :fedex_account, :fedex_meter, :fedex_url

		attr_accessor :name, :phone, :company, :email, :address, :address2, :city, :state, :zip, :country
		attr_accessor :sender_name, :sender_phone, :sender_company, :sender_email, :sender_address, :sender_city, :sender_state, :sender_zip, :sender_country

		attr_accessor :weight, :weight_units, :insured_value, :declared_value, :transaction_type, :description
		attr_accessor :measure_units, :measure_length, :measure_width, :measure_height
		attr_accessor :package_total, :packaging_type, :service_type

		attr_accessor :ship_date, :dropoff_type, :pay_type, :currency_code, :image_type, :label_type

		def initialize(options = {})
			prefs = File.expand_path(options[:prefs] || "~/.shipping.yml")
			YAML.load(File.open(prefs)).each {|pref, value| eval("@#{pref} = #{value.inspect}")} if File.exists?(prefs)

			@required = Array.new

			# include all provided data
			options.each do |method, value| 
				instance_variable_set("@#{method}", value)
			end

		end

		# Initializes an instance of Shipping::FedEx with the same instance variables as the base object
		def fedex
			Shipping::FedEx.new prepare_vars
		end

		# Initializes an instance of Shipping::UPS with the same instance variables as the base object
		def ups
			Shipping::UPS.new prepare_vars
		end

		def self.state_from_zip(zip)
			zip = zip.to_i
			{
				(99500...99929) => "AK", 
				(35000...36999) => "AL", 
				(71600...72999) => "AR", 
				(75502...75505) => "AR", 
				(85000...86599) => "AZ", 
				(90000...96199) => "CA", 
				(80000...81699) => "CO", 
				(6000...6999) => "CT", 
				(20000...20099) => "DC", 
				(20200...20599) => "DC", 
				(19700...19999) => "DE", 
				(32000...33999) => "FL", 
				(34100...34999) => "FL", 
				(30000...31999) => "GA", 
				(96700...96798) => "HI", 
				(96800...96899) => "HI", 
				(50000...52999) => "IA", 
				(83200...83899) => "ID", 
				(60000...62999) => "IL", 
				(46000...47999) => "IN", 
				(66000...67999) => "KS", 
				(40000...42799) => "KY", 
				(45275...45275) => "KY", 
				(70000...71499) => "LA", 
				(71749...71749) => "LA", 
				(1000...2799) => "MA", 
				(20331...20331) => "MD", 
				(20600...21999) => "MD", 
				(3801...3801) => "ME", 
				(3804...3804) => "ME", 
				(3900...4999) => "ME", 
				(48000...49999) => "MI", 
				(55000...56799) => "MN", 
				(63000...65899) => "MO", 
				(38600...39799) => "MS", 
				(59000...59999) => "MT", 
				(27000...28999) => "NC", 
				(58000...58899) => "ND", 
				(68000...69399) => "NE", 
				(3000...3803) => "NH", 
				(3809...3899) => "NH", 
				(7000...8999) => "NJ", 
				(87000...88499) => "NM", 
				(89000...89899) => "NV", 
				(400...599) => "NY", 
				(6390...6390) => "NY", 
				(9000...14999) => "NY", 
				(43000...45999) => "OH", 
				(73000...73199) => "OK", 
				(73400...74999) => "OK", 
				(97000...97999) => "OR", 
				(15000...19699) => "PA", 
				(2800...2999) => "RI", 
				(6379...6379) => "RI", 
				(29000...29999) => "SC", 
				(57000...57799) => "SD", 
				(37000...38599) => "TN", 
				(72395...72395) => "TN", 
				(73300...73399) => "TX", 
				(73949...73949) => "TX", 
				(75000...79999) => "TX", 
				(88501...88599) => "TX", 
				(84000...84799) => "UT", 
				(20105...20199) => "VA", 
				(20301...20301) => "VA", 
				(20370...20370) => "VA", 
				(22000...24699) => "VA", 
				(5000...5999) => "VT", 
				(98000...99499) => "WA", 
				(49936...49936) => "WI", 
				(53000...54999) => "WI", 
				(24700...26899) => "WV", 
				(82000...83199) => "WY"
				}.each do |range, state|
					return state if range.include? zip
				end

				raise ShippingError, "Invalid zip code"
			end

		private

			def prepare_vars #:nodoc:
				h = eval(%q{instance_variables.map {|var| "#{var.gsub("@",":")} => #{eval(var+'.inspect')}"}.join(", ").chomp(", ")})
				return eval("{#{h}}")
			end

			# Goes out, posts the data, and sets the @response variable with the information
			def get_response(url)
				check_required
				uri            = URI.parse url
				http           = Net::HTTP.new uri.host, uri.port
				if uri.port == 443
					http.use_ssl	= true
					http.verify_mode = OpenSSL::SSL::VERIFY_NONE
				end
				@response_plain = http.post(uri.path, @data).body
				@response       = @response_plain.include?('<?xml') ? REXML::Document.new(@response_plain) : @response_plain

				@response.instance_variable_set "@response_plain", @response_plain
				def @response.plain; @response_plain; end
			end

			# Make sure that the required fields are not empty
			def check_required
				for var in @required
					raise ShippingRequiredFieldError, "The #{var} variable needs to be set" if eval("@#{var}").nil?
				end
			end

			STATES = {"al" => "alabama", "ne" => "nebraska", "ak" => "alaska", "nv" => "nevada", "az" => "arizona", "nh" => "new hampshire", "ar" => "arkansas", "nj" => "new jersey", "ca" => "california", "nm" => "new mexico", "co" => "colorado", "ny" => "new york", "ct" => "connecticut", "nc" => "north carolina", "de" => "delaware", "nd" => "north dakota", "fl" => "florida", "oh" => "ohio", "ga" => "georgia", "ok" => "oklahoma", "hi" => "hawaii", "or" => "oregon", "id" => "idaho", "pa" => "pennsylvania", "il" => "illinois", "pr" => "puerto rico", "in" => "indiana", "ri" => "rhode island", "ia" => "iowa", "sc" => "south carolina", "ks" => "kansas", "sd" => "south dakota", "ky" => "kentucky", "tn" => "tennessee", "la" => "louisiana", "tx" => "texas", "me" => "maine", "ut" => "utah", "md" => "maryland", "vt" => "vermont", "ma" => "massachusetts", "va" => "virginia", "mi" => "michigan", "wa" => "washington", "mn" => "minnesota", "dc" => "district of columbia", "ms" => "mississippi", "wv" => "west virginia", "mo" => "missouri", "wi" => "wisconsin", "mt" => "montana", "wy" => "wyoming"}
		end
	end
