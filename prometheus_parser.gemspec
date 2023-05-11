Gem::Specification.new do |s|
  s.name        = "prometheus_parser"
  s.version     = "0.2.2"
  s.summary     = "Parse prometheus metrics"
  s.authors     = ["Magnus Landerblom"]
  s.email       = "mange@84codes.com"
  s.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  s.homepage =
    "https://rubygems.org/gems/prometheus_parser"
  s.license = "MIT"
end
