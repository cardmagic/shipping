# Author::    Lucas Carlson  (mailto:lucas@rufy.com)
# Copyright:: Copyright (c) 2005 Lucas Carlson
# License::   LGPL

=begin
	UPS Service				transaction_type
	--------------------------------------------- 
	Next Day Air Early	1DM 
	Next Day Air			1DA 
	Next Day Air Intra	1DAPI (Puerto Rico) 
	Next Day Air Saver	1DP 
	2nd Day Air A 			M2DM 
	2nd Day Air				2DA 
	3 Day Select			3DS 
	Ground					GND 
	Canada Standard		STD 
	Worldwide Express		XPR 
	Worldwide Express		XDM 
	Worldwide Expedited	XPD 
=end

module Shipping
   class UPS < Base
            
      API_VERSION = "1.0001"
      
      # For current implementation docs, see http://www.ec.ups.com/ecommerce/techdocs/pdf/RatesandServiceHTML.pdf
      # For upcoming implementation docs, see http://www.ups.com/gec/techdocs/pdf/dtk_RateXML_V1.zip
   	def price
   		@required = [:zip, :country, :sender_zip, :weight]
   		
         @insured_value ||= 0
         @country ||= 'US'
         @sender_country ||= 'US'
         @transaction_type ||= 'GND' # default to UPS ground
         
   		@data = "AppVersion=1.2&AcceptUPSLicenseAgreement=yes&ResponseType=application/x-ups-rss&ActionCode=3&RateChart=Customer+Counter&DCISInd=0&SNDestinationInd1=0&SNDestinationInd2=0&ResidentialInd=$r&PackagingType=00&ServiceLevelCode=#{@transaction_type}&ShipperPostalCode=#{@sender_zip}&ShipperCountry=#{@sender_country}&ConsigneePostalCode=#{@zip}&ConsigneeCountry=#{@country}&PackageActualWeight=#{@weight}&DeclaredValueInsurance=#{@insured_value}"

   		get_response "http://www.ups.com/using/services/rave/qcost_dss.cgi"
   		
   		price = @response.split("%")
   		price = price[price.size-2]
   		
   		return price.to_f
   	end
      
      # See http://www.ups.com/gec/techdocs/pdf/dtk_AddrValidateXML_V1.zip for API info
      
      def valid_address?( delta = 1.0 )
         @required = [:ups_account, :ups_user, :ups_password]
         
         state = STATES.has_value?(@state.downcase) ? STATES.index(@state.downcase) : @state
         
         @data = String.new
         b = Builder::XmlMarkup.new :target => @data
         
         b.instruct!
         b.AccessRequest {|b|
            b.AccessLicenseNumber @ups_account
            b.UserId @ups_user
            b.Password @ups_password
         }
         b.instruct!
         b.AddressValidationRequest {|b|
            b.Request {|b|
               b.RequestAction "AV"
               b.TransactionReference {|b|
                  b.CustomerContext "#{@city}, #{state} #{@zip}"
                  b.XpciVersion API_VERSION
               }
            }
            b.Address {|b|
               b.City @city
               b.StateProvinceCode state
               b.PostalCode @zip
            }
         }
         
   	   get_response "https://wwwcie.ups.com/ups.app/xml/AV"
         
   		if REXML::XPath.first(@response, "//AddressValidationResponse/Response/ResponseStatusCode").text == "1" && REXML::XPath.first(@response, "//AddressValidationResponse/AddressValidationResult/Quality").text.to_f >= delta
   		   return true
   		else
   		   return false
   		end
      end
   end
end