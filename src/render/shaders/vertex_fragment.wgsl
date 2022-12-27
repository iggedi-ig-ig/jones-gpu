struct VertexInput {
    // per vertex inputs
    @location(0) position: vec2<f32>,
    @location(1) color_variable: f32,
    // per instance inputs
    @location(2) instance_position: vec2<f32>,
    @location(3) instance_velocity: vec2<f32>,
    @location(4) instance_force:    vec2<f32>,
    @location(5) instance_visual:   f32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color_variable: f32,
    @location(1) model_pos: vec2<f32>,
}

struct PushConstants {
    position: vec2<f32>,
    inv_aspect: f32,
    scale: f32
}

var<push_constant> push_constants: PushConstants;
@group(0) @binding(0) var colormap: texture_1d<f32>;
@group(0) @binding(1) var colormap_sampler: sampler;

let radius = 1.0;

@vertex
fn main_vs(vs_inputs: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.position = vec4<f32>(
        (vs_inputs.position * radius - push_constants.position + vs_inputs.instance_position) * vec2<f32>(push_constants.inv_aspect, 1.0) * push_constants.scale,
            0.0,
            1.0);

    out.color_variable = vs_inputs.instance_visual;
    out.model_pos = vs_inputs.position.xy * 2.0;
    return out;
}

@fragment
fn main_fs(in: VertexOutput) -> @location(0) vec4<f32> {
    return dot(vec3<f32>(in.model_pos.x, sqrt(1.0 - dot(in.model_pos,in.model_pos)), in.model_pos.y), normalize(vec3<f32>(0.3,0.6,0.3))) * vec4<f32>(textureSample(colormap, colormap_sampler, in.color_variable).rgb, 1.0);

    //dot(vec3(circlePos.x, sqrt(1.0 - dot(circlePos, circlePos)), circlePos.y), normalize(vec3(0.3, 0.6, 0.2)))
}