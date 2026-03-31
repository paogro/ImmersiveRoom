//
//  ImmersiveView.swift
//  ImmersiveRoom
//
//  Created by Paolo Grommes on 31.03.26.
//

import SwiftUI
import RealityKit
import RealityKitContent
import CoreGraphics

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var themen: [Thema] = []
    @State private var status = ""
    
    private let themenService = ThemenService()
    
    var body: some View {
        RealityView { content, attachments in
            // Skybox mit Sternenhimmel-Textur
            let skyboxTexture = generateSkyboxTexture(width: 2048, height: 1024)
            
            var material = UnlitMaterial()
            if let texture = skyboxTexture {
                material.color = .init(texture: .init(texture))
            } else {
                material.color = .init(tint: .black)
            }
            
            let skybox = ModelEntity(
                mesh: .generateSphere(radius: 50),
                materials: [material]
            )
            skybox.scale = SIMD3<Float>(x: -1, y: 1, z: 1)
            skybox.position = SIMD3<Float>(0, 0, 0)
            content.add(skybox)
            
            // UI-Panel vor dem Nutzer platzieren
            if let panel = attachments.entity(for: "mainPanel") {
                panel.position = SIMD3<Float>(0, 1.5, -2)
                content.add(panel)
            }
        } attachments: {
            Attachment(id: "mainPanel") {
                VStack(spacing: 20) {
                    if appModel.showThemen {
                        Text("Wissensraum")
                            .font(.extraLargeTitle)
                            .foregroundColor(.white)
                        
                        Text(status)
                            .foregroundColor(.gray)
                        
                        ForEach(themen) { thema in
                            Text("📦 \(thema.name) (Level \(thema.level))")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial)
                                .cornerRadius(16)
                        }
                        
                        Button("Zurück") {
                            withAnimation {
                                appModel.showThemen = false
                            }
                        }
                        .padding(.top, 20)
                    } else {
                        Button("Start Experience") {
                            withAnimation {
                                appModel.showThemen = true
                            }
                        }
                        .font(.title)
                        .padding()
                    }
                }
                .padding(40)
            }
        }
        .task {
            await ladeHauptkategorien()
        }
    }
    
    // MARK: - Skybox-Textur erzeugen
    
    func generateSkyboxTexture(width: Int, height: Int) -> TextureResource? {
        let w = width
        let h = height
        let horizonY = Float(h) * 0.56
        
        let skyTop = SIMD3<Float>(4, 6, 14)
        let skyMid = SIMD3<Float>(11, 16, 32)
        let skyBot = SIMD3<Float>(16, 23, 42)
        let gndTop = SIMD3<Float>(12, 20, 34)
        let gndBot = SIMD3<Float>(26, 37, 64)
        let glowColor = SIMD3<Float>(80, 160, 255)
        
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        
        for y in 0..<h {
            let fy = Float(y)
            for x in 0..<w {
                var r: Float
                var g: Float
                var b: Float
                
                if fy < horizonY {
                    let t = fy / horizonY
                    if t < 0.65 {
                        let localT = t / 0.65
                        r = mix(skyTop.x, skyMid.x, localT)
                        g = mix(skyTop.y, skyMid.y, localT)
                        b = mix(skyTop.z, skyMid.z, localT)
                    } else {
                        let localT = (t - 0.65) / 0.35
                        r = mix(skyMid.x, skyBot.x, localT)
                        g = mix(skyMid.y, skyBot.y, localT)
                        b = mix(skyMid.z, skyBot.z, localT)
                    }
                } else {
                    let t = (fy - horizonY) / (Float(h) - horizonY)
                    r = mix(gndTop.x, gndBot.x, t)
                    g = mix(gndTop.y, gndBot.y, t)
                    b = mix(gndTop.z, gndBot.z, t)
                }
                
                let distToHorizon = abs(fy - horizonY)
                let glowStrength = max(0, 1.0 - distToHorizon / 60.0) * 0.3
                r += glowColor.x * glowStrength
                g += glowColor.y * glowStrength
                b += glowColor.z * glowStrength
                
                if fy < horizonY * 0.9 {
                    let hash = sinHash(Float(x) * 127.1 + Float(y) * 311.7)
                    if hash > 0.997 {
                        let brightness: Float = 150 + hash * 105
                        r = brightness
                        g = brightness
                        b = brightness
                    }
                }
                
                let i = (y * w + x) * 4
                pixels[i]     = UInt8(min(255, max(0, r)))
                pixels[i + 1] = UInt8(min(255, max(0, g)))
                pixels[i + 2] = UInt8(min(255, max(0, b)))
                pixels[i + 3] = 255
            }
        }
        
        // CGImage erstellen
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: w,
                height: h,
                bitsPerComponent: 8,
                bytesPerRow: w * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let cgImage = context.makeImage() else {
            return nil
        }
        
        // TextureResource aus CGImage erstellen
        do {
            let texture = try TextureResource.generate(from: cgImage, options: .init(semantic: .color))
            return texture
        } catch {
            print("Skybox Textur Fehler: \(error)")
            return nil
        }
    }
    
    // Hilfsfunktionen
    func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
        return a + (b - a) * t
    }
    
    func sinHash(_ value: Float) -> Float {
        let x = sin(value) * 43758.5453
        return x - floor(x)
    }
    
    // MARK: - Daten laden
    
    func ladeHauptkategorien() async {
        do {
            themen = try await themenService.getHauptkategorien()
            status = "\(themen.count) Kategorien geladen ✓"
        } catch {
            status = "Fehler: \(error.localizedDescription)"
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
