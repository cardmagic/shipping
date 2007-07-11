require File.dirname(__FILE__) + '/../test_helper'
class UpsTest < Test::Unit::TestCase
	def setup
		@ship = Shipping::UPS.new(
			:zip => 97202,
			:state => "OR",
			:sender_zip => 10001,
			:sender_state => "New York",
			:weight => 2
		)
		
		# use demo environment for tests
		@ship.ups_url = 'https://wwwcie.ups.com/ups.app/xml'
	end

	def test_price
		# price is subject to account details, it seems?
		assert_in_delta 5.80, @ship.price, 1
	end
	
	def test_valid_address
		assert !@ship.valid_address?
		@ship.city = "Portland"
		assert @ship.valid_address?
	end
	
	def test_label
		@ship.name = "Package Receiver"
		@ship.company = "Package Receiver Company"
		@ship.phone = "555-555-5555"
		@ship.email = "lucas@rufy.com"
		@ship.address = "Some address"
		@ship.city = "Portland"
	
		@ship.sender_name = "Package Sender"
		@ship.sender_company = "Package Sender Company"
		@ship.sender_phone = "333-333-3333"
		@ship.sender_email = "john@doe.com"
		@ship.sender_address = "Ok old address"
		@ship.sender_city = "New York"
		
		assert_nothing_raised { @label = @ship.label }
		assert_not_nil @label.tracking_number
		assert_not_nil @label.image.path
		#assert_equal `file -i -b #{@label.image.path}`, "image/gif\n"
	end
	
	def test_void
		@ship.name = "Package Receiver"
		@ship.company = "Package Receiver Company"
		@ship.phone = "555-555-5555"
		@ship.email = "lucas@rufy.com"
		@ship.address = "Some address"
		@ship.city = "Portland"
	
		@ship.sender_name = "Package Sender"
		@ship.sender_company = "Package Sender Company"
		@ship.sender_phone = "333-333-3333"
		@ship.sender_email = "john@doe.com"
		@ship.sender_address = "Ok old address"
		@ship.sender_city = "New York"
		
		assert_nothing_raised { @label = @ship.label }
		
		assert @ship.void(@label.tracking_number)
	end
	
	def test_void_fail
		# Tracking number from certification process; Time for voiding has expired 
		assert_raise(Shipping::ShippingError) { @ship.void('1Z12345E0392508488') }
	end
end