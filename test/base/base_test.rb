require File.dirname(__FILE__) + '/../test_helper'
class BaseTest < Test::Unit::TestCase
	def setup
		@ship = Shipping::Base.new :zip => 97202, :state => "OR", :sender_zip => 10001, :sender_state => "New York", :weight => 2
	end
	
	def test_ups
	   ups = @ship.ups
		assert_instance_of Shipping::UPS, ups
		assert_equal ups.zip, @ship.zip
	end

	def test_fedex
	   fedex = @ship.fedex
		assert_instance_of Shipping::FedEx, fedex
		assert_equal fedex.zip, @ship.zip
	end
end