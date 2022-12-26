use crate::simulation::Atom;
use bytemuck::{Pod, Zeroable};
use std::mem::size_of;
use wgpu::util::{BufferInitDescriptor, DeviceExt};
use wgpu::{
    include_wgsl, BindGroup, BindGroupDescriptor, BindGroupEntry, BindGroupLayoutDescriptor,
    BindGroupLayoutEntry, BindingType, Buffer, BufferAddress, BufferBindingType, BufferUsages,
    CommandBuffer, CommandEncoder, CommandEncoderDescriptor, ComputePassDescriptor,
    ComputePipeline, ComputePipelineDescriptor, Device, PipelineLayoutDescriptor,
    PushConstantRange, ShaderStages,
};

pub const MAX_INDICES: usize = 16;

#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
struct PushConstants {
    cells_per_side: u32,
}

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
    cells_per_side: i32,
    /// the total amount of cells this hash grid has, i.e. `cells_per_side.powi(2)`
    cell_count: u32,

    interact_pipeline: ComputePipeline,
    // integrate_pipeline: ComputePipeline,
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

        let cells_per_side = (grid_side_length / cell_side_length).ceil() as usize;
        let mut cells = vec![HashGridCell::default(); cells_per_side * cells_per_side];

        atoms.iter().enumerate().for_each(|(index, atom)| {
            let cell_id_x = (atom.position.x / cell_side_length).floor() as usize;
            let cell_id_y = (atom.position.y / cell_side_length).floor() as usize;

            let cell_index = cell_id_y * cells_per_side + cell_id_x;
            let cell = &mut cells[cell_index];
            if cell.count < cell.indices.len() as i32 {
                cell.indices[cell.count as usize] = index as i32;
            }
            cell.count += 1;
        });

        let cell_buffer = device.create_buffer_init(&BufferInitDescriptor {
            label: Some("Cell Buffer"),
            contents: bytemuck::cast_slice(&cells),
            usage: BufferUsages::STORAGE,
        });

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

        let interact_layout = device.create_pipeline_layout(&PipelineLayoutDescriptor {
            label: Some("Interact Pipeline Layout"),
            bind_group_layouts: &[&atom_bind_group_layout, &cell_bind_group_layout],
            push_constant_ranges: &[PushConstantRange {
                stages: ShaderStages::COMPUTE,
                range: 0..size_of::<PushConstants>() as u32,
            }],
        });
        let interact_shader = device.create_shader_module(include_wgsl!("shaders/interact.wgsl"));
        let interact_pipeline = device.create_compute_pipeline(&ComputePipelineDescriptor {
            label: Some("Interaction Compute Pipeline"),
            layout: Some(&interact_layout),
            module: &interact_shader,
            entry_point: "main",
        });

        // let integrate_layout = device.create_pipeline_layout(&PipelineLayoutDescriptor {
        //     label: Some("Integrate Pipeline Layout"),
        //     bind_group_layouts: &[&atom_bind_group_layout],
        //     push_constant_ranges: &[],
        // });
        // let integrate_shader = device.create_shader_module(include_wgsl!("shaders/integrate.wgsl"));
        // let integrate_pipeline = device.create_compute_pipeline(&ComputePipelineDescriptor {
        //     label: Some("Integrate Compute Pipeline"),
        //     layout: Some(&integrate_layout),
        //     module: &integrate_shader,
        //     entry_point: "main",
        // });

        Self {
            grid_side_length,
            cell_side_length,
            cells_per_side: cells_per_side as i32,
            cell_count: (cells_per_side * cells_per_side) as u32,

            interact_pipeline,
            // integrate_pipeline: integrate_pipeline,
            atom_buffer_curr,
            atom_buffer_last,
            atom_buffer_size,
            atom_bind_group,

            cell_buffer,
            cell_bind_group,
        }
    }

    pub fn update(&self, command_encoder: &mut CommandEncoder) {
        let mut compute_pass = command_encoder.begin_compute_pass(&ComputePassDescriptor {
            label: Some("Interact Pass"),
        });

        compute_pass.set_pipeline(&self.interact_pipeline);
        compute_pass.set_bind_group(0, &self.atom_bind_group, &[]);
        compute_pass.set_bind_group(1, &self.cell_bind_group, &[]);
        compute_pass.set_push_constants(0, bytemuck::bytes_of(&self.cells_per_side));
        compute_pass.dispatch_workgroups(self.cells_per_side as u32, self.cells_per_side as u32, 1);

        drop(compute_pass);

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
