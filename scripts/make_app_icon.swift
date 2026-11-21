#!/usr/bin/env swift
//
//  make_app_icon.swift — 앱 아이콘을 코드로 그린다.
//
//  사용법 (저장소 루트에서):
//    swift scripts/make_app_icon.swift
//
//  그림: 쿨타임 고리(4분의 3이 찬 진행 고리) 안에 쇼핑백 하나. "사고 싶은 것에 쿨타임을 건다."
//  색은 앱의 쿨타임 그라데이션(AppTheme.cooldown → cooldownAccent) 그대로다.
//
//  만드는 것:
//    · iOS 앱 · 위젯 확장: 기본 / 다크 / 틴트 (1024, 불투명)
//    · watchOS: 기본 (1024, 불투명)
//    · visionOS: Back(바탕) · Middle(고리 길) · Front(진행 고리 + 쇼핑백) 3단
//    · docs/icon.png (소개 페이지, 256)
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])!
}

/// 그림 한 장의 색.
struct Palette {
    /// 바탕 그라데이션(왼쪽 위 → 오른쪽 아래). nil 이면 투명.
    var background: [CGColor]?
    /// 고리의 빈 길.
    var track: CGColor
    /// 찬 고리와 쇼핑백. 두 색이면 그라데이션으로 칠한다.
    var ink: [CGColor]
}

enum Part { case background, track, glyph }

let blue = rgb(0.35, 0.55, 1.0)       // AppTheme.cooldown
let purple = rgb(0.7, 0.4, 1.0)       // AppTheme.cooldownAccent
let white = rgb(1, 1, 1)

let light = Palette(background: [rgb(0.27, 0.50, 1.0), rgb(0.66, 0.36, 1.0)],
                    track: rgb(1, 1, 1, 0.26), ink: [white])
let dark = Palette(background: [rgb(0.09, 0.10, 0.16), rgb(0.04, 0.04, 0.07)],
                   track: rgb(1, 1, 1, 0.12), ink: [rgb(0.45, 0.65, 1.0), rgb(0.78, 0.52, 1.0)])
let tinted = Palette(background: [rgb(0.11, 0.11, 0.11), rgb(0.03, 0.03, 0.03)],
                     track: rgb(1, 1, 1, 0.22), ink: [rgb(0.96, 0.96, 0.96)])

func render(_ palette: Palette, parts: Set<Part>, opaque: Bool, pixels: Int = size) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: alpha.rawValue)!
    // 왼쪽 위가 원점인 1024 좌표로 그린다.
    let scale = CGFloat(pixels) / CGFloat(size)
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: scale, y: -scale)
    ctx.interpolationQuality = .high
    let full = CGRect(x: 0, y: 0, width: size, height: size)

    func gradient(_ colors: [CGColor]) -> CGGradient {
        CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    }
    /// 지금 클립 안을 색(들)으로 칠한다.
    func fill(_ colors: [CGColor], from start: CGPoint = .zero, to end: CGPoint = CGPoint(x: size, y: size)) {
        if colors.count == 1 {
            ctx.setFillColor(colors[0])
            ctx.fill(full)
        } else {
            ctx.drawLinearGradient(gradient(colors), start: start, end: end,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }

    if parts.contains(.background), let background = palette.background {
        fill(background)
        // 위쪽에 아주 옅은 빛.
        ctx.saveGState()
        ctx.drawRadialGradient(gradient([rgb(1, 1, 1, 0.16), rgb(1, 1, 1, 0)]),
                               startCenter: CGPoint(x: 300, y: 220), startRadius: 0,
                               endCenter: CGPoint(x: 300, y: 220), endRadius: 760, options: [])
        ctx.restoreGState()
    }

    let center = CGPoint(x: 512, y: 512)
    let radius: CGFloat = 308
    let ringWidth: CGFloat = 84

    if parts.contains(.track) {
        ctx.setStrokeColor(palette.track)
        ctx.setLineWidth(ringWidth)
        ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
        ctx.strokePath()
    }

    if parts.contains(.glyph) {
        let ink = CGMutablePath()

        // 진행 고리 — 12시에서 시계 방향으로 4분의 3.
        let arc = CGMutablePath()
        arc.addArc(center: center, radius: radius, startAngle: -.pi / 2, endAngle: .pi, clockwise: false)
        ink.addPath(arc.copy(strokingWithWidth: ringWidth, lineCap: .round, lineJoin: .round, miterLimit: 10))

        // 쇼핑백 — 아래로 살짝 넓어지는 몸통.
        let top: CGFloat = 446, bottom: CGFloat = 690
        let topHalf: CGFloat = 126, bottomHalf: CGFloat = 148, corner: CGFloat = 36
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 512 - topHalf + corner, y: top))
        body.addArc(tangent1End: CGPoint(x: 512 + topHalf, y: top), tangent2End: CGPoint(x: 512 + bottomHalf, y: bottom), radius: corner)
        body.addArc(tangent1End: CGPoint(x: 512 + bottomHalf, y: bottom), tangent2End: CGPoint(x: 512 - bottomHalf, y: bottom), radius: corner + 10)
        body.addArc(tangent1End: CGPoint(x: 512 - bottomHalf, y: bottom), tangent2End: CGPoint(x: 512 - topHalf, y: top), radius: corner + 10)
        body.addArc(tangent1End: CGPoint(x: 512 - topHalf, y: top), tangent2End: CGPoint(x: 512 + topHalf, y: top), radius: corner)
        body.closeSubpath()

        // 손잡이 — 몸통 위로 솟은 부분은 칠하고, 몸통 안으로 내려온 끝은 파낸다.
        let handleHalf: CGFloat = 56, handleWidth: CGFloat = 26, handleTop: CGFloat = top - 26
        let handle = CGMutablePath()
        handle.move(to: CGPoint(x: 512 - handleHalf, y: top + 4))
        handle.addLine(to: CGPoint(x: 512 - handleHalf, y: handleTop))
        handle.addArc(center: CGPoint(x: 512, y: handleTop), radius: handleHalf, startAngle: .pi, endAngle: 0, clockwise: false)
        handle.addLine(to: CGPoint(x: 512 + handleHalf, y: top + 4))
        let legs = CGMutablePath()
        for x in [512 - handleHalf, 512 + handleHalf] {
            legs.move(to: CGPoint(x: x, y: top - 4))
            legs.addLine(to: CGPoint(x: x, y: top + 62))
        }

        ctx.saveGState()
        if parts.contains(.background) {
            ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 28 * scale, color: rgb(0.1, 0.05, 0.4, 0.28))
        }
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for path in [ink, body, handle.copy(strokingWithWidth: handleWidth, lineCap: .butt, lineJoin: .round, miterLimit: 10)] {
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip(using: .winding)
            fill(palette.ink, from: CGPoint(x: 200, y: 200), to: CGPoint(x: 824, y: 824))
            ctx.restoreGState()
        }
        ctx.setBlendMode(.clear)
        ctx.addPath(legs.copy(strokingWithWidth: handleWidth, lineCap: .round, lineJoin: .round, miterLimit: 10))
        ctx.fillPath()
        ctx.endTransparencyLayer()
        ctx.restoreGState()
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

let everything: Set<Part> = [.background, .track, .glyph]
let lightIcon = render(light, parts: everything, opaque: true)
let darkIcon = render(dark, parts: everything, opaque: true)
let tintedIcon = render(tinted, parts: everything, opaque: true)

for catalog in ["CoolTime/Assets.xcassets", "widget/Assets.xcassets"] {
    write(lightIcon, to: "\(catalog)/AppIcon.appiconset/AppIcon.png")
    write(darkIcon, to: "\(catalog)/AppIcon.appiconset/AppIcon-dark.png")
    write(tintedIcon, to: "\(catalog)/AppIcon.appiconset/AppIcon-tinted.png")
}
write(lightIcon, to: "CoolTimeWatch/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

let stack = "CoolTime/Assets.xcassets/AppIcon.solidimagestack"
write(render(light, parts: [.background], opaque: true), to: "\(stack)/Back.solidimagestacklayer/Content.imageset/Back.png")
write(render(light, parts: [.track], opaque: false), to: "\(stack)/Middle.solidimagestacklayer/Content.imageset/Middle.png")
write(render(light, parts: [.glyph], opaque: false), to: "\(stack)/Front.solidimagestacklayer/Content.imageset/Front.png")

write(render(light, parts: everything, opaque: true, pixels: 256), to: "docs/icon.png")
