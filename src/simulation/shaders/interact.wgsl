struct Atom {
    pos_x: f32,
    pos_y: f32,
    vel_x: f32,
    vel_y: f32,
    force_x: f32,
    force_y: f32,
    visual: f32,
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
@group(0) @binding(2) var<storage, read_write> cells: array<Cell>;

var<push_constant> push_constants: PushConstants;

fn lennard_jones(dist_sq: f32) -> f32 {
    let desired_radius = 1.0;
    let sigma_fac = 1.122462048309373; // 6th root of 2, the factor of the root relative to sigma
    let sigma = desired_radius / sigma_fac;
    let sigma_6 = sigma * sigma * sigma * sigma * sigma * sigma;
    let epsilon = 0.25 * 3.0;


    return max(-1e7, (24.0 * epsilon * sigma_6 * (dist_sq * dist_sq * dist_sq - 2.0 * sigma_6)) / (dist_sq * dist_sq * dist_sq * dist_sq * dist_sq * dist_sq * dist_sq));
}

fn hash(id: vec2<i32>) -> i32 {
    return clamp(id.y, 0, push_constants.cells_per_side - 1) * push_constants.cells_per_side + clamp(id.x, 0, push_constants.cells_per_side - 1);
}

@compute
@workgroup_size(1)
fn main_interact(@builtin(global_invocation_id) invocation_id: vec3<u32>) {
    let global_id = vec3<i32>(invocation_id);

    let self_index = hash(global_id.xy);
    let self_cell = &cells[self_index];

    let n = push_constants.cells_per_side;
    for (var y_pos = max(0, global_id.y - 1); y_pos <= min(global_id.y + 1, n); y_pos++) {
        for(var x_pos = max(0, global_id.x - 1); x_pos <= min(global_id.x + 1, n); x_pos++) {
            let other_index = hash(vec2<i32>(x_pos, y_pos));
            let other_cell = &cells[other_index];

            for (var j = 0; j < min(16, (*self_cell).count); j++) {
                let self_index = (*self_cell).indices[j];

                for (var i = 0; i < min(16, (*other_cell).count); i++) {
                    let other_index = (*other_cell).indices[i];

                    if (self_index != other_index) {
                        let self_atom = atoms_last[self_index];
                        let self_pos = vec2<f32>(self_atom.pos_x, self_atom.pos_y);
                        let other_atom = atoms_last[other_index];
                        let other_pos = vec2<f32>(other_atom.pos_x, other_atom.pos_y);

                        let diff = other_pos - self_pos;
                        let dist_sq = dot(diff, diff);

                        let force = diff * lennard_jones(dist_sq);

                        // interact
                        atoms_curr[self_index].force_x += force.x;
                        atoms_curr[self_index].force_y += force.y;
                        atoms_curr[other_index].force_x -= force.x;
                        atoms_curr[other_index].force_y -= force.y;
                    }
                }
            }
        }
    }
}

@compute
@workgroup_size(1)
fn main_integrate(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let self_id = hash(vec2<i32>(global_id.xy));
    let self_cell = &cells[self_id];

    let time_step = 1e-5;
    let mass = 1.0;

    for (var i = 0; i < min(16, (*self_cell).count); i++) {
        let index = (*self_cell).indices[i];

        atoms_curr[index].vel_x = atoms_last[index].vel_x + atoms_curr[index].force_x / mass;
        atoms_curr[index].vel_y = atoms_last[index].vel_y + atoms_curr[index].force_y / mass;

        atoms_curr[index].pos_x = atoms_last[index].pos_x + atoms_curr[index].vel_x * time_step;
        atoms_curr[index].pos_y = atoms_last[index].pos_y + atoms_curr[index].vel_y * time_step;

        let vis = log2(length(vec2<f32>(atoms_curr[index].force_x, atoms_curr[index].force_y)) + 1.0) * 0.07;
        let k = 0.01;
        atoms_curr[index].visual = mix(atoms_curr[index].visual, vis, k);

        atoms_curr[index].force_x = 0.0;
        atoms_curr[index].force_y = 0.0;
    }
}