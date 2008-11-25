require File.dirname(__FILE__) + '/../test_helper'
class FedExTest < Test::Unit::TestCase
	def setup
		@ship = Shipping::FedEx.new(
			:zip => 97202,
			:state => "OR",
			:sender_zip => 10001,
			:sender_state => "New York",
			:weight => 2
		)
		
		# use demo environment for tests
		@ship.fedex_url = 'https://gatewaybeta.fedex.com/GatewayDC'
	end

	def test_price
		assert_in_delta 5.80, @ship.price, 1
	end
	
	def test_discount_price
		assert_in_delta 5.80, @ship.discount_price, 1
		assert @ship.discount_price < @ship.price
	end
	
	def test_fails
		ship = Shipping::FedEx.new :zip => 97202, :weight => 2
		assert_raise(Shipping::ShippingError) { ship.price }
	end
	
	def test_label
		@ship.name = "Package Receiver"
		@ship.phone = "555-555-5555"
		@ship.email = "lucas@rufy.com"
		@ship.address = "Some address"
		@ship.city = "Portland"
	
		@ship.sender_name = "Package Sender"
		@ship.sender_phone = "333-333-3333"
		@ship.sender_email = "john@doe.com"
		@ship.sender_address = "Ok old address"
		@ship.sender_city = "New York"
		
		assert_nothing_raised { @label = @ship.label }
		assert_not_nil @label.tracking_number
		assert_not_nil @label.image.path
		#assert_equal `file -i -b #{@label.image.path}`, "image/png\n"
	end
	
	def test_void
		@ship.name = "Package Receiver"
		@ship.phone = "555-555-5555"
		@ship.email = "lucas@rufy.com"
		@ship.address = "Some address"
		@ship.city = "Portland"
	
		@ship.sender_name = "Package Sender"
		@ship.sender_phone = "333-333-3333"
		@ship.sender_email = "john@doe.com"
		@ship.sender_address = "Ok old address"
		@ship.sender_city = "New York"
				
		assert_nothing_raised { @label = @ship.label }
		
		assert @ship.void(@label.tracking_number)
	end
	
	def test_available_services
	  @ship.name = "Package Receiver"
		@ship.phone = "555-555-5555"
		@ship.email = "lucas@rufy.com"
		@ship.address = "Some address"
		@ship.city = "Portland"
	
		@ship.sender_name = "Package Sender"
		@ship.sender_phone = "333-333-3333"
		@ship.sender_email = "john@doe.com"
		@ship.sender_address = "Ok old address"
		@ship.sender_city = "New York"
		
		assert_nothing_raised { @available_services = @ship.available_services }
		assert_not_nil @available_services
	end
	
	def test_void_fail
		# made up tracking number
		assert_raise(Shipping::ShippingError) { @ship.void('470012923511666') }
	end
end