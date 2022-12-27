pub mod hashgrid;

use bytemuck::{Pod, Zeroable};
use nalgebra::Vector2;
use std::mem::size_of;
use wgpu::{vertex_attr_array, BufferAddress, VertexAttribute};

/// the conversion factors from constants to real-world data are not trivial, though
/// the simulation result should correspond to reality at least by proportionality.
pub const DELTA_T: f32 = 1e-6;

#[repr(C)]
#[derive(Copy, Clone, Pod, Zeroable)]
pub struct Atom {
    position: Vector2<f32>,
    velocity: Vector2<f32>,
    force: Vector2<f32>,
    visual: f32,
}

impl Atom {
    pub const INSTANCE_ATTRIBS: &'_ [VertexAttribute] =
        &vertex_attr_array![2 => Float32x2, 3 => Float32x2, 4 => Float32x2, 5 => Float32];
}

impl Atom {
    pub fn new(position: Vector2<f32>, velocity: Vector2<f32>, force: Vector2<f32>) -> Self {
        Self {
            position,
            velocity,
            force,
            visual: 0.0,
        }
    }
}
