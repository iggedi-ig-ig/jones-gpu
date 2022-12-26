struct Atom {
    pos_x: f32,
    pos_y: f32,
    vel_x: f32,
    vel_y: f32,
    force_x: f32,
    force_y: f32
}

struct Cell {
    count: i32,
    indices: array<i32, 16>
}

struct PushConstants {
    cells_per_side: i32
}

@group(0) @binding(0) var<storage, read_write> atoms_curr: array<Atom>;
@group(0) @binding(1) var<storage, read> atoms_last: array<Atom>;
@group(1) @binding(0) var<storage, read_write> cells: array<Cell>;

var<push_constant> push_constants: PushConstants;

fn lennard_jones(dist_sq: f32) -> f32 {
    let desired_radius = 1.0;
    let sigma_fac = 1.122462048309373;
    let sigma = desired_radius / sigma_fac;
    let sigma_6 = sigma * sigma * sigma * sigma * sigma * sigma;
    let epsilon = 0.75;

    return max(-1e7, 24.0 * epsilon * sigma_6 * (dist_sq * dist_sq * dist_sq - 2.0 * sigma_6) / (dist_sq * dist_sq * dist_sq * dist_sq * dist_sq * dist_sq * dist_sq));
}

fn hash(id: vec2<i32>) -> i32 {
    return id.y * push_constants.cells_per_side + id.x;
}

@compute
@workgroup_size(16, 16, 1)
fn main(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let global_id = vec3<i32>(invocation_id);

    let self_index = hash(global_id.xy);
    let self_cell = &cells[self_index];

    for (var y_offs = -1; y_offs <= 1; y_offs++) {
        for(var x_offs = -1; x_offs <= 1; x_offs++) {
            let other_index = hash(global_id.xy + vec2<i32>(x_offs, y_offs));
            let other_cell = &cells[other_index];

            for (var j = 0; j < min(16, (*self_cell).count); j++) {
                for (var i = 0; i < min(16, (*other_cell).count); i++) {
                    let self_index = (*self_cell).indices[j];
                    let self_atom = atoms_last[self_index];
                    let self_pos = vec2<f32>(self_atom.pos_x, self_atom.pos_y);

                    let other_index = (*other_cell).indices[i];
                    let other_atom = atoms_last[other_index];
                    let other_pos = vec2<f32>(other_atom.pos_x, other_atom.pos_y);

                    let diff = self_pos - other_pos;
                    let dist_sq = dot(diff, diff);

                    let force_mag_mult = -lennard_jones(dist_sq);
                    let force = diff * force_mag_mult;

                    // interact
                    let mass = 100.0;
                    atoms_curr[self_index].vel_x += force.x / mass;
                    atoms_curr[self_index].vel_y += force.y / mass;
                    atoms_curr[other_index].vel_x -= force.x / mass;
                    atoms_curr[other_index].vel_y -= force.y / mass;

                    // integrate
                    let time_step = 1e-6;
                    atoms_curr[self_index].pos_x += atoms_curr[self_index].vel_x * time_step;
                    atoms_curr[self_index].pos_y += atoms_curr[self_index].vel_y * time_step;
                    atoms_curr[other_index].pos_x += atoms_curr[other_index].vel_x * time_step;
                    atoms_curr[other_index].pos_y += atoms_curr[other_index].vel_y * time_step;
                }
            }
        }
    }
}