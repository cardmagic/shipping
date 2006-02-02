require File.dirname(__FILE__) + '/../test_helper'
class UpsTest < Test::Unit::TestCase
	def setup
		@ship = Shipping::UPS.new :zip => 97202, :state => "OR", :sender_zip => 10001, :sender_state => "New York", :weight => 2
	end
	
	def test_price
	   assert_equal 8.82, @ship.price
	end
	
	def test_valid_address
	   assert !@ship.valid_address?
	   @ship.city = "Portland"
	   assert @ship.valid_address?
	end
end