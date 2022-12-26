use crate::render::{PushConstants, RenderState};
use crate::simulation::hashgrid::HashGrid;
use crate::simulation::Atom;
use eyre::Result;
use nalgebra::Vector2;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use std::mem::size_of;
use wgpu::{
    Backends, BufferAddress, Color, CommandEncoderDescriptor, CompositeAlphaMode, DeviceDescriptor,
    Features, Instance, Limits, LoadOp, Operations, PowerPreference, PresentMode,
    RenderPassColorAttachment, RenderPassDescriptor, RequestAdapterOptions, SurfaceConfiguration,
    TextureUsages, TextureViewDescriptor,
};
use winit::event::{DeviceEvent, Event, MouseScrollDelta, WindowEvent};
use winit::event_loop::{ControlFlow, EventLoop};
use winit::window::WindowBuilder;

pub mod render;
pub mod simulation;

/// grid side length
const GRID_SIZE: f32 = 50.0;

/// cell side length
const CELL_SIZE: f32 = 2.0;

#[tokio::main]
async fn main() -> Result<()> {
    let mut rng = StdRng::from_entropy();

    let event_loop = EventLoop::new();
    let window = WindowBuilder::new().build(&event_loop)?;
    let instance = Instance::new(Backends::VULKAN);
    let surface = unsafe { instance.create_surface(&window) };

    let adapter = instance
        .request_adapter(&RequestAdapterOptions {
            power_preference: PowerPreference::HighPerformance,
            force_fallback_adapter: false,
            compatible_surface: Some(&surface),
        })
        .await
        .expect("failed to get adapter");

    let (device, queue) = adapter
        .request_device(
            &DeviceDescriptor {
                label: Some("Device"),
                features: Features::PUSH_CONSTANTS,
                limits: Limits {
                    max_push_constant_size: size_of::<PushConstants>() as u32,
                    ..Default::default()
                },
            },
            None,
        )
        .await?;

    let atom_count = 10000;
    let atoms = (0..atom_count)
        .map(|_| {
            Atom::new(
                Vector2::from_fn(|_, _| rng.gen::<f32>() * GRID_SIZE),
                Vector2::zeros(),
                Vector2::zeros(),
            )
        })
        .collect::<Vec<_>>();

    let texture_format = surface.get_supported_formats(&adapter)[0];

    let mut surface_configuration = SurfaceConfiguration {
        usage: TextureUsages::RENDER_ATTACHMENT,
        format: texture_format,
        width: 1080,
        height: 1920,
        present_mode: PresentMode::Immediate,
        alpha_mode: CompositeAlphaMode::Auto,
    };
    surface.configure(&device, &surface_configuration);

    let hash_grid = HashGrid::from_slice(&device, &atoms, GRID_SIZE, CELL_SIZE);
    let mut render_state = RenderState::from_slice(
        &device,
        texture_format,
        GRID_SIZE,
        surface_configuration.width as f32 / surface_configuration.height as f32,
    );
    event_loop.run(move |event, _, control_flow| match event {
        Event::WindowEvent {
            window_id,
            ref event,
        } if window_id == window.id() => match event {
            &WindowEvent::Resized(new_size)
            | &WindowEvent::ScaleFactorChanged {
                new_inner_size: &mut new_size,
                ..
            } => {
                surface_configuration.width = new_size.width;
                surface_configuration.height = new_size.height;
                render_state.resize(new_size);
                surface.configure(&device, &surface_configuration);
            }
            WindowEvent::CloseRequested => *control_flow = ControlFlow::Exit,
            WindowEvent::KeyboardInput { .. } => {
                // TODO: keyboard input
            }
            _ => {}
        },
        Event::DeviceEvent {
            event:
                DeviceEvent::MouseWheel {
                    delta: MouseScrollDelta::LineDelta(_x, y),
                },
            ..
        } => {
            render_state.zoom(y);
        }
        Event::MainEventsCleared => window.request_redraw(),
        Event::RedrawRequested(window_id) if window_id == window.id() => {
            let frame = surface
                .get_current_texture()
                .expect("Couldn't get current surface texture");
            let view = frame.texture.create_view(&TextureViewDescriptor::default());

            let mut command_encoder =
                device.create_command_encoder(&CommandEncoderDescriptor::default());

            hash_grid.update(&mut command_encoder);
            render_state.render(
                &mut command_encoder,
                &view,
                atoms.len() as u32,
                hash_grid.instance_buffer(),
            );
            queue.submit(Some(command_encoder.finish()));

            frame.present();
        }
        Event::LoopDestroyed => *control_flow = ControlFlow::Exit,
        _ => {}
    });
}