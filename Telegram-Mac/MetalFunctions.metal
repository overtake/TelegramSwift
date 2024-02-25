//
//  TwoInputFilter.metal
//  TgVoipWebrtc
//
//  Created by kolechqa on 25.06.2021.
//  Copyright © 2021 Mikhail Filimonov. All rights reserved.
//


#include <metal_stdlib>
using namespace metal;

typedef struct {
  packed_float2 position;
  packed_float2 texcoord;
} Vertex;

typedef struct {
  float4 position[[position]];
  float2 texcoord;
} Varyings;
                                                
vertex Varyings vertexPassthrough(constant Vertex *verticies[[buffer(0)]],
                                  unsigned int vid[[vertex_id]]) {
  Varyings out;
  constant Vertex &v = verticies[vid];
  out.position = float4(float2(v.position), 0.0, 1.0);
  out.texcoord = v.texcoord;

  return out;
}

fragment float4 fragmentColorConversion(
    Varyings in[[stage_in]],
    sampler sourceSampler [[sampler(0)]],
    texture2d<float, access::sample> textureY[[texture(0)]],
    texture2d<float, access::sample> textureU[[texture(1)]],
    texture2d<float, access::sample> textureV[[texture(2)]]) {
//    float y;
//    float u;
//    float v;
//    float r;
//    float g;
//    float b;
//    // Conversion for YUV to rgb from http://www.fourcc.org/fccyvrgb.php
//
//    constexpr sampler quadSampler;
//
//    y = textureY.sample(quadSampler, in.texcoord).r;
//    u = textureU.sample(quadSampler, in.texcoord).r;
//    v = textureV.sample(quadSampler, in.texcoord).r;
//
//    y = y - 0.0625;
//    u = u - 0.5;
//    v = v - 0.5;
//
//    r = 1.164 * y + 1.596 * v;
//    g = 1.164 * y - 0.392 * u - 0.813 * v;
//    b = 1.164 * y + 2.17 * u;
//
//    float4 out = float4(r, g, b, 1.0);
//
//    return float4(out);
        
        constexpr sampler s(address::clamp_to_edge, filter::linear);
        float y;
        float u;
        float v;
        float r;
        float g;
        float b;
        // Conversion for YUV to rgb from http://www.fourcc.org/fccyvrgb.php
        y = textureY.sample(s, in.texcoord).r;
        u = textureU.sample(s, in.texcoord).r;
        v = textureV.sample(s, in.texcoord).r;
        u = u - 0.5;
        v = v - 0.5;
        r = y + 1.403 * v;
        g = y - 0.344 * u - 0.714 * v;
        b = y + 1.770 * u;

        float4 out = float4(r, g, b, 1.0);

        return out;

}
         

float4 ditherNoise(texture2d<float, access::sample> texture, sampler sampler, float2 uv, float4 color) {
    
    float textureSize = 256;
    float noiseGrain = 0.002;
    
    float width = texture.get_width();
    float height = texture.get_width();
    
    float xPixel = (1 / width);
    float yPixel = (1 / height);
    
    
    float2 noiseTextureCoord = float2(uv.x + textureSize * xPixel, uv.y + textureSize * yPixel);
    float noiseClamped = texture.sample(sampler, noiseTextureCoord).r;
    float noiseIntensity = (noiseClamped * 4.) - 2.;
    float3 lumcoeff = float3(0.299, 0.587, 0.114);
    float luminance = dot(color.rgb, lumcoeff);
    float lum = smoothstep(0.2, 0.0, luminance) + luminance;
    float3 noiseColor = mix(float3(noiseIntensity), float3(0.0), pow(lum, 4.0));

    color.rgb = color.rgb + noiseColor * noiseGrain;
    return color;
}

/*
 
 [[nodiscard]] ShaderPart FragmentDitherNoise() {
     const auto size = QString::number(kNoiseTextureSize);
     return {
         .header = R"(
 uniform sampler2D n_texture;
 )",
         .body = R"(
     vec2 noiseTextureCoord = gl_FragCoord.xy / )" + size + R"(.;
     float noiseClamped = texture2D(n_texture, noiseTextureCoord).r;
     float noiseIntensity = (noiseClamped * 4.) - 2.;
     vec3 lumcoeff = vec3(0.299, 0.587, 0.114);
     float luminance = dot(result.rgb, lumcoeff);
     float lum = smoothstep(0.2, 0.0, luminance) + luminance;
     vec3 noiseColor = mix(vec3(noiseIntensity), vec3(0.0), pow(lum, 4.0));
     result.rgb = result.rgb + noiseColor * noiseGrain;
 )",
     };
 }
 */

float2 doScale(float2 uv, float2 scale) {
    uv -= float2(0.5); // relative center logic
    uv  = float2x2(float2(scale.x, 0.0), float2(0.0, scale.y)) * uv; // scale
    uv += float2(0.5); // relative center logic
  
    return uv;
}
float4 applyBoxBlur(texture2d<float, access::sample> texture, sampler sampler, float2 uv, bool vertical) {
    
    int radius = 30;
    int diameter = 2 * radius + 1;
    
    const float3 satLuminanceWeighting = float3(0.2126, 0.7152, 0.0722);
    
    float width = texture.get_width();
    float height = texture.get_width();
    
    float xPixel = (1 / width);
    float yPixel = (1 / height);
    
    float2 offsets = vertical ? float2(0, 1) : float2(1, 0);
            
    float4 accumulated = float4(0.);
    for (int i = 0; i != diameter; i++) {
        float stepOffset = float(i - radius);
        float fradius = float(radius);
        float2 offset = float2(stepOffset) * offsets;
        float2 px = float2(uv.x + offset.x*xPixel, uv.y + offset.y*yPixel);
        float4 sampled = float4(texture.sample(sampler, px));
        float boxWeight = fradius + 1.0 - abs(float(i) - fradius);
        accumulated += sampled * boxWeight;
    }
    

    float3 blurred = accumulated.rgb / accumulated.a;
    float satLuminance = dot(blurred, satLuminanceWeighting);
    float3 mixinColor = float3(satLuminance);
    
    return float4(clamp(mix(mixinColor, blurred, 1.1), 0.0, 1.0) * 0.65, 1.0);
}


typedef struct {
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
    float2 textureCoordinate2 [[user(texturecoord2)]];
} TwoInputVertexIO;
                                                
vertex TwoInputVertexIO twoInputVertex(const device packed_float2 *position [[buffer(0)]],
                                       const device packed_float2 *texturecoord [[buffer(1)]],
                                       const device packed_float2 *texturecoord2 [[buffer(2)]],
                                       unsigned int vid [[vertex_id]])
{
    TwoInputVertexIO outputVertices;
    
    outputVertices.position = float4(position[vid], 0.0, 1.0);
    outputVertices.textureCoordinate = texturecoord[vid];
    outputVertices.textureCoordinate2 = texturecoord2[vid];

    return outputVertices;
}


fragment float4 scaleAndBlur(Varyings in[[stage_in]],
                            sampler sampler [[sampler(0)]],
                            constant float2 &scale [[buffer(0)]],
                            constant bool &vertical [[buffer(1)]],
                            texture2d<float, access::sample> inputTexture[[texture(0)]]) {
    
    float2 uv = doScale(in.texcoord, scale);

    return float4(applyBoxBlur(inputTexture, sampler, uv, vertical));
}


fragment float4 transformAndBlend(TwoInputVertexIO fragmentInput [[stage_in]],
                                 sampler sourceSampler1 [[sampler(0)]],
                                 sampler sourceSampler2 [[sampler(1)]],
                                   texture2d<float, access::sample> foregroundTexture [[texture(0)]],
                                 texture2d<float, access::sample> backgroundTexture [[texture(1)]],
                                 constant float2 &scale1 [[buffer(0)]],
                                 constant float2 &scale2 [[buffer(1)]])
{
    
    float2 uv1 = doScale(fragmentInput.textureCoordinate, scale1);
    float2 uv2 = doScale(fragmentInput.textureCoordinate2, scale2);
    
    float4 out1 = foregroundTexture.sample(sourceSampler1, uv1);
    
    float4 out2 = backgroundTexture.sample(sourceSampler2, uv2);
    
    
    if (out1.a == 0) {
        out2 = float4(applyBoxBlur(backgroundTexture, sourceSampler2, uv2, false));
//        out2 = ditherNoise(backgroundTexture, sourceSampler2, uv2, out2);
    }
    
    float4 outputColor;
    
    float a = out1.a + out2.a * (1.0h - out1.a);
    float alphaDivisor = a; // Protect against a divide-by-zero blacking out things in the output
    
    outputColor.r = (out1.r * out1.a + out2.r * out2.a * (1.0h - out1.a))/alphaDivisor;
    outputColor.g = (out1.g * out1.a + out2.g * out2.a * (1.0h - out1.a))/alphaDivisor;
    outputColor.b = (out1.b * out1.a + out2.b * out2.a * (1.0h - out1.a))/alphaDivisor;
    outputColor.a = a;
    
    return outputColor;
}

fragment float4 fragmentPlain(Varyings in[[stage_in]],
                              sampler sampler [[sampler(0)]],
                              texture2d<float, access::sample> inputTexture[[texture(0)]]) {
    return inputTexture.sample(sampler, in.texcoord);
}




struct VertexIn {
  packed_float3 position;
  packed_float2 texCoord;
};

struct VertexOut {
  float4 position [[position]];
  float2 texCoord;
};

vertex VertexOut basic_vertex(
    const device VertexIn* vertex_array [[ buffer(0) ]],
    unsigned int vid [[ vertex_id ]]) {
    VertexIn in = vertex_array[vid];
  
    VertexOut out;
    out.position = float4(in.position, 1.0);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 basic_fragment(
    VertexOut interpolated [[stage_in]],
    texture2d<float> tex2D [[ texture(0) ]],
    sampler sampler2D [[ sampler(0) ]],
    constant bool &mirror [[buffer(0)]]) {
    
    float2 p = interpolated.texCoord;
    float4 color;
    if (mirror) {
        color = tex2D.sample(sampler2D, float2(1 - p.x, p.y));
    } else {
        color = tex2D.sample(sampler2D, p);
    }
    return float4(color.r, color.g, color.b, color.a);
}





typedef struct {
    packed_float2 position;
} VertexMatrix;

struct RasterizerData
{
    float4 position [[position]];
};

vertex RasterizerData matrixVertex
(
    constant VertexMatrix *vertexArray[[buffer(0)]],
    uint vertexID [[ vertex_id ]]
) {
    RasterizerData out;
    
    out.position = vector_float4(vertexArray[vertexID].position[0], vertexArray[vertexID].position[1], 0.0, 1.0);
            
    return out;
}

float text(float2 uvIn,
           texture2d<half> symbolTexture,
           texture2d<float> noiseTexture,
           float time)
{
    constexpr sampler textureSampler(min_filter::linear, mag_filter::linear, mip_filter::linear, address::repeat);
    
    float count = 32.0;
    
    float2 noiseResolution = float2(256.0, 256.0);

    float2 uv = fmod(uvIn, 1.0 / count) * count;
    float2 block = uvIn * count - uv;
    uv = uv * 0.8;
    uv += floor(noiseTexture.sample(textureSampler, block / noiseResolution + time * .00025).xy * 256.);
    uv *= -1.0;
    
    uv *= 0.25;
    
    return symbolTexture.sample(textureSampler, uv).g;
}

float4 rain(float2 uvIn,
            uint2 resolution,
            float time)
{
    float count = 32.0;
    uvIn.x -= fmod(uvIn.x, 1.0 / count);
    uvIn.y -= fmod(uvIn.y, 1.0 / count);
    
    float2 fragCoord = uvIn * float2(resolution);
    
    float offset = sin(fragCoord.x * 15.0);
    float speed = cos(fragCoord.x * 3.0) * 0.3 + 0.7;
    
    float y = fract(fragCoord.y / resolution.y + time * speed + offset);
    
    return float4(1.0, 1.0, 1.0, 1.0 / (y * 30.0) - 0.02);
}

fragment half4 matrixFragment(RasterizerData in[[stage_in]],
                              texture2d<half> symbolTexture [[ texture(0) ]],
                              texture2d<float> noiseTexture [[ texture(1) ]],
                              constant uint2 &resolution[[buffer(0)]],
                              constant float &time[[buffer(1)]])
{
    float2 uv = (in.position.xy / float2(resolution.xy) - float2(0.5, 0.5));
    uv.y -= 0.1;
    
    float2 lookup = float2(0.08 / (uv.x), (0.9 - abs(uv.x)) * uv.y * -1.0) * 2.0;
    
    float4 out = text(lookup, symbolTexture, noiseTexture, time) * rain(lookup, resolution, time);
    return half4(out);
}



struct Rectangle {
    float2 origin;
    float2 size;
};

constant static float2 quadVertices[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 1.0)
};

struct QuadVertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex QuadVertexOut edgeTestVertex(
    const device Rectangle &rect [[ buffer(0) ]],
    unsigned int vid [[ vertex_id ]]
) {
    float2 quadVertex = quadVertices[vid];
    
    QuadVertexOut out;
    
    out.position = float4(rect.origin.x + quadVertex.x * rect.size.x, rect.origin.y + quadVertex.y * rect.size.y, 0.0, 1.0);
    out.position.x = -1.0 + out.position.x * 2.0;
    out.position.y = -1.0 + out.position.y * 2.0;
    
    out.uv = quadVertex;
    
    return out;
}

fragment half4 edgeTestFragment(
    QuadVertexOut in [[stage_in]],
    const device float4 &colorIn
) {
    half4 color = half4(colorIn);
    return color;
}
