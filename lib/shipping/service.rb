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
        initialize_for_ups(xml)
      when 'usps'
        
      end
    end
    
    private
    def initialize_for_fedex(xml)
      begin
        @carrier = 'fedex'
        @eta = REXML::XPath.first(xml, "DeliveryDate").text unless REXML::XPath.match(xml, "DeliveryDate").empty?
        @type = REXML::XPath.first(xml, "Service").text
        @discount_price = REXML::XPath.first(xml, "EstimatedCharges/DiscountedCharges/BaseCharge").text
        @price = REXML::XPath.first(xml, "EstimatedCharges/DiscountedCharges/NetCharge").text
      rescue Exception => e
        puts e.message
      end
    end
  
    def initialize_for_ups(xml)
      
    end
  
  
  end
  
end