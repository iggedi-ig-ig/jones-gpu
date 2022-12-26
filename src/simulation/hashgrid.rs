use crate::simulation::Atom;
use bytemuck::{Pod, Zeroable};
use wgpu::util::{BufferInitDescriptor, DeviceExt};
use wgpu::{
    BindGroup, BindGroupDescriptor, BindGroupEntry, BindGroupLayoutDescriptor,
    BindGroupLayoutEntry, BindingType, Buffer, BufferAddress, BufferBindingType, BufferUsages,
    CommandBuffer, CommandEncoder, CommandEncoderDescriptor, ComputePassDescriptor, Device,
    ShaderStages,
};

pub const MAX_INDICES: usize = 16;

#[repr(C)]
#[derive(Copy, Clone, Pod, Zeroable, Default)]
/// represents a hash grid cell on the gpu
pub struct HashGridCell {
    /// the amount of atoms this cell contains. Note that this can go above the size of what the indices array can hold.
    count: i32,
    /// the indices into the main atom array of the atoms that lie within this cell.
    indices: [i32; MAX_INDICES],
}
/// represents a hash grid on the gpu. Note that this does not even store
pub struct HashGrid {
    /// the side length of the actual grid
    grid_side_length: f32,
    /// the side length of each cell
    cell_side_length: f32,
    /// the amount of cells per side
    cells_per_side: u32,
    /// the total amount of cells this hash grid has, i.e. `cells_per_side.powi(2)`
    cell_count: u32,

    atom_buffer_curr: Buffer,
    atom_buffer_last: Buffer,
    atom_buffer_size: BufferAddress,
    atom_bind_group: BindGroup,

    cell_buffer: Buffer,
    cell_bind_group: BindGroup,
}

impl HashGrid {
    pub fn from_slice(
        device: &Device,
        atoms: &[Atom],
        grid_side_length: f32,
        cell_side_length: f32,
    ) -> Self {
        let atom_buffer_content = bytemuck::cast_slice(atoms);
        let atom_buffer_size = atom_buffer_content.len() as BufferAddress;
        let atom_buffer_desc = BufferInitDescriptor {
            label: Some("Atom Buffer"),
            contents: atom_buffer_content,
            usage: BufferUsages::STORAGE
                | BufferUsages::COPY_DST
                | BufferUsages::COPY_SRC
                | BufferUsages::VERTEX,
        };
        let atom_buffer_curr = device.create_buffer_init(&atom_buffer_desc);
        let atom_buffer_last = device.create_buffer_init(&atom_buffer_desc);

        let atom_bind_group_layout = device.create_bind_group_layout(&BindGroupLayoutDescriptor {
            label: Some("Atom Bind Group Layout"),
            entries: &[
                // current position buffer
                BindGroupLayoutEntry {
                    binding: 0,
                    visibility: ShaderStages::COMPUTE,
                    ty: BindingType::Buffer {
                        ty: BufferBindingType::Storage { read_only: false },
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
                // last position buffer
                BindGroupLayoutEntry {
                    binding: 1,
                    visibility: ShaderStages::COMPUTE,
                    ty: BindingType::Buffer {
                        ty: BufferBindingType::Storage { read_only: true },
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
            ],
        });
        let atom_bind_group = device.create_bind_group(&BindGroupDescriptor {
            label: Some("Atom Bind Group"),
            layout: &atom_bind_group_layout,
            entries: &[
                BindGroupEntry {
                    binding: 0,
                    resource: atom_buffer_curr.as_entire_binding(),
                },
                BindGroupEntry {
                    binding: 1,
                    resource: atom_buffer_last.as_entire_binding(),
                },
            ],
        });

        let cells_per_side = (grid_side_length / cell_side_length).ceil() as usize;
        let cell_count = cells_per_side * cells_per_side;

        let mut cells = vec![HashGridCell::default(); cell_count];
        atoms.iter().enumerate().for_each(|(atom_index, atom)| {
            let cell_x = (atom.position.x / cell_side_length).floor() as usize;
            let cell_y = (atom.position.y / cell_side_length).floor() as usize;

            let cell_id = cell_y * cells_per_side + cell_x;
            let cell = &mut cells[cell_id];
            // index into the indices array of the cell
            let index_index = cell.count as usize;

            if index_index < cell.indices.len() {
                cell.indices[index_index] = atom_index as i32;
            }
            cell.count += 1;
        });

        let cell_buffer = device.create_buffer_init(&BufferInitDescriptor {
            label: Some("Cell Buffer"),
            contents: bytemuck::cast_slice(&cells),
            usage: BufferUsages::STORAGE,
        });

        let cell_bind_group_layout = device.create_bind_group_layout(&BindGroupLayoutDescriptor {
            label: Some("Cell Bind Group Layout"),
            entries: &[BindGroupLayoutEntry {
                binding: 0,
                visibility: ShaderStages::COMPUTE,
                ty: BindingType::Buffer {
                    ty: BufferBindingType::Storage { read_only: false },
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            }],
        });
        let cell_bind_group = device.create_bind_group(&BindGroupDescriptor {
            label: Some("Cell Bind Group"),
            layout: &cell_bind_group_layout,
            entries: &[BindGroupEntry {
                binding: 0,
                resource: cell_buffer.as_entire_binding(),
            }],
        });

        Self {
            grid_side_length,
            cell_side_length,
            cells_per_side: cells_per_side as u32,
            cell_count: cell_count as u32,

            atom_buffer_curr,
            atom_buffer_last,
            atom_buffer_size,
            atom_bind_group,
            cell_buffer,
            cell_bind_group,
        }
    }

    pub fn update(&self, command_encoder: &mut CommandEncoder) {
        command_encoder.begin_compute_pass(&ComputePassDescriptor {
            label: Some("Interact Pass"),
        });

        command_encoder.copy_buffer_to_buffer(
            &self.atom_buffer_curr,
            0,
            &self.atom_buffer_last,
            0,
            self.atom_buffer_size,
        );
    }

    pub fn instance_buffer(&self) -> &Buffer {
        &self.atom_buffer_curr
    }
}
