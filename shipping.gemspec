Gem::Specification.new do |s|
  s.name = "contacts"
  s.version = "1.6.0"
  s.date = "2008-11-25"
  s.summary = "A general shipping module to find out the shipping prices via UPS or FedEx"
  s.email = "lucas@rufy.com"
  s.homepage = "http://github.com/cardmagic/shipping"
  s.description = "A general shipping module to find out the shipping prices via UPS or FedEx"
  s.has_rdoc = false
  s.authors = ["Lucas Carlson", "Jimmy Baker"]
  s.files = ["LICENSE", "Rakefile", "README", "lib/shipping/base.rb", "lib/shipping/fedex.rb", "lib/shipping/ups.rb"]
  s.add_dependency("builder", [">= 1.2.0"])
end
