module Shipping
  
  class Service
    
    attr_accessor :price, :eta, :type, :carrier, :discount_price, :number_of_packages
    
    def initialize(options={})
      options.each do |k, v|
        instance_variable_set("@#{k}", v)
      end
    end
    
    def initialize(carrier, xml)
      case carrier
      when 'fedex'
        initialize_for_fedex(xml)
      when 'ups'
        
      when 'usps'
        
      end
    end
    
    private
    def initialize_for_fedex(xml)
      begin
        @carrier = 'fedex'
        #@eta = REXML::XPath.first(xml, "//DeliveryDate").text
        @type = REXML::XPath.first(xml, "//Service").text
        @discount_price = REXML::XPath.first(xml, "//DiscountedCharges/BaseCharge").text
        @price = REXML::XPath.first(xml, "//DiscountedCharges/NetCharge").text
      rescue ShippingError => e
        puts e.message
      end
    end
  end
  
end