# ios/hdr_converter.podspec
Pod::Spec.new do |s|
  s.name         = "hdr_converter"
  s.version      = "1.0.0"
  s.summary      = "HDR↔SDR video converter native library"
  s.homepage     = "https://github.com/Dremous/hdr2sdr"
  s.license      = { :type => "MIT" }
  s.author       = "Dremous"
  s.platform     = :ios, "15.0"
  s.source       = { :path => "." }
  s.vendored_libraries = "libhdr_converter.a"
  s.static_framework = true
end
