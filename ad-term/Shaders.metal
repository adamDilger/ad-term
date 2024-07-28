//
//  Shaders.metal
//  ad-term
//
//  Created by Adam Dilger on 24/7/2024.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>

using namespace metal;

struct Vertex {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
    float3 bgColor [[attribute(2)]];
    float3 fgColor [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 bgColor;
    float3 fgColor;
};

vertex VertexOut vertexFunction(Vertex in [[stage_in]]) {
    VertexOut out;
    out.position = float4(in.position, 0.0, 1.0);
    out.texCoord = in.texCoord;
    out.bgColor = in.bgColor;
    out.fgColor = in.fgColor;
    
    return out;
}

fragment float4 fragmentFunction(VertexOut in [[stage_in]], texture2d<float> fontTexture [[texture(0)]]) {
    constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);

    float4 color = fontTexture.sample(colorSampler, in.texCoord);
    
    return float4((1-color.a) * in.bgColor + color.rgb * in.fgColor, 1);
    
//    if (color.a > 0.5) {
//        return float4(in.fgColor[0], in.fgColor[1], in.fgColor[2], 1);
//    }
//    
//    // return float4(color.rgb, 1.0);
//    return float4(in.bgColor[0], in.bgColor[1], in.bgColor[2], 1);
}
