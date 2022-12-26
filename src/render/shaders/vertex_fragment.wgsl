struct VertexInput {
    // per vertex inputs
    @location(0) position: vec2<f32>,
    @location(1) color: vec4<f32>,
    // per instance inputs
    @location(2) instance_position: vec2<f32>,
    @location(3) instance_velocity: vec2<f32>,
    @location(4) instance_force: vec2<f32>,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) color: vec4<f32>,
}

struct PushConstants {
    position: vec2<f32>,
    inv_aspect: f32,
    scale: f32
}

var<push_constant> push_constants: PushConstants;

let radius = 1.0;

@vertex
fn main_vs(vs_inputs: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    out.position = vec4<f32>(
        (vs_inputs.position * radius - push_constants.position + vs_inputs.instance_position) * vec2<f32>(push_constants.inv_aspect, 1.0) * push_constants.scale,
            0.0,
            1.0);
    out.color = vs_inputs.color;
    return out;
}

@fragment
fn main_fs(in: VertexOutput) -> @location(0) vec4<f32> {
    return in.color;
}