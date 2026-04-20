require_relative "lib/workflows/version"

Gem::Specification.new do |spec|
  spec.name        = "workflows"
  spec.version     = Workflows::VERSION
  spec.authors     = ["Ye Lin Aung"]
  spec.email       = ["noreply@example.com"]
  spec.homepage    = "https://github.com/yelinaung/workflows"
  spec.summary     = "Unified YAML workflow authoring: one file -> tour + system test + video."
  spec.description = "Authors each workflow as one YAML file and projects it into a driver.js tour, a Minitest system test, and an MP4 video with WebVTT subtitles. Built on the tutorials gem's selector convention. Shared between LMS and school-os."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["allowed_push_host"] = "none"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.1.0"
  spec.add_dependency "playwright-ruby-client", "~> 1.50"
end
