# Author::    Lucas Carlson  (mailto:lucas@rufy.com)
# Copyright:: Copyright (c) 2005 Lucas Carlson
# License::   LGPL

module Shipping

	class UPS < Base

		API_VERSION = "1.0001"

		# For current implementation (XML) docs, see http://www.ups.com/gec/techdocs/pdf/dtk_RateXML_V1.zip
		def price
			@required = [:zip, :country, :sender_zip, :weight]
			@required += [:ups_license_number, :ups_user, :ups_password]

			@insured_value ||= 0
			@country ||= 'US'
			@sender_country ||= 'US'
			@service_type ||= 'ground' # default to UPS ground
			@ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
			@ups_tool = '/Rate'

			state = STATES.has_value?(@state.downcase) ? STATES.index(@state.downcase).upcase : @state.upcase unless @state.blank?
			sender_state = STATES.has_value?(@sender_state.downcase) ? STATES.index(@sender_state.downcase).upcase : @sender_state.upcase unless @sender_state.blank?

			# With UPS need to send two xmls
			# First one to authenticate, second for the request
			b = request_access
			b.instruct!

			b.RatingServiceSelectionRequest { |b| 
				b.Request { |b|
					b.TransactionReference { |b|
						b.CustomerContext 'Rating and Service'
						b.XpciVersion API_VERSION
					}
					b.RequestAction 'Rate'
				}
				b.CustomerClassification { |b|
					b.Code CustomerTypes[@customer_type] || '01'
				}
				b.PickupType { |b|
					b.Code @pickup_type || '01'
				}
				b.Shipment { |b|
					b.Shipper { |b|
						b.Address { |b|
							b.PostalCode @sender_zip
							b.CountryCode @sender_country unless @sender_country.blank?
							b.City @sender_city unless @sender_city.blank?
							b.StateProvinceCode sender_state unless sender_state.blank?
						}
					}
					b.ShipTo { |b|
						b.Address { |b|
							b.PostalCode @zip
							b.CountryCode @country unless @country.blank?
							b.City @city unless @city.blank?
							b.StateProvinceCode state unless state.blank?
						}
					}
					b.Service { |b| # The service code
						b.Code ServiceTypes[@service_type] || '03' # defaults to ground
					}
					b.Package { |b| # Package Details					
						b.PackagingType { |b|
							b.Code PackageTypes[@packaging_type] || '02' # defaults to 'your packaging'
							b.Description 'Package'
						}
						b.Description 'Rate Shopping'
						b.PackageWeight { |b|
							b.Weight @weight
							b.UnitOfMeasurement { |b|
								b.Code @weight_units || 'LBS' # or KGS
							}
						}
						b.Dimensions { |b|
							b.UnitOfMeasurement { |b|
								b.Code @measure_units || 'IN'
							}
							b.Length @measure_length || 0
							b.Width @measure_width || 0
							b.Height @measure_height || 0
						}
						b.PackageServiceOptions { |b|
							b.InsuredValue { |b|
								b.CurrencyCode @currency_code || 'US'
								b.MonetaryValue @insured_value
							}
						}
					}
				}
			}

			get_response @ups_url + @ups_tool

			return REXML::XPath.first(@response, "//RatingServiceSelectionResponse/RatedShipment/TransportationCharges/MonetaryValue").text.to_f
		rescue
			raise ShippingError, get_error
		end

		# See http://www.ups.com/gec/techdocs/pdf/dtk_AddrValidateXML_V1.zip for API info
		def valid_address?( delta = 1.0 )
			@required = [:ups_license_number, :ups_user, :ups_password]         
			@ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
			@ups_tool = '/AV'
			
			state = nil
			if @state:
				state = STATES.has_value?(@state.downcase) ? STATES.index(@state.downcase) : @state
			end
			
			b = request_access
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

			get_response @ups_url + @ups_tool

			if REXML::XPath.first(@response, "//AddressValidationResponse/Response/ResponseStatusCode").text == "1" && REXML::XPath.first(@response, "//AddressValidationResponse/AddressValidationResult/Quality").text.to_f >= delta
				return true
			else
				return false
			end
			rescue ShippingError
				raise ShippingError, get_error
		end

		# See Ship-WW-XML.pdf for API info
		# @image_type = [GIF|EPL]	
		def label
			@required = [:ups_license_number, :ups_shipper_number, :ups_user, :ups_password]
			@required +=  [:phone, :email, :company, :address, :city, :state, :zip]
			@required += [:sender_phone, :sender_email, :sender_company, :sender_address, :sender_city, :sender_state, :sender_zip ]
			@ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
			@ups_tool = '/ShipConfirm'
			
			state = STATES.has_value?(@state.downcase) ? STATES.index(@state.downcase).upcase : @state.upcase unless @state.blank?
			sender_state = STATES.has_value?(@sender_state.downcase) ? STATES.index(@sender_state.downcase).upcase : @sender_state.upcase unless @sender_state.blank?
			
			# make ConfirmRequest and get Confirm Response
			b = request_access
			b.instruct!

			b.ShipmentConfirmRequest { |b|
				b.Request { |b|
					b.RequestAction "ShipConfirm"
					b.RequestOption "nonvalidate"
					b.TransactionReference { |b|
						b.CustomerContext "#{@city}, #{state} #{@zip}"
						b.XpciVersion API_VERSION
					}
				}
				b.Shipment { |b|
					b.Shipper { |b|
						b.ShipperNumber @ups_shipper_number
						b.Name @sender_name
						b.Address { |b|
							b.AddressLine1 @sender_address unless @sender_address.blank?
							b.PostalCode @sender_zip
							b.CountryCode @sender_country unless @sender_country.blank?
							b.City @sender_city unless @sender_city.blank?
							b.StateProvinceCode sender_state unless sender_state.blank?
						}
					}
					b.ShipFrom { |b|
						b.CompanyName @sender_company
						b.Address { |b|
							b.AddressLine1 @sender_address unless @sender_address.blank?
							b.PostalCode @sender_zip
							b.CountryCode @sender_country unless @sender_country.blank?
							b.City @sender_city unless @sender_city.blank?
							b.StateProvinceCode sender_state unless sender_state.blank?
						}
					}
					b.ShipTo { |b|
						b.CompanyName @company
						b.Address { |b|
							b.AddressLine1 @address unless @address.blank?
							b.PostalCode @zip
							b.CountryCode @country unless @country.blank?
							b.City @city unless @city.blank?
							b.StateProvinceCode state unless state.blank?
						}
					}
					b.PaymentInformation { |b|
						pay_type = PaymentTypes[@pay_type] || 'Prepaid'
						
						if pay_type == 'Prepaid'
							b.Prepaid { |b|
								b.BillShipper { |b|
									b.AccountNumber @ups_shipper_number
								}
							}
						elsif pay_type == 'BillThirdParty'
							b.BillThirdParty { |b|
								b.BillThirdPartyShipper { |b|
									b.AccountNumber @billing_account
									b.ThirdParty { |b|
										b.Address { |b|
											b.PostalCode @billing_zip
											b.CountryCode @billing_country
										}
									}
								}
							}
						elsif pay_type == 'FreightCollect'
							b.FreightCollect { |b|
								b.BillReceiver { |b|
									b.AccountNumber @billing_account
								}
							}
						else
							raise ShippingError, "Valid pay_types are 'prepaid', 'bill_third_party', or 'freight_collect'."
						end
					}
					b.Service { |b| # The service code
						b.Code ServiceTypes[@service_type] || '03' # defaults to ground
					}
					b.Package { |b| # Package Details					
						b.PackagingType { |b|
							b.Code PackageTypes[@packaging_type] || '02' # defaults to 'your packaging'
							b.Description 'Package'
						}
						b.PackageWeight { |b|
							b.Weight @weight
							b.UnitOfMeasurement { |b|
								b.Code @weight_units || 'LBS' # or KGS
							}
						}
						b.Dimensions { |b|
							b.UnitOfMeasurement { |b|
								b.Code @measure_units || 'IN'
							}
							b.Length @measure_length || 0
							b.Width @measure_width || 0
							b.Height @measure_height || 0
						} if @measure_length || @measure_width || @measure_height
						b.PackageServiceOptions { |b|
							b.InsuredValue { |b|
								b.CurrencyCode @currency_code || 'US'
								b.MonetaryValue @insured_value
							}
						} if @insured_value
					}
				}
				b.LabelSpecification { |b|
					image_type = @image_type || 'GIF' # default to GIF
					
					b.LabelPrintMethod { |b|
						b.Code image_type
					}
					if image_type == 'GIF'
						b.HTTPUserAgent 'Mozilla/5.0'
						b.LabelImageFormat { |b|
							b.Code 'GIF'
						}
					elsif image_type == 'EPL'
						b.LabelStockSize { |b|
							b.Height '4'
							b.Width '6'
						}
					else
						raise ShippingError, "Valid image_types are 'EPL' or 'GIF'."
					end
				}
			}
			
			# get ConfirmResponse
			get_response @ups_url + @ups_tool
			begin
				shipment_digest = REXML::XPath.first(@response, '//ShipmentConfirmResponse/ShipmentDigest').text
			rescue
				raise ShippingError, get_error
			end

			# make AcceptRequest and get AcceptResponse
			@ups_tool = '/ShipAccept'
			
			b = request_access
			b.instruct!

			b.ShipmentAcceptRequest { |b|
				b.Request { |b|
					b.RequestAction "ShipAccept"
					b.TransactionReference { |b|
						b.CustomerContext "#{@city}, #{state} #{@zip}"
						b.XpciVersion API_VERSION
					}
				}
				b.ShipmentDigest shipment_digest
			}
			
			# get AcceptResponse
			get_response @ups_url + @ups_tool
			
			begin  
				response = Hash.new       
				response[:tracking_number] = REXML::XPath.first(@response, "//ShipmentAcceptResponse/ShipmentResults/PackageResults/TrackingNumber").text
				response[:encoded_image] = REXML::XPath.first(@response, "//ShipmentAcceptResponse/ShipmentResults/PackageResults/LabelImage/GraphicImage").text
				response[:image] = Tempfile.new("shipping_label")
				response[:image].write Base64.decode64( response[:encoded_image] )
				response[:image].rewind
			rescue
				raise ShippingError, get_error
			end

			# allows for things like fedex.label.url
			def response.method_missing(name, *args)
				has_key?(name) ? self[name] : super
			end
			
			# don't allow people to edit the response
			response.freeze
		end
		
		def void(tracking_number)
			@required = [:ups_license_number, :ups_shipper_number, :ups_user, :ups_password]
			@ups_url ||= "https://wwwcie.ups.com/ups.app/xml"
			@ups_tool = '/Void'

			# make ConfirmRequest and get Confirm Response
			b = request_access
			b.instruct!

			b.VoidShipmentRequest { |b|
				b.Request { |b|
					b.RequestAction "Void"
					b.TransactionReference { |b|
						b.CustomerContext "Void #{@tracking_number}"
						b.XpciVersion API_VERSION
					}
				}
				b.ShipmentIdentificationNumber tracking_number
			}
			
			# get VoidResponse
			get_response @ups_url + @ups_tool
			status = REXML::XPath.first(@response, '//VoidShipmentResponse/Response/ResponseStatusCode').text
			raise ShippingError, get_error if status == '0'
			return true if status == '1'
		end

		private

		def request_access
			@data = String.new
			b = Builder::XmlMarkup.new :target => @data

			b.instruct!
			b.AccessRequest {|b|
				b.AccessLicenseNumber @ups_license_number
				b.UserId @ups_user
				b.Password @ups_password
			}
			return b
		end
		
		def get_error
			return if @response.class != REXML::Document

			error = REXML::XPath.first(@response, '//*/Response/Error')
			return if !error
			
			severity = REXML::XPath.first(error, '//ErrorSeverity').text
			code = REXML::XPath.first(error, '//ErrorCode').text
			description = REXML::XPath.first(error, '//ErrorDescription').text
			begin
				location = REXML::XPath.first(error, '//ErrorLocation/ErrorLocationElementName').text
			rescue
				location = 'unknown'
			end
			return "#{severity} Error ##{code} @ #{location}: #{description}"
		end

		# The following type hashes are to allow cross-api data retrieval
		PackageTypes = {
			"ups_envelope" => "01",
			"your_packaging" => "02",
			"ups_tube" => "03",
			"ups_pak" => "04",
			"ups_box" => "21",
			"fedex_25_kg_box" => "24",
			"fedex_10_kg_box" => "25"
		}

		ServiceTypes = {
			"next_day" => "01",
			"2day" => "02",
			"ground_service" => "03",
			"worldwide_express" => "07",
			"worldwide_expedited" => "08",
			"standard" => "11",
			"3day" => "12",
			"next_day_saver" => "13",
			"next_day_early" => "14",
			"worldwide_express_plus" => "54",
			"2day_early" => "59"
		}

		PickupTypes = {
			'daily_pickup' => '01',
			'customer_counter' => '03',
			'one_time_pickup' => '06',
			'on_call' => '07',
			'suggested_retail_rates' => '11',
			'letter_center' => '19',
			'air_service_center' => '20'
		}

		CustomerTypes = {
			'wholesale' => '01',
			'ocassional' => '02',
			'retail' => '04'
		}
		
		PaymentTypes = {
			'prepaid' => 'Prepaid',
			'consignee' => 'Consignee', # TODO: Implement
			'bill_third_party' => 'BillThirdParty',
			'freight_collect' => 'FreightCollect'
		}
	end
end
