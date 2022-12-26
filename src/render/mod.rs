use crate::simulation::Atom;
use bytemuck::{Pod, Zeroable};
use nalgebra::Vector2;
use std::cmp::Ordering;
use std::default::Default;
use std::mem::size_of;
use wgpu::util::{BufferInitDescriptor, DeviceExt};
use wgpu::{
    include_wgsl, vertex_attr_array, Buffer, BufferAddress, BufferUsages, Color, ColorTargetState,
    ColorWrites, CommandEncoder, CommandEncoderDescriptor, Device, FragmentState, IndexFormat,
    LoadOp, MultisampleState, Operations, PipelineLayoutDescriptor, PrimitiveState,
    PushConstantRange, RenderPassColorAttachment, RenderPassDescriptor, RenderPipeline,
    RenderPipelineDescriptor, ShaderStages, Surface, TextureFormat, TextureView, VertexAttribute,
    VertexBufferLayout, VertexState, VertexStepMode,
};
use winit::dpi::PhysicalSize;

#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
pub struct PushConstants {
    position: Vector2<f32>,
    inv_aspect: f32,
    scale: f32,
}

#[repr(C)]
#[derive(Copy, Clone, Debug, Pod, Zeroable)]
pub struct Vertex {
    position: Vector2<f32>,
    color: [f32; 4],
}

impl Vertex {
    pub const VERTEX_ATTRS: &'_ [VertexAttribute] =
        &vertex_attr_array![0 => Float32x2, 1 => Float32x4];
}

pub struct RenderState {
    render_pipeline: RenderPipeline,
    vertex_buffer: Buffer,
    index_buffer: Buffer,
    index_count: u32,
    push_constants: PushConstants,
}

impl RenderState {
    pub fn zoom(&mut self, amnt: f32) {
        match amnt.total_cmp(&0.0) {
            Ordering::Less => self.push_constants.scale *= 1.25,
            Ordering::Greater => self.push_constants.scale /= 1.25,
            _ => {}
        }
    }
}

impl RenderState {
    const VERTEX_COUNT: usize = 25;

    pub fn from_slice(
        device: &Device,
        surface_format: TextureFormat,
        grid_size: f32,
        aspect_ratio: f32,
    ) -> Self {
        let vertex_fragment_shader =
            device.create_shader_module(include_wgsl!("shaders/vertex_fragment.wgsl"));

        let vertices = std::iter::once(Vertex {
            position: Vector2::zeros(),
            color: [0.0, 0.0, 0.0, 1.0],
        })
        .chain(
            (0..Self::VERTEX_COUNT - 1)
                .map(|i| i as f32 / (Self::VERTEX_COUNT - 2) as f32 * std::f32::consts::TAU)
                .map(|a| Vertex {
                    position: Vector2::new(-a.sin() * 0.5, a.cos() * 0.5),
                    color: [1.0; 4],
                }),
        )
        .collect::<Vec<_>>();
        let indices: Vec<_> = (2..Self::VERTEX_COUNT as u16 - 1)
            .flat_map(|i| [0, i, i + 1])
            .chain([0, 1, 2])
            .collect();

        let vertex_buffer = device.create_buffer_init(&BufferInitDescriptor {
            label: Some("Vertex Buffer"),
            contents: bytemuck::cast_slice(&vertices),
            usage: BufferUsages::VERTEX,
        });

        let index_buffer = device.create_buffer_init(&BufferInitDescriptor {
            label: None,
            contents: bytemuck::cast_slice(&indices),
            usage: BufferUsages::INDEX,
        });

        let render_pipeline_layout = device.create_pipeline_layout(&PipelineLayoutDescriptor {
            label: Some("Render Pipeline"),
            bind_group_layouts: &[],
            push_constant_ranges: &[PushConstantRange {
                stages: ShaderStages::VERTEX,
                range: 0..size_of::<PushConstants>() as u32,
            }],
        });
        let render_pipeline = device.create_render_pipeline(&RenderPipelineDescriptor {
            label: Some("Render Pipeline"),
            layout: Some(&render_pipeline_layout),
            vertex: VertexState {
                module: &vertex_fragment_shader,
                entry_point: "main_vs",
                buffers: &[
                    VertexBufferLayout {
                        array_stride: size_of::<Vertex>() as BufferAddress,
                        step_mode: VertexStepMode::Vertex,
                        attributes: Vertex::VERTEX_ATTRS,
                    },
                    VertexBufferLayout {
                        array_stride: size_of::<Atom>() as BufferAddress,
                        step_mode: VertexStepMode::Instance,
                        attributes: Atom::INSTANCE_ATTRIBS,
                    },
                ],
            },
            primitive: PrimitiveState::default(),
            depth_stencil: None,
            multisample: MultisampleState::default(),
            fragment: Some(FragmentState {
                module: &vertex_fragment_shader,
                entry_point: "main_fs",
                targets: &[Some(ColorTargetState {
                    format: surface_format,
                    blend: None,
                    write_mask: ColorWrites::ALL,
                })],
            }),
            multiview: None,
        });

        Self {
            render_pipeline,
            vertex_buffer,
            index_buffer,
            index_count: indices.len() as u32,
            push_constants: PushConstants {
                position: Vector2::new(grid_size / 2.0, grid_size / 2.0),
                inv_aspect: 1.0 / aspect_ratio,
                scale: 1.0,
            },
        }
    }

    pub fn resize(&mut self, new_size: PhysicalSize<u32>) {
        let new_aspect = new_size.width as f32 / new_size.height as f32;
        self.push_constants.inv_aspect = 1.0 / new_aspect;
    }

    pub fn render(
        &self,
        command_encoder: &mut CommandEncoder,
        texture_view: &TextureView,
        atom_count: u32,
        instance_buffer: &Buffer,
    ) {
        let mut render_pass = command_encoder.begin_render_pass(&RenderPassDescriptor {
            label: Some("Render Pass"),
            color_attachments: &[Some(RenderPassColorAttachment {
                view: texture_view,
                resolve_target: None,
                ops: Operations {
                    load: LoadOp::Clear(Color::BLACK),
                    store: true,
                },
            })],
            depth_stencil_attachment: None,
        });

        render_pass.set_pipeline(&self.render_pipeline);
        render_pass.set_vertex_buffer(0, self.vertex_buffer.slice(..));
        render_pass.set_vertex_buffer(1, instance_buffer.slice(..));

        render_pass.set_index_buffer(self.index_buffer.slice(..), IndexFormat::Uint16);
        render_pass.set_push_constants(
            ShaderStages::VERTEX,
            0,
            bytemuck::bytes_of(&self.push_constants),
        );
        render_pass.draw_indexed(0..self.index_count, 0, 0..atom_count);
    }
}
