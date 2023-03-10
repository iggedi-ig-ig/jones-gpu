use crate::render::{PushConstants, RenderState};
use crate::simulation::hashgrid::HashGrid;
use crate::simulation::Atom;
use eyre::Result;
use nalgebra::Vector2;
use rand::rngs::StdRng;
use rand::{Rng, SeedableRng};
use std::mem::size_of;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use wgpu::{
    Backends, CommandEncoderDescriptor, CompositeAlphaMode, DeviceDescriptor, Features, Instance,
    Limits, Maintain, MaintainBase, PowerPreference, PresentMode, QuerySetDescriptor, QueryType,
    RequestAdapterOptions, SurfaceConfiguration, TextureUsages, TextureViewDescriptor,
};
use winit::event::{DeviceEvent, Event, MouseScrollDelta, WindowEvent};
use winit::event_loop::{ControlFlow, EventLoop};
use winit::window::WindowBuilder;

pub mod render;
pub mod simulation;

/// grid side length
const GRID_SIZE: f32 = 100.0;

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
                features: Features::PUSH_CONSTANTS | Features::TIMESTAMP_QUERY,
                limits: Limits {
                    max_push_constant_size: size_of::<PushConstants>() as u32,
                    ..Default::default()
                },
            },
            None,
        )
        .await?;

    let device = Arc::new(device);
    let queue = Arc::new(queue);

    let hexagonal_lattice = |i: usize, rng: &mut StdRng| -> Vector2<f32> {
        let n = GRID_SIZE.floor() as usize;
        Vector2::new(
            (i % n) as f32 + if (i / n) % 2 == 0 { 0.5 } else { 0.0 },
            (i / n) as f32 * 3.0f32.sqrt() * 0.5,
        )
    };

    let count = (GRID_SIZE / 1.0).floor() as usize
        * (GRID_SIZE / (3.0f32.sqrt() * 0.5) / 1.0).floor() as usize; // hex
    let atoms = (0..count)
        .filter_map(|i| {
            if rng.gen::<f32>() < 0.01 {
                //  return None;
            }

            let pos = hexagonal_lattice(i, &mut rng);
            Some(Atom::new(pos, Vector2::zeros(), Vector2::zeros()))
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
    let mut render_state = RenderState::new(
        &device,
        texture_format,
        GRID_SIZE,
        surface_configuration.width as f32 / surface_configuration.height as f32,
        &queue,
    );

    let ib = hash_grid.instance_buffer().clone();

    let running = Arc::new(AtomicBool::new(true));

    tokio::spawn({
        let device = device.clone();
        let queue = queue.clone();
        let running = running.clone();

        let qs = device.create_query_set(&QuerySetDescriptor {
            label: Some("compute timer"),
            count: 2,
            ty: QueryType::Timestamp,
        });

        async move {
            let mut tick = Arc::new(AtomicU64::new(0));
            let mut i = 0;

            while running.load(Ordering::Relaxed) {
                // tokio::time::sleep(Duration::from_millis(500)).await;
                let mut command_encoder =
                    device.create_command_encoder(&CommandEncoderDescriptor::default());
                command_encoder.write_timestamp(&qs, 0);
                hash_grid.update(&mut command_encoder);
                command_encoder.write_timestamp(&qs, 1);

                queue.submit(Some(command_encoder.finish()));
                queue.on_submitted_work_done({
                    let tick = tick.clone();
                    move || {
                        let _ = tick.fetch_add(1, Ordering::Relaxed);
                    }
                });
                i += 1;
                //println!("{} {}", tick.load(Ordering::Relaxed), i);
                // while !device.poll(Maintain::Wait) {}
            }
        }
    });

    let mut last_frame = Instant::now();
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
            WindowEvent::CloseRequested => {
                running.store(false, Ordering::Relaxed);
                *control_flow = ControlFlow::Exit;
            }
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

            render_state.render(&mut command_encoder, &view, atoms.len() as u32, &ib);
            queue.submit(Some(command_encoder.finish()));

            frame.present();
        }
        Event::LoopDestroyed => {
            *control_flow = ControlFlow::Exit;
        }
        _ => {}
    });
}
