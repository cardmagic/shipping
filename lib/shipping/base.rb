# Author::    Lucas Carlson  (mailto:lucas@rufy.com)
# Copyright:: Copyright (c) 2005 Lucas Carlson
# License::   LGPL

module Shipping
   class ShippingError < StandardError; end

   class Base
      attr_reader :data, :response, :plain_response, :required

      attr_writer :ups_account, :ups_user, :ups_password
      attr_writer :fedex_account, :fedex_meter, :fedex_url

      attr_accessor :name, :phone, :email, :address, :city, :state, :zip, :country
      attr_accessor :sender_name, :sender_phone, :sender_email, :sender_address, :sender_city, :sender_state, :sender_zip, :sender_country

      attr_accessor :weight, :weight_units, :insured_value, :declared_value, :transaction_type, :description
      attr_accessor :package_total, :packaging_type, :service_type
      
		attr_accessor :ship_date, :dropoff_type, :pay_type, :currency_code

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
            raise ShippingError, "The #{var} variable needs to be set" if eval("@#{var}").nil?
         end
      end
      
      STATES = {"al" => "alabama", "ne" => "nebraska", "ak" => "alaska", "nv" => "nevada", "az" => "arizona", "nh" => "new hampshire", "ar" => "arkansas", "nj" => "new jersey", "ca" => "california", "nm" => "new mexico", "co" => "colorado", "ny" => "new york", "ct" => "connecticut", "nc" => "north carolina", "de" => "delaware", "nd" => "north dakota", "fl" => "florida", "oh" => "ohio", "ga" => "georgia", "ok" => "oklahoma", "hi" => "hawaii", "or" => "oregon", "id" => "idaho", "pa" => "pennsylvania", "il" => "illinois", "pr" => "puerto rico", "in" => "indiana", "ri" => "rhode island", "ia" => "iowa", "sc" => "south carolina", "ks" => "kansas", "sd" => "south dakota", "ky" => "kentucky", "tn" => "tennessee", "la" => "louisiana", "tx" => "texas", "me" => "maine", "ut" => "utah", "md" => "maryland", "vt" => "vermont", "ma" => "massachusetts", "va" => "virginia", "mi" => "michigan", "wa" => "washington", "mn" => "minnesota", "dc" => "district of columbia", "ms" => "mississippi", "wv" => "west virginia", "mo" => "missouri", "wi" => "wisconsin", "mt" => "montana", "wy" => "wyoming"}

   end
end
