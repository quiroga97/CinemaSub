Pod::Spec.new do |s|
  s.name           = 'CinemaNative'
  s.version        = '0.1.0'
  s.summary        = 'Pipeline nativo CinemaSubs'
  s.description    = 'Captura de audio, transcripción SpeechAnalyzer, traducción on-device y scheduler de subtítulos.'

  s.author         = ''
  s.homepage       = 'https://github.com/cinemasubs/cinema-native'
  s.license        = 'UNLICENSED'
  s.source         = { git: '' }

  s.platforms      = {
    ios: '26.0'
  }

  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.swift_version = '5.9'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }

  s.source_files = "**/*.{h,m,mm,cpp,swift,hpp,c}"
end
