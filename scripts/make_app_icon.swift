#!/usr/bin/env swift
//
//  make_app_icon.swift — 앱 아이콘을 코드로 그린다.
//
//  사용법 (저장소 루트에서):
//    swift scripts/make_app_icon.swift
//
//  그림: 게임 스킬 칸처럼 쿨타임이 도는 다이얼 위의 쇼핑백. 남은 3분의 1을 반투명 그늘이 덮는다.
//
//  원본은 Icon Composer 문서 CoolTime/AppIcon.icon 이다 (아이폰 · 워치).
//  바탕색 · 유리 · 그림자 같은 설정은 그 안의 icon.json 에 있고 Icon Composer 로 열어 고칠 수 있다.
//  이 스크립트는 그 문서의 레이어 그림을 그리고, 레이어를 쓰지 못하는 곳에 같은 그림을 내보낸다.
//
//  만드는 것:
//    · CoolTime/AppIcon.icon/Assets: dial(다이얼) · bag(쇼핑백) · cooldown(남은 쿨타임) 레이어
//    · visionOS: Back(바탕) · Middle(다이얼) · Front(쇼핑백 + 쿨타임) 3단
//    · docs/icon.png: Icon Composer 가 렌더한 소개 페이지 아이콘 (256)
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size: CGFloat = 1024
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

let center = CGPoint(x: 512, y: 512)
let dialRadius: CGFloat = 400

/// 쇼핑백 몸통 — 아래로 살짝 넓어진다.
let bagBody: CGPath = {
    let cx: CGFloat = 512, top: CGFloat = 448, bottom: CGFloat = 760
    let topHalf: CGFloat = 176, bottomHalf: CGFloat = 200, corner: CGFloat = 46
    let p = CGMutablePath()
    p.move(to: CGPoint(x: cx - topHalf + corner, y: top))
    p.addArc(tangent1End: CGPoint(x: cx + topHalf, y: top), tangent2End: CGPoint(x: cx + bottomHalf, y: bottom), radius: corner)
    p.addArc(tangent1End: CGPoint(x: cx + bottomHalf, y: bottom), tangent2End: CGPoint(x: cx - bottomHalf, y: bottom), radius: corner * 1.3)
    p.addArc(tangent1End: CGPoint(x: cx - bottomHalf, y: bottom), tangent2End: CGPoint(x: cx - topHalf, y: top), radius: corner * 1.3)
    p.addArc(tangent1End: CGPoint(x: cx - topHalf, y: top), tangent2End: CGPoint(x: cx + topHalf, y: top), radius: corner)
    p.closeSubpath()
    return p
}()

/// 손잡이 — 끝이 몸통 안으로 묻힌다.
let bagHandle: CGPath = {
    let cx: CGFloat = 512, top: CGFloat = 448, half: CGFloat = 88, arcY = top - 26
    let h = CGMutablePath()
    h.move(to: CGPoint(x: cx - half, y: top + 30))
    h.addLine(to: CGPoint(x: cx - half, y: arcY))
    h.addArc(center: CGPoint(x: cx, y: arcY), radius: half, startAngle: .pi, endAngle: 0, clockwise: false)
    h.addLine(to: CGPoint(x: cx + half, y: top + 30))
    return h.copy(strokingWithWidth: 42, lineCap: .butt, lineJoin: .round, miterLimit: 10)
}()

/// 남은 쿨타임 — 12시에서 시계 반대 방향으로 3분의 1.
let cooldownWedge: CGPath = {
    let p = CGMutablePath()
    p.move(to: center)
    p.addArc(center: center, radius: dialRadius, startAngle: .pi / 6 * 5, endAngle: .pi * 1.5, clockwise: false)
    p.closeSubpath()
    return p
}()

enum Layer { case background, dial, bag, cooldown }

func render(_ layers: [Layer], opaque: Bool = false) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue)!
    // 왼쪽 위가 원점인 좌표로 그린다.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)
    for layer in layers {
        switch layer {
        case .background:   // icon.json 의 바탕 그라데이션과 같은 색
            let gradient = CGGradient(colorsSpace: space, colors: [rgb(0.33, 0.56, 1.0), rgb(0.66, 0.38, 1.0)] as CFArray, locations: nil)!
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 205, y: 0), end: CGPoint(x: 819, y: size), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        case .dial:
            ctx.setFillColor(rgb(1, 1, 1, 0.22))
            ctx.fillEllipse(in: CGRect(x: center.x - dialRadius, y: center.y - dialRadius, width: dialRadius * 2, height: dialRadius * 2))
        case .bag:
            ctx.setFillColor(rgb(1, 1, 1))
            ctx.addPath(bagBody); ctx.fillPath()
            ctx.addPath(bagHandle); ctx.fillPath()
        case .cooldown:
            ctx.setFillColor(rgb(0.14, 0.08, 0.40, 0.72))
            ctx.addPath(cooldownWedge); ctx.fillPath()
        }
    }
    return ctx.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let url = root.appendingPathComponent(path)
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("못 썼다: \(path)") }
    print("✓ \(path)")
}

// Icon Composer 레이어
let icon = "CoolTime/AppIcon.icon"
write(render([.dial]), to: "\(icon)/Assets/dial.png")
write(render([.bag]), to: "\(icon)/Assets/bag.png")
write(render([.cooldown]), to: "\(icon)/Assets/cooldown.png")

// visionOS 3단
let stack = "CoolTime/Assets.xcassets/AppIcon.solidimagestack"
write(render([.background], opaque: true), to: "\(stack)/Back.solidimagestacklayer/Content.imageset/Back.png")
write(render([.dial]), to: "\(stack)/Middle.solidimagestacklayer/Content.imageset/Middle.png")
write(render([.bag, .cooldown]), to: "\(stack)/Front.solidimagestacklayer/Content.imageset/Front.png")

// 소개 페이지는 Icon Composer 가 렌더한 그림을 쓴다.
let ictool = "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
func export(_ rendition: String, pixels: Int, to path: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: ictool)
    process.arguments = [icon, "--export-image", "--output-file", path, "--platform", "iOS", "--rendition", rendition,
                         "--width", "\(pixels)", "--height", "\(pixels)", "--scale", "1"]
    process.standardOutput = FileHandle.nullDevice
    try! process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { fatalError("ictool 실패: \(path)") }
    print("✓ \(path)")
}
export("Default", pixels: 256, to: "docs/icon.png")
