
Pod::Spec.new do |s|

  s.name         = "T21RealmStoreSwift"
  s.version      = "1.0.0"
  s.summary      = "T21RealmStoreSwift is a helper class to work with Realm. It offers an easy way using blocks to perform reads and writes on a background thread and then fetching the results in the main thread using the private keys."
  s.author    = "Eloi Guzman Ceron"
  s.platform     = :ios
  s.ios.deployment_target = "8.0"
  s.source       = { :git => "https://github.com/worldline-spain/T21RealmStoreSwift.git", :tag => "1.0.0" }
  s.source_files  = "Classes", "src/**/*.{swift}"
  s.framework  = "Foundation"
  s.requires_arc = true
  s.dependency "RealmSwift", "~>2.2.0"
  s.dependency "T21SortingDescriptorSwift", "~>1.0.0"

end
