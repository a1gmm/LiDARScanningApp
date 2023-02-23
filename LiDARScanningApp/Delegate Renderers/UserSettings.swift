#if !os(macOS)
import Metal
import ARKit

@usableFromInline
final class UserSettings: DelegateRenderer {
    unowned let renderer: MainRenderer
    
    var savingSettings = false
    var shouldSaveSettings = false
    var storedSettings: StoredSettings
  var lensDistortionSettings: LensDistortionSettings
    
    var cameraMeasurements: CameraMeasurements!
    
    required public init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
      self.storedSettings = .defaultSettings
      self.lensDistortionSettings = .defaultSettings
        cameraMeasurements = CameraMeasurements(userSettings: self, library: library)
    }
}

protocol DelegateUserSettings {
    var userSettings: UserSettings { get }
    init(userSettings: UserSettings, library: MTLLibrary)
}

extension DelegateUserSettings {
    var renderer: MainRenderer { userSettings.renderer }
    var device: MTLDevice { userSettings.device }
    var renderIndex: Int { userSettings.renderIndex }
    
    var cameraMeasurements: CameraMeasurements { userSettings.cameraMeasurements }
}

extension UserSettings {
    
  struct StoredSettings: Equatable {
    var isFirstAppLaunch: Bool
    
    var usingHeadsetMode: Bool
    var renderingViewSeparator: Bool
    var interfaceScale: Float
    
    var canHideSettingsIcon: Bool
    var usingHandForSelection: Bool
    var showingHandPosition: Bool
    
    var allowingSceneReconstruction: Bool
    var allowingHandReconstruction: Bool
    var customSettings: [String : String]
    
    static let defaultSettings = Self(
      isFirstAppLaunch: true,
      
      usingHeadsetMode: false,
      renderingViewSeparator: true,
      interfaceScale: 1.0,
      
      canHideSettingsIcon: false,
      usingHandForSelection: true,
      showingHandPosition: false,
      
      allowingSceneReconstruction: true,
      allowingHandReconstruction: true,
      customSettings: [:]
    )
  }
  
  struct LensDistortionSettings: Codable, Equatable {
          var headsetFOV: Double
          var viewportDiameter: Double
          
          enum CaseSize: Int, Codable {
              case none = 0
              case small = 1
              case large = 2
              
              var thickness: Double {
                  switch self {
                  case .none:  return 0
                  case .small: return 0.001 * 1.5
                  case .large: return 0.001 * 5.0
                  }
              }
              
              var protrusionDepth: Double {
                  switch self {
                  case .none:  return 0
                  case .small: return 0.001 * 1.0
                  case .large: return 0.001 * 3.5
                  }
              }
          }
          
          var caseSize: CaseSize
          var caseThickness: Double { caseSize.thickness }
          var caseProtrusionDepth: Double { caseSize.protrusionDepth }
          
          var eyeOffsetX: Double
          var eyeOffsetY: Double
          var eyeOffsetZ: Double
          
          var k1_green: Float
          var k2_green: Float
          var k1_proportions: simd_float2
         
          var k2_proportions: simd_float2 {
              let k_sum = k1_green + k2_green
            let remaining_k = fma(simd_float2(repeating: k1_green),
                                  -k1_proportions,
                                  simd_float2(repeating: k_sum))
              return remaining_k * Float(simd_fast_recip(Double(k2_green)))
          }
          
          static let defaultSettings = Self(
              headsetFOV: 80.0,
              viewportDiameter: 0.001 * 58,
              
              caseSize: .small,
              eyeOffsetX: 0.001 * 31,
              eyeOffsetY: 0.001 * 34,
              eyeOffsetZ: 0.001 * 77,
              
              k1_green: 0.135,
              k2_green: 0.185,
              k1_proportions: [0.70, 1.31]
          )
          
          func eyePositionMatches(_ other: Self) -> Bool {
              caseThickness == other.caseThickness &&
              caseProtrusionDepth == other.caseProtrusionDepth &&
                  
              eyeOffsetX == other.eyeOffsetX &&
              eyeOffsetY == other.eyeOffsetY &&
              eyeOffsetZ == other.eyeOffsetZ
          }
          
          func viewportMatches(_ other: Self) -> Bool {
              eyePositionMatches(other) &&
              viewportDiameter == other.viewportDiameter
          }
          
          func intermediateTextureMatches(_ other: Self) -> Bool {
              headsetFOV == other.headsetFOV &&
              viewportDiameter == other.viewportDiameter &&
                  
              k1_green == other.k1_green && k2_green == other.k2_green &&
              k1_proportions == other.k1_proportions
          }
      }
}
#endif
