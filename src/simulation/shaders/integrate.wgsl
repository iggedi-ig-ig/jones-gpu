struct Atom {
    pos_x: f32,
    pos_y: f32,
    vel_x: f32,
    vel_y: f32,
    force_x: f32,
    force_y: f32
}

@group(0) @binding(0) var<storage, write> atoms_curr: array<Atom>;
@group(0) @binding(1) var<storage, read> atoms_last: array<Atom>;

@compute
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let index = global_id.x;
}