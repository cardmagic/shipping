require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'

PKG_VERSION = "1.0.0"

PKG_FILES = FileList[
    "lib/**/*", "bin/*", "test/**/*", "[A-Z]*", "Rakefile", "doc/**/*"
]

desc "Default Task"
task :default => [ :test ]

# Run the unit tests
desc "Run all unit tests"
Rake::TestTask.new("test") { |t|
  t.libs << "lib"
  t.pattern = 'test/*/*_test.rb'
  t.verbose = true
}

# Make a console, useful when working on tests
desc "Generate a test console"
task :console do
   verbose( false ) { sh "irb -I lib/ -r 'shipping'" }
end

# Genereate the RDoc documentation
desc "Create documentation"
Rake::RDocTask.new("doc") { |rdoc|
  rdoc.title = "Ruby Shipping - UPS, FedEx, USPS"
  rdoc.rdoc_dir = 'doc'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
}

# Genereate the package
spec = Gem::Specification.new do |s|

  #### Basic information.

  s.name = 'shipping'
  s.version = PKG_VERSION
  s.summary = <<-EOF
   A general shipping module to find out the shipping prices via UPS or FedEx.
  EOF
  s.description = <<-EOF
   A general shipping module to find out the shipping prices via UPS or FedEx.
  EOF

  #### Which files are to be included in this gem?  Everything!  (Except CVS directories.)

  s.files = PKG_FILES

  #### Load-time details: library and application (you will need one or both).

  s.add_dependency('builder', '>= 1.2.0')
  s.requirements << "An xml-builder library."

  s.require_path = 'lib'
  s.autorequire = 'shipping'

  #### Documentation and testing.

  s.has_rdoc = true

  #### Author and project details.

  s.author = "Lucas Carlson"
  s.email = "lucas@rufy.com"
  s.homepage = "http://shipping.rufy.com/"
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

desc "Report code statistics (KLOCs, etc) from the application"
task :stats do
  require 'code_statistics'
  CodeStatistics.new(
    ["Library", "lib"],
    ["Units", "test"]
  ).to_s
end

desc "Publish new documentation"
task :publish do
   `ssh rufy update-shipping-doc`
   `scp pkg/shipping-1.0.0.* rufy:www/shipping.rufy.com/docs/`
    Rake::RubyForgePublisher.new('shipping', 'cardmagic').upload
end
