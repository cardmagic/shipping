# Author::    Lucas Carlson  (mailto:lucas@rufy.com)
# Copyright:: Copyright (c) 2005 Lucas Carlson
# License::   LGPL
#
#
# See http://www.fedex.com/us/solutions/wis/pdf/xml_transguide.pdf?link=4 for the full XML-based API

module Shipping
   class FedEx < Base
      # Gets the total price of the shipping
      def price
         get_price
         p = REXML::XPath.first(@response, "//FDXRateReply/EstimatedCharges/DiscountedCharges/NetCharge").text.to_f rescue nil
         raise ShippingError, get_error if p.nil?
         return p
      end
      
      # Gets the base price of the shipping (with discounts taken into consideration)
      def base_price
         get_price
         p = REXML::XPath.first(@response, "//FDXRateReply/EstimatedCharges/DiscountedCharges/BaseCharge").text.to_f rescue nil
         raise ShippingError, get_error if p.nil?
         return p
      end
      
		# still not sure what the best way to handle this transaction's return data would be. Possibly a hash of the form {service => delivery_estimate}?
		def express_service_availability
			
		   @data = String.new
			b = Builder::XmlMarkup.new :target => @data
			b.instruct!
			b.FDXServiceAvailabilityRequest('xmlns:api' => 'http://www.fedex.com/fsmapi', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation' => 'FDXServiceAvailabilityRequest.xsd') { |b|
				b.RequestHeader { |b|
					b.AccountNumber @fedex_account
					b.MeterNumber @fedex_meter
				}
				b.OriginAddress { |b|
					b.PostalCode @sender_zip
					b.CountryCode @sender_country_code || "US"
				}
				b.DestinationAddress { |b|
					b.PostalCode @zip
					b.CountryCode @country || "US"
				}
				b.ShipDate @ship_date unless @ship_date.nil?
				b.PackageCount @package_total || '1'
			}
			
			get_response @fedex_url
		end

		def subscription_request
		   @required = [:name, :company, :phone, :email, :address, :city, :state, :zip]
		   @required += [:fedex_account, :fedex_url]
		   
		   state = STATES.has_value?(@state.downcase) ? STATES.index(@state.downcase).upcase : @state.upcase

		   @data = String.new
		   b = Builder::XmlMarkup.new :target => @data
			b.instruct!
			b.FDXSubscriptionRequest('xmlns:api' => 'http://www.fedex.com/fsmapi', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation' => 'FDXSubscriptionRequest.xsd') { |b|
				b.RequestHeader { |b|
   				b.CustomerTransactionIdentifier @transaction_identifier if @transaction_identifier # optional
					b.AccountNumber @fedex_account
				}
				b.Contact { |b|
				   b.PersonName @name
				   b.CompanyName @company
				   b.Department @department if @department
				   b.PhoneNumber @phone.gsub(/[^\d]/,"")
				   b.tag! :"E-MailAddress", @email
				}
				b.Address { |b|
				   b.Line1 @address
				   b.Line2 @address2 if @address2
				   b.City @city
				   b.StateOrProvinceCode state
				   b.PostalCode @zip
				   b.CountryCode @country || 'US'
				}
		   }
		   
		   get_response @fedex_url
		   
		   return REXML::XPath.first(@response, "//FDXSubscriptionReply/MeterNumber").text
		end
		
		#     require 'fileutils'
		#     fedex = Shipping::FedEx.new :name => 'John Doe', ... , :sender_zip => 97202
		#     label = fedex.label
		#     FileUtils.cp label.path, '/path/to/my/images/directory/'
		#     puts label.tracking_number
		#
		def label
		   @required =  [:phone,        :email,        :address,        :city,        :state,        :zip        ]
		   @required += [:sender_phone, :sender_email, :sender_address, :sender_city, :sender_state, :sender_zip ]
		   @required += [:fedex_account, :fedex_url]
         
		   @transaction_type ||= 'rate_ground'
		   @weight = (@weight.to_f*10).round/10.0
		   @declared_value = (@declared_value.to_f*100).round/100.0 unless @declared_value.nil?
		   state = STATES.has_value?(@state.downcase) ? STATES.index(@state.downcase).upcase : @state.upcase
		   sender_state = STATES.has_value?(@sender_state.downcase) ? STATES.index(@sender_state.downcase).upcase : @sender_state.upcase

		   @data = String.new
		   
		   b = Builder::XmlMarkup.new :target => @data
			b.instruct!
			b.FDXEmailLabelRequest('xmlns:api' => 'http://www.fedex.com/fsmapi', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation' => 'FDXEmailLabelRequest.xsd') { |b|
   			b.RequestHeader { |b|
   				b.AccountNumber @fedex_account
   				b.MeterNumber @fedex_meter
   				b.CarrierCode TransactionTypes[@transaction_type][1]
   			}
   			b.URLExpirationDate((Time.now + 3600*24).strftime("%Y-%m-%d"))
   			b.tag! :"URLNotificationE-MailAddress", @sender_email
   			b.MerchantPhoneNumber @sender_phone.gsub(/[^\d]/,"")
   			b.Service ServiceTypes[@service_type] || ServiceTypes['ground_service'] # default to ground service
   			b.Packaging PackageTypes[@packaging_type] || 'YOURPACKAGING'
   			b.WeightUnits @weight_units || 'LBS' # or KGS
   			b.CurrencyCode @currency_code || 'USD'
   			b.Origin { |b|
   			   b.Contact { |b|
   			      if @sender_name.to_s.size > 2
      			      b.PersonName @sender_name
      			      b.CompanyName @sender_company unless @sender_company.nil?
      			   elsif @sender_company.to_s.size > 2
      			      b.PersonName @sender_name unless @sender_name.nil?
      			      b.CompanyName @sender_company
      			   else
      			      raise ShippingError, "Either the sender_name or the sender_company value must be bigger than 2 characters."
      			   end
      			   b.Department @sender_department unless @sender_department.nil?
      			   b.PhoneNumber @sender_phone.gsub(/[^\d]/,"")
      			   b.PagerNumber @sender_pager.gsub(/[^\d]/,"") if @sender_pager.class == String
      			   b.FaxNumber @sender_fax.gsub(/[^\d]/,"") if @sender_fax.class == String
   			      b.tag! :"E-MailAddress", @sender_email
   			   }
   			   b.Address { |b|
   			      b.Line1 @sender_address
   			      b.Line2 @sender_address2 unless @sender_address2.nil?
   			      b.City @sender_city
   			      b.StateOrProvinceCode sender_state
   			      b.PostalCode @sender_zip
   			      b.CountryCode @sender_country || 'US'
   			   }
   			}
   			b.Destination { |b|
      			b.Contact { |b|
         			if @name.to_s.size > 2
         			   b.PersonName @name
         			   b.CompanyName @company unless @company.nil?
         			elsif @company.to_s.size > 2
         			   b.PersonName @name unless @name.nil?
         			   b.CompanyName @company
         			else
         			   raise ShippingError, "Either the name or the company value must be bigger than 2 characters."
         			end
         			b.Department @department unless @department.nil?
      			   b.PhoneNumber @phone.gsub(/[^\d]/,"")
      			   b.PagerNumber @pager.gsub(/[^\d]/,"") if @pager.class == String
      			   b.FaxNumber @fax.gsub(/[^\d]/,"") if @fax.class == String
      			   b.tag! :"E-MailAddress", @email
      			}
      			b.Address { |b|
      			   b.Line1 @address
      			   b.Line2 @address2 unless @address2.nil?
      			   b.City @city
      			   b.StateOrProvinceCode state
      			   b.PostalCode @zip
      			   b.CountryCode @country || 'US'
      			}
      		}
      		b.Payment { |b|
      		   b.PayorType PaymentTypes[@pay_type] || 'SENDER'
      		   b.Payor { |b|
      		      b.AccountNumber @payor_account_number
      		      b.CountryCode @payor_country_code unless @payor_country_code.nil?
      		   } unless @payor_account_number.nil?
      		}
      		b.RMA { |b|
      		   b.Number @rma_number
      		} unless @rma_number.nil?
      		b.Package { |b|
      		   b.Weight @weight
      		   b.DeclaredValue @declared_value || '99.00'
      		   b.ReferenceInfo { |b|
      		      b.CustomerReference @customer_reference
      		   } unless @customer_reference.nil?
      		   b.ItemDescription @description || "Shipment"
      		}
      		b.SpecialServices { |b|
      		   b.EMailNotification { |b|
      		      b.ShipAlertOptionalMessage @message
      		      b.Shipper { |b|
      		         b.ShipAlert @shipper_ship_alert ? 'true' : 'false'
      		         b.LanguageCode @shipper_language || 'EN' # FR also available
      		      }
      		      b.Recipient { |b|
         		      b.ShipAlert @recipient_ship_alert ? 'true' : 'false'
         		      b.LanguageCode @recipient_language || 'EN' # FR also available
      		      }
      		      b.Other { |b|
      		         b.tag! :"E-MailAddress", @other_email
      		         b.ShipAlert @other_ship_alert ? 'true' : 'false'
      		         b.LanguageCode @other_language || 'EN' # FR also available
      		      } unless @other_email.nil?
      		   }
      		} unless @message.nil?
         }
		   
		   get_response @fedex_url
		   
		   begin
   		   response = Hash.new
   		   response[:image_url]       = REXML::XPath.first(@response, "//FDXEmailLabelReply/URL").text
   		   response[:image_userid]    = REXML::XPath.first(@response, "//FDXEmailLabelReply/UserID").text
   		   response[:image_password]  = REXML::XPath.first(@response, "//FDXEmailLabelReply/Password").text
   		   response[:tracking_number] = REXML::XPath.first(@response, "//FDXEmailLabelReply/Package/TrackingNumber").text
   		rescue
   		   raise ShippingError, get_error
   		end
		   
		   # allows for things like fedex.label.image
		   def response.method_missing(name, *args)
		      has_key?(name) ? self[name] : super
		   end
		   
		   f = Tempfile.new response.image_password
		   uri = URI.parse response.image_url
		   
		   http = Net::HTTP.new uri.host, uri.port
		   if uri.port == 443
		      http.use_ssl	= true
		      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
		   end
		   req = Net::HTTP::Get.new(uri.path)
		   req.basic_auth response.image_userid, response.image_password
		   res = http.request(req)
		   f << res.body
		   f.seek(0)
		   response[:image] = f

		   # don't allow people to edit the response
		   response.freeze
		end

      private

      def get_price #:nodoc:
         @required = [:zip, :sender_zip, :weight]
         @required += [:transaction_type, :fedex_account, :fedex_meter, :fedex_url]

         @transaction_type ||= 'rate_ground'
         @weight = (@weight.to_f*10).round/10.0

         @data = String.new
         b = Builder::XmlMarkup.new(:target => @data)
         b.instruct!
         b.FDXRateRequest('xmlns:api' => 'http://www.fedex.com/fsmapi', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xsi:noNamespaceSchemaLocation' => 'FDXRateRequest.xsd') { |b|
         	b.RequestHeader { |b|
         		b.AccountNumber @fedex_account
         		b.MeterNumber @fedex_meter
         		b.CarrierCode TransactionTypes[@transaction_type][1]
         	}
         	b.ShipDate @ship_date unless @ship_date.nil?
         	b.DropoffType @dropoff_type || 'REGULARPICKUP'
         	b.Service ServiceTypes[@service_type] || ServiceTypes['ground_service'] # default to ground service
         	b.Packaging PackageTypes[@packaging_type] || 'YOURPACKAGING'
         	b.WeightUnits @weight_units || 'LBS'
         	b.Weight @weight
         	b.OriginAddress { |b|
         		b.PostalCode @sender_zip
         		b.CountryCode @sender_country_code || "US"
         	}
         	b.DestinationAddress { |b|
         		b.PostalCode @zip
         		b.CountryCode @country || "US"
         	}
         	b.Payment { |b|
         		b.PayorType PaymentTypes[@pay_type] || 'SENDER'
         	}
         	b.PackageCount @package_total || '1'
         }

         get_response @fedex_url
      end
	
		def get_error
			return if @response.class != REXML::Document
			
			code = REXML::XPath.first(@response, "//Error/Code").text
			message = REXML::XPath.first(@response, "//Error/Message").text
			
			return "Error #{code}: #{message}"
		end

      # The following type hashes are to allow cross-api data retrieval
      
      ServiceTypes = {
         "priority" => "PRIORITYOVERNIGHT",
         "2day" => "FEDEX2DAY",
         "standard_overnight" => "STANDARDOVERNIGHT",
         "first_overnight" => "FIRSTOVERNIGHT",
         "express_saver" => "FEDEXEXPRESSSAVER",
         "1day_freight" => "FEDEX1DAYFREIGHT",
         "2day_freight" => "FEDEX2DAYFREIGHT",
         "3day_freight" => "FEDEX3DAYFREIGHT",
         "international_priority" => "INTERNATIONALPRIORITY",
         "international_economy" => "INTERNATIONALECONOMY",
         "international_first" => "INTERNATIONALFIRST",
         "international_priority_freight" => "INTERNATIONALPRIORITYFREIGHT",
         "international_economy_freight" => "INTERNATIONALECONOMYFREIGHT",
         "home_delivery" => "GROUNDHOMEDELIVERY",
         "ground_service" => "FEDEXGROUND",
         "international_ground_service" => "INTERNATIONALGROUND"
      }

		PackageTypes = {
			"fedex_envelope" => "FEDEXENVELOPE",
			"fedex_pak" => "FEDEXPAK",
			"fedex_box" => "FEDEXBOX",
			"fedex_tube" => "FEDEXTUBE",
			"fedex_10_kg_box" => "FEDEX10KGBOX",
			"fedex_25_kg_box" => "FEDEX25KGBOX",
			"your_packaging" => "YOURPACKAGING"
		}
		
		DropoffTypes = {
			'regular_pickup' => 'REGULARPICKUP',
			'request_courier' => 'REQUESTCOURIER',
			'dropbox' => 'DROPBOX',
			'business_service_center' => 'BUSINESSSERVICECENTER',
			'station' => 'STATION'
		}
		
		PaymentTypes = {
			'sender' => 'SENDER',
			'recipient' => 'RECIPIENT',
			'third_party' => 'THIRDPARTY',
			'collect' => 'COLLECT'
 		}

      
      TransactionTypes = {
         'rate_ground'           =>  ['022','FDXG'],
         'rate_express'          =>  ['022','FDXE'],
         'rate_services'         =>  ['025',''],
         'ship_ground'           =>  ['021','FDXG'],
         'ship_express'          =>  ['021','FDXE'],
         'cancel_express'        =>  ['023','FDXE'],
         'cancel_ground'         =>  ['023','FDXG'],
         'close_ground'          =>  ['007','FDXG'],
         'service_available'     =>  ['019','FDXE'],
         'fedex_locater'         =>  ['410',''],
         'subscribe'             =>  ['211',''],
         'sig_proof_delivery'    =>  ['402',''],
         'track'                 =>  ['405',''],
         'ref_track'             =>  ['403','']
      }
   end
end