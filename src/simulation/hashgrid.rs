use crate::simulation::Atom;
use bytemuck::{Pod, Zeroable};
use std::mem::size_of;
use std::sync::Arc;
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
    /// the amount of atoms this cell contains. Note that this cannot exceed the length of the indices array.
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
    integrate_pipeline: ComputePipeline,

    atom_buffer_curr: Arc<Buffer>,
    atom_buffer_last: Arc<Buffer>,
    atom_buffer_size: BufferAddress,
    atom_bind_group_a: BindGroup,
    atom_bind_group_b: BindGroup,
    cell_buffer: Buffer,
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

        let atom_buffer_curr = device.create_buffer_init(&BufferInitDescriptor {
            label: Some("Atom Buffer Current"),
            contents: atom_buffer_content,
            usage: BufferUsages::STORAGE
                | BufferUsages::COPY_DST
                | BufferUsages::COPY_SRC
                | BufferUsages::VERTEX,
        });
        let atom_buffer_last = device.create_buffer_init(&BufferInitDescriptor {
            label: Some("Atom Buffer Last"),
            contents: atom_buffer_content,
            usage: BufferUsages::STORAGE
                | BufferUsages::COPY_DST
                | BufferUsages::COPY_SRC
                | BufferUsages::VERTEX,
        });

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

        println!(
            "max atoms per cell: {}",
            cells
                .iter()
                .max_by_key(|cell| cell.count)
                .map(|a| a.count)
                .unwrap()
        );

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
                // cell buffer
                BindGroupLayoutEntry {
                    binding: 2,
                    visibility: ShaderStages::COMPUTE,
                    ty: BindingType::Buffer {
                        ty: BufferBindingType::Storage { read_only: false },
                        has_dynamic_offset: false,
                        min_binding_size: None,
                    },
                    count: None,
                },
            ],
        });
        let atom_bind_group_a = device.create_bind_group(&BindGroupDescriptor {
            label: Some("Atom Bind Group A"),
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
                BindGroupEntry {
                    binding: 2,
                    resource: cell_buffer.as_entire_binding(),
                },
            ],
        });
        let atom_bind_group_b = device.create_bind_group(&BindGroupDescriptor {
            label: Some("Atom Bind Group B"),
            layout: &atom_bind_group_layout,
            entries: &[
                BindGroupEntry {
                    binding: 0,
                    resource: atom_buffer_last.as_entire_binding(),
                },
                BindGroupEntry {
                    binding: 1,
                    resource: atom_buffer_curr.as_entire_binding(),
                },
                BindGroupEntry {
                    binding: 2,
                    resource: cell_buffer.as_entire_binding(),
                },
            ],
        });

        let interact_layout = device.create_pipeline_layout(&PipelineLayoutDescriptor {
            label: Some("Interact Pipeline Layout"),
            bind_group_layouts: &[&atom_bind_group_layout],
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
            entry_point: "main_interact",
        });

        let integrate_layout = device.create_pipeline_layout(&PipelineLayoutDescriptor {
            label: Some("Integrate Pipeline Layout"),
            bind_group_layouts: &[&atom_bind_group_layout],
            push_constant_ranges: &[PushConstantRange {
                stages: ShaderStages::COMPUTE,
                range: 0..size_of::<PushConstants>() as u32,
            }],
        });
        let integrate_pipeline = device.create_compute_pipeline(&ComputePipelineDescriptor {
            label: Some("Integrate Compute Pipeline"),
            layout: Some(&integrate_layout),
            module: &interact_shader,
            entry_point: "main_integrate",
        });

        Self {
            grid_side_length,
            cell_side_length,
            cells_per_side: cells_per_side as i32,
            cell_count: (cells_per_side * cells_per_side) as u32,

            interact_pipeline,
            integrate_pipeline,

            atom_buffer_curr: Arc::new(atom_buffer_curr),
            atom_buffer_last: Arc::new(atom_buffer_last),
            atom_buffer_size,
            atom_bind_group_a,
            atom_bind_group_b,
            cell_buffer,
        }
    }

    pub fn update(&self, command_encoder: &mut CommandEncoder) {
        for (bg, (ba, bb)) in [
            (
                &self.atom_bind_group_a,
                (&self.atom_buffer_curr, &self.atom_buffer_last),
            ),
            (
                &self.atom_bind_group_b,
                (&self.atom_buffer_last, &self.atom_buffer_curr),
            ),
        ] {
            {
                let mut interact_pass =
                    command_encoder.begin_compute_pass(&ComputePassDescriptor {
                        label: Some("Interact Pass"),
                    });

                interact_pass.set_pipeline(&self.interact_pipeline);
                interact_pass.set_bind_group(0, bg, &[]);
                interact_pass.set_push_constants(0, bytemuck::bytes_of(&self.cells_per_side));
                interact_pass.dispatch_workgroups(
                    self.cells_per_side as u32,
                    self.cells_per_side as u32,
                    1,
                );
            }

            {
                let mut integrate_pass =
                    command_encoder.begin_compute_pass(&ComputePassDescriptor {
                        label: Some("Integrate Pass"),
                    });

                integrate_pass.set_pipeline(&self.integrate_pipeline);
                integrate_pass.set_bind_group(0, bg, &[]);
                integrate_pass.set_push_constants(0, bytemuck::bytes_of(&self.cells_per_side));
                integrate_pass.dispatch_workgroups(
                    self.cells_per_side as u32,
                    self.cells_per_side as u32,
                    1,
                );
            }

            //command_encoder.copy_buffer_to_buffer(ba, 0, bb, 0, self.atom_buffer_size);
        }
    }

    pub fn instance_buffer(&self) -> &Arc<Buffer> {
        &self.atom_buffer_curr
    }
}
