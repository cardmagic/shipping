class Object
 def blank?
   if respond_to? :empty?
     empty?
   elsif respond_to? :zero?
     zero?
   else
     !self
   end
 end
end