require File.dirname(__FILE__) + '/../test_helper'
class FedExTest < Test::Unit::TestCase
	def setup
		@ship = Shipping::FedEx.new :zip => 97202, :state => "OR", :sender_zip => 10001, :sender_state => "New York", :weight => 2
	end
	
	def test_price
	   assert_in_delta 5.5, @ship.price, 0.5
	end
	
	def test_base_price
	   assert_in_delta 5.3, @ship.base_price, 0.5
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
	   
	   response = nil
#	   assert_nothing_raised { response = @ship.label }
#	   assert_equal 'PackageSen', response.image_userid
	end
end
